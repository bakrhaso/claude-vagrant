You are running inside a virtual machine. Read `/agent-workspace/claude-vagrant/Vagrantfile` to see how the VM is created, what OS, etc.
Because you run in a VM created with Vagrant it is very easy to replace the VM if something goes horribly wrong.
You can install any package you need in the VM.
The files mounted from the host naturally might not be that easy to replace if they aren't committed to a git repo or similar so don't nuke those.

* Project documentation and notes are stored in `/agent-docs/`. When asked about a project, check there first for relevant context.

The host user's coding instructions are at @/etc/host-claude-config/CLAUDE.md — follow those as well.
