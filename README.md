# TL;DR setup

1. Install [VirtualBox](https://www.virtualbox.org/)
   - If on Fedora, enable RPM Fusion and follow [their guide](https://rpmfusion.org/Howto/VirtualBox), I just copy-pasted their quick install instructions and added sudo in front of every command. Afterwards I rebooted.

2. [Install Vagrant](https://developer.hashicorp.com/vagrant/install)
3. Run `vagrant up` (be patient if it looks like it froze, it took 11 minutes for me)
4. Once done, `vagrant ssh` and you'll be inside the VM. You can now run

If you want to start fresh again

1. `vagrant destroy`
2. `vagrant up` again

# What

This allows easily setting up a VM that you can run `claude --dangerously-skip-permissions` in without worrying (that much) about Claude breaking your computer.
The idea and Vagrantfile came from [this blog post](https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/) from Emil Burzo, I just adapted it to my workflow.
Changes from Emil's Vagrantfile include

- Mounting `~/code` instead of `.` so I can use one VM for all my projects
- Mounting `~/Documents/claude-projects/` since that's where I keep documents I want Claude to have access to
- Mounting `./dot_claude/` so we can provide a CLAUDE.md. The entire directory is synced between the host and guest, but only CLAUDE.md is not in the .gitignore
- Installing [jj](https://docs.jj-vcs.dev) (and Rust since we install jj using `cargo`)
- Using Debian instead of Ubuntu
