# TL;DR setup

1. [Install VirtualBox](https://www.virtualbox.org/)
   - If on Fedora, enable RPM Fusion and follow [their guide](https://rpmfusion.org/Howto/VirtualBox), I just copy-pasted their quick install instructions and added sudo in front of every command. Afterwards I rebooted.
2. [Install Vagrant](https://developer.hashicorp.com/vagrant/install)
3. `cp example-config config` and replace with your values
4. `./start-agent.sh`, optionally `./start-agent.sh path/to/dir` if you want to start in a specific directory. The path is on the host and will be "translated" to an internal path in the VM.

If you want to start fresh again

1. `vagrant destroy`
2. `./start-agent.sh`

# What

This allows easily setting up a VM that you can run `claude --dangerously-skip-permissions` in without worrying (that much) about Claude breaking your computer.
The idea and Vagrantfile came from [this blog post](https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/) from Emil Burzo, I just adapted it to my workflow.
Changes from Emil's Vagrantfile include

- Mounting a configurable code directory (default `~/code`) at `/agent-workspace` — edit the `config` file to change it
- Mounting a configurable docs directory (default `~/Documents/claude-projects`) at `/agent-docs`
- Copying `dot_claude/CLAUDE.md` into the VM as Claude Code's instructions
- Homebrew is installed
- Installing [jj](https://docs.jj-vcs.dev) and [gh](https://cli.github.com/) via Homebrew
- Using Debian instead of Ubuntu
- Docker is installed inside the VM so Claude can use it without needing privileged access on the host

# GitHub CLI (gh) setup

The VM has `gh` installed but needs a token to authenticate. The `start-agent.sh` script can optionally pull a fine-grained PAT from 1Password via `op` and inject it into the VM session. This is entirely optional — if `op` is not installed or `OP_PAT_REF` is empty in `config`, the VM starts without `GH_TOKEN`.

## Creating the PAT

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure:
   - **Resource owner:** The owner of the repos you plan to work with.
   - **Repository access:** "Only select repositories" → pick only the repos you plan to work on with Claude in the VM. Every additional repo increases the blast radius if the token is compromised.
   - **Permissions (required):**
     - Contents: Read and write — push commits and read repo files
     - Pull requests: Read-only — read PRs, reviews, and comments (read-only prevents the agent from merging PRs)
     - Metadata: Read — required by GitHub for all fine-grained PATs, cannot be disabled
   - **Permissions (optional — prefer read-only for all, add as needed):**
     - Issues: Read-only — read issues for context. Write lets Claude create/comment on issues.
     - Actions: Read-only — view workflow runs and logs
     - Commit statuses: Read-only — view commit status checks
     - ~~Checks: currently unavailable for fine-grained PATs ([GitHub is tracking this](https://github.com/orgs/community/discussions/129512)). Use a GitHub App if you need Checks API access.~~
   - Leave everything else at "No access"
   - See [GitHub's docs on fine-grained PAT permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens) for a full reference
4. Generate the token. If the org requires approval, an admin will need to approve it.
5. Store the token in 1Password and set `OP_PAT_REF` in `config` to the secret reference (default: `op://Private/claude-vagrant-pat/credential`)

## Launching

```bash
./start-agent.sh                            # land in /agent-workspace
./start-agent.sh ~/code/my-project          # land in a specific project
```

If a PAT is available (via `op`), it's injected as `GH_TOKEN` into the VM session. The token only lives in the shell environment — it's never written to disk inside the VM. Without a PAT, the session starts normally but `gh` won't be authenticated.

You can also authenticate `gh` inside the VM using `gh auth login` (the regular browser/device code flow), but this is discouraged — it grants the full permissions of your GitHub account rather than the scoped-down permissions of a fine-grained PAT.

**Security note:** Exposing a PAT via environment variable means any process running in the VM can read it (e.g. `printenv GH_TOKEN`). This is a known trade-off. We accept it here because:

- The VM is single-purpose — only the agent runs in it
- The PAT is scoped to minimal permissions (no repo deletion, no admin access)
- The alternative (writing to disk) is worse — it persists across reboots and is easier to leak
- The token disappears when the session ends

## Renewing an expired PAT

Fine-grained PATs cannot be renewed or duplicated. When it expires, create a new one with the same settings above and update the `claude-vagrant-pat` item in 1Password.

## Syncing CLAUDE.md files

Two CLAUDE.md files are copied into the VM during provisioning:

- `~/.claude/CLAUDE.md` (your host's personal instructions) → `/etc/host-claude-config/CLAUDE.md`
- `./dot_claude/CLAUDE.md` (VM-specific instructions) → `/home/vagrant/.claude/CLAUDE.md`

To update them without re-provisioning:

```bash
./sync-claude-md.sh          # sync both
./sync-claude-md.sh host     # sync only host CLAUDE.md
./sync-claude-md.sh vm       # sync only VM CLAUDE.md
```

See [SECURITY.md](SECURITY.md) for a detailed analysis of the security considerations in this setup.
