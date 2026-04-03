# -*- mode: ruby -*-
# vi: set ft=ruby :

#$ip_file = "db_ip.txt"

Vagrant.configure("2") do |config|
  config.vm.box = 'digital_ocean'
  config.vm.box_url = "https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box"
  config.ssh.private_key_path = '~/.ssh/id_rsa'
  # Sync project folder
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # --- Database Server with Docker ---
  config.vm.define "dbserver" do |db|
    db.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end

    db.vm.hostname = "dbserver"
  end 

  # --- Swarm Manager / Ingress Node (Node 3) ---
  # This is the NEW third droplet added for the Docker Swarm migration.
  # It serves as the initial swarm manager and Traefik ingress node.
  # Size s-1vcpu-2gb (vs 1gb for others) because it runs Traefik + swarm
  # manager heartbeat overhead simultaneously during the cutover phase.
  config.vm.define "swarmnode" do |swarm|
    swarm.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-1vcpu-2gb'
      provider.privatenetworking = true
    end
    swarm.vm.hostname = "swarmnode"
  end

  # --- Web Server with Docker ---
  config.vm.define "webserver" do |web|

    web.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end

    web.vm.hostname = "webserver"

    # Ansible runs ONCE here after all three VMs are up.
    # inventory_path points to our new static inventory which replaces
    # the implicit Vagrant-generated inventory so we can use host groups.
    web.vm.provision "ansible" do |ansible|
      ansible.playbook       = "ansible/site.yml"
      ansible.limit          = "all"
      ansible.verbose        = "v"
      ansible.inventory_path = "ansible/inventory"
    end
  end
end
