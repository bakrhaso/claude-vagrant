# Security considerations

This document covers the security trade-offs in running an autonomous Claude Code agent inside a Vagrant VM.

## Why a VM?

Running `claude --dangerously-skip-permissions` gives Claude unrestricted command execution — no confirmation prompts for file writes, shell commands, or network access. A VM contains the blast radius: Claude cannot touch the host OS, SSH keys, browser data, cloud credentials, or system configuration.

Docker is installed inside the VM because Docker-in-Docker (dind) requires superuser access, which would be a security risk on the host. Running it inside the VM keeps that privilege contained.

## What the VM protects

| Threat | Bare metal | In VM |
|--------|-----------|-------|
| Modify/destroy OS files | Full access | Contained to guest |
| Access ~/.ssh, ~/.aws, ~/.config | Yes | No |
| Access browser data, keychains | Yes | No |
| Install rootkits, modify crontabs | On host | In guest only, cleared on destroy |
| Resource exhaustion (fork bombs) | Affects host | Contained to VM resource limits (see Vagrantfile) |
| Access code directory files | Yes | Yes — mounted read/write |
| Network exfiltration | Yes | Yes — no egress restrictions |

## What the VM does NOT protect

### Shared folders

Your code directory (configured in `config`) is mounted read/write at `/agent-workspace`. This means any process in the VM can read, modify, or delete files across **all** projects under that directory — not just the one being worked on. This includes:

- Source code in unrelated projects
- `.env` files, API keys, or credentials stored in project directories
- Git hooks (`.git/hooks/`) that could be modified to execute code on the host when you run git commands from the host side. **`git status` does not show hook modifications** — hooks live inside `.git/` which is not tracked. You must check `.git/hooks/` manually.
- Build scripts, Makefiles, and CI configurations that execute code when you build or test
- `package.json` scripts (e.g. `postinstall`) that run automatically during `npm install` on the host
- `.gitattributes` filter definitions that execute commands during `git checkout` or `git diff`
- Git submodule definitions (`.gitmodules`) that could be pointed at malicious repositories

Your docs directory (configured in `config`) is also mounted read/write. Any documents stored there are fully accessible.

### Network access

The VM has unrestricted outbound internet access (VirtualBox NAT mode). Combined with read access to the mounted code directory, this means data exfiltration is possible — a process could read files from shared folders and send them anywhere via `curl`.

### Prompt injection

Since Claude reads files from the shared folders, a malicious file (e.g. a crafted README in a cloned third-party repo) could contain prompt injection that instructs Claude to take unintended actions. With `--dangerously-skip-permissions`, those actions execute without confirmation.

Prompt injection can also come from the network. If Claude performs a web search and a result includes a site controlled by a malicious actor, the injected instructions could combine with Claude's network access and file access to exfiltrate data or modify code.

## Human-in-the-loop

Even with VM isolation, a human should review the agent's work before trusting it. The VM prevents damage to your host system, but it does not prevent the agent from producing bad, malicious, or subtly compromised code in the shared folders.

**After every agent session, before committing or using the code:**

1. **Review code changes:** Run `git diff` in each affected repository on the host. Read the diff — don't just skim it. Look for:
   - Unexpected changes to files outside the project scope
   - New dependencies in `package.json`, `Cargo.toml`, `go.mod`, etc. — each is a supply chain trust decision
   - Modifications to build scripts, Makefiles, or CI/CD pipeline files
   - Hardcoded URLs, IP addresses, or encoded strings that could be exfiltration endpoints
   - Subtle logic changes that weaken validation, authentication, or authorization
2. **Check for hook tampering:** `git status` and `git diff` do not show changes inside `.git/`. Manually inspect `.git/hooks/` for new or modified hooks, especially `pre-commit`, `post-checkout`, and `post-merge` which execute automatically during normal git operations.
3. **Check for dotfile changes:** Look for new or modified `.env`, `.npmrc`, `.yarnrc`, `.pypirc`, or similar files that could redirect package installs, leak credentials, or alter build behavior.
4. **Review new files:** `git status` shows untracked files. Check that the agent hasn't created unexpected files outside the project directory.
5. **Review PRs before merging:** If the agent pushes branches, always review the PR diff yourself before approving. Branch protection requiring human review is your last line of defense.
6. **Check for modifications to this repo:** If `claude-vagrant` is under the mounted directory, the agent can modify its own Vagrantfile, scripts, and CLAUDE.md instructions. Run `git status` in this repo after sessions too.

