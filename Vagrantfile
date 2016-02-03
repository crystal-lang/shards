Vagrant.configure(2) do |config|
  config.ssh.forward_agent = true
  config.vm.box_check_update = false
  config.vm.hostname = "shards"

  config.vm.define :precise64 do |app|
    app.vm.provider :lxc do |lxc, override|
      override.vm.box = "fgrehm/precise64-lxc"
      lxc.container_name = "shards-precise64"
    end
  end

  config.vm.define :precise32 do |app|
    app.vm.provider :lxc do |lxc, override|
      override.vm.box = "erickeller/precise-i386"
      lxc.container_name = "shards-precise32"
    end
  end

  config.vm.provision "shell", inline: <<-SHELL
    apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
    echo "deb http://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list

    apt-get update
    apt-get install --yes build-essential crystal libyaml-dev git

    su - vagrant -c 'git config --global user.email "you@example.com"'
    su - vagrant -c 'git config --global user.name "Your Name"'
  SHELL
end
