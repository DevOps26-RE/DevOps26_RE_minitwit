# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = 'digital_ocean'
  config.vm.box_url = "https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box"
  config.ssh.private_key_path = '~/.ssh/id_ed25519'
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # --- Database Server ---
  config.vm.define "dbserver" do |db|
    db.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name      = ENV["SSH_KEY_NAME"]
      provider.token             = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image             = 'ubuntu-22-04-x64'
      provider.region            = 'fra1'
      provider.size              = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end

    db.vm.hostname = "dbserver"

    db.trigger.after :up do |trigger|
      trigger.ruby do |env, machine|
        ip = machine.ssh_info[:host]
        File.write(File.join(File.dirname(__FILE__), "db_ip.txt"), ip) if ip
      end
    end
  end

  # --- Web Server ---
  config.vm.define "webserver" do |web|
    web.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name      = ENV["SSH_KEY_NAME"]
      provider.token             = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image             = 'ubuntu-22-04-x64'
      provider.region            = 'fra1'
      provider.size              = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end

    web.vm.hostname = "webserver"

    web.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/site.yml"
      ansible.limit    = "all"
      ansible.verbose  = "v"
    end
  end
end