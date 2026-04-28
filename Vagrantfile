# -*- mode: ruby -*-
# vi: set ft=ruby :

#$ip_file = "db_ip.txt"

# Load .env file if it exists
if File.exist?('.env')
  File.foreach('.env') do |line|
    next if line.strip.empty? || line.start_with?('#')
    key, value = line.strip.split('=', 2)
    ENV[key] = value
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = 'digital_ocean'
  config.vm.box_url = "https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box"
  config.ssh.private_key_path = '~/.ssh/id_rsa'
  # Sync project folder
  config.vm.synced_folder ".", "/vagrant", type: "rsync"

  # --- Manager 1 ---
  config.vm.define "manager1" do |m|
    m.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end
    m.vm.hostname = "manager1"
  end

  # --- Manager 2 ---
  config.vm.define "manager2" do |m|
    m.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-1vcpu-1gb'
      provider.privatenetworking = true
    end
    m.vm.hostname = "manager2"
  end

  # --- Swarm Leader (defined last so Ansible runs after all nodes are up) ---
  config.vm.define "leader_swarm" do |leader|
    leader.vm.provider :digital_ocean do |provider|
      provider.ssh_key_name = ENV["SSH_KEY_NAME"]
      provider.token        = ENV["DIGITAL_OCEAN_TOKEN"]
      provider.image        = 'ubuntu-22-04-x64'
      provider.region       = 'fra1'
      provider.size         = 's-2vcpu-2gb'
      provider.privatenetworking = true
    end
    leader.vm.hostname = "leader"

    # Ansible runs ONCE here after all VMs are up
    leader.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/site.yml"
      ansible.limit    = "all"
      ansible.verbose  = "v"
      ansible.groups     = { "swarm_leaders" => ["leader_swarm"] }
      ansible.extra_vars = {
        DB_ADDR:     ENV["DB_ADDR"],
        DOMAIN:      ENV["DOMAIN"],
        MANAGER1_IP: ENV["MANAGER1_IP"],
        MANAGER2_IP: ENV["MANAGER2_IP"],
        PROM_URL:    ENV["PROM_URL"],
        GRAFANA_URL:  ENV["GRAFANA_URL"],
        ENTRYPOINT:   ENV["ENTRYPOINT"],
        TLS_ENABLED:  ENV["TLS_ENABLED"]
      }
    end
  end
end
