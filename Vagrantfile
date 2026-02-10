vm_name = File.basename(Dir.getwd)

Vagrant.configure("2") do |config|
  config.vm.box = "bento/debian-13"

  #config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true
  config.vm.synced_folder "~/code", "/agent-workspace", type: "virtualbox"
  config.vm.synced_folder "~/Documents/claude-projects/", "/agent-docs", type: "virtualbox"
  config.vm.synced_folder "./dot_claude", "/home/vagrant/.claude/", type: "virtualbox"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
    vb.gui = false
    vb.name = vm_name
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--usb", "off"]
  end

  config.vm.provision "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get upgrade -y
    apt-get install -y unattended-upgrades ca-certificates curl gnupg build-essential
    dpkg-reconfigure -f noninteractive unattended-upgrades

    # Enable unattended upgrades for all packages, not just security
    cat > /etc/apt/apt.conf.d/51unattended-upgrades-all <<'EOF'
Unattended-Upgrade::Origins-Pattern { "origin=*"; };
EOF

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    apt-get install -y nodejs npm git unzip

    # Install brew
    su - vagrant -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    su - vagrant -c 'echo "eval \\"\\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\\"" >> ~/.bashrc'
    su - vagrant -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew install jj'
    
    su - vagrant -c 'curl -fsSL https://claude.ai/install.sh | bash'
    echo 'Claude Code installed'

    usermod -aG docker vagrant
    echo 'Finished provisioner shell script'
  SHELL
end