**Consider reviewing from inside the VM (or a fresh VM).** Running `git diff`, `git status`, and inspecting files inside the VM avoids the risk of host-side code execution from tampered hooks, build scripts, or dotfiles. You can review the agent's changes without triggering any of the host-side execution vectors listed above. A freshly provisioned VM (`vagrant destroy && vagrant up`) provides the cleanest review environment.

## GitHub PAT

The PAT is injected as an environment variable (`GH_TOKEN`) at SSH time. It is never written to disk inside the VM. Any process in the VM can read it via `printenv`, but it disappears when the session ends.

### Permissions and worst cases

**With required permissions only (Contents R/W, Pull requests R/O, Metadata R):**

- Can push commits to any branch, including force pushes to unprotected branches
- Can force push an empty commit to `main`, effectively destroying all visible content — **but only if branch protection is not configured**
- Can delete unprotected branches
- Cannot merge PRs (Pull requests is read-only)
- Cannot modify branch protection rules (requires Administration permission)
- Cannot delete repositories, change settings, or add collaborators

**Branch protection is essential.** Without it, Contents R/W is effectively a repo destruction vector. With it properly configured (require reviews, block force pushes, block deletions), the required permissions are reasonable for an automation agent.

**Optional permissions — prefer read-only for all:**

We recommend granting only read-only access for optional permissions unless you have a specific reason to need write access. The incremental risk of each:

- **Workflows: Do not grant.** This is the most dangerous permission available — it unlocks the ability to push changes to `.github/workflows/` files, which Contents R/W alone cannot do. Without this permission, workflow files are protected even with full Contents access. Modifying workflows enables arbitrary code execution in CI runners, which can access repository secrets, OIDC tokens, and cloud credentials. The blast radius can extend well beyond the scoped repositories. There is no read-only option — it is read and write only.
- **Issues: Read-only recommended.** Write access allows bulk-closing, editing, or creating issues. Read access alone exposes private issue discussions, which may contain sensitive information.
- **Actions: Read-only.** View workflow runs and logs. Note that GitHub's secret masking in workflow logs is imperfect — leaked secrets in logs may be readable.
- **Commit statuses: Read-only.** View commit status checks. Information disclosure only.
- **Checks:** Currently unavailable for fine-grained PATs — only GitHub Apps can access the Checks API ([tracking issue](https://github.com/orgs/community/discussions/129512)). Listed in GitHub's API schema but disabled due to edge cases.

### Mitigations

These are configured on the GitHub side, independent of this VM setup:

1. **Enable branch protection** on `main` (and release branches) for every repo the PAT can access:
   - Require at least 1 approving review
   - Dismiss stale reviews on new pushes
   - Block force pushes
   - Block branch deletion
   - Require status checks to pass
2. **Use CODEOWNERS** with required review from code owners for `.github/workflows/` to prevent CI/CD pipeline tampering
3. **Scope the PAT to only the repos you actively work on with Claude** — every additional repo increases blast radius
4. **Set the org's default GITHUB_TOKEN to read-only** to limit what CI workflows can do if tampered with

## Potential improvements

These are known improvements we haven't implemented:

- **Egress network filtering:** iptables rules in the VM that allowlist only known-good destinations (GitHub API, npm registry, apt mirrors, Anthropic API). This would prevent arbitrary data exfiltration.
- **Read-only code mount:** Mount `/agent-workspace` read-only and only mount the specific project directory read-write. VirtualBox shared folders can't be changed at runtime (requires `vagrant reload`), so this would mean one VM per project or a reload when switching.
- **Keep claude-vagrant outside the mounted directory:** If this repo lives under the path mounted into the VM, the agent can modify its own Vagrantfile, scripts, and instructions.
