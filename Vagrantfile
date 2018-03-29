# -*- mode: ruby -*-
# vi: set ft=ruby :

N = 3 	# define number of nodes

Vagrant.configure("2") do |config|
	
	# global stuff
	config.vm.provision :shell, path: "prov/prepare.sh"
	config.vm.box = "centos/7"
	if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
		config.vm.synced_folder ".", "/vagrant", mount_options: ["dmode=700,fmode=600"], type: "rsync", rsync__exclude: ".git/"
	else
		config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"
	end
	if Vagrant.has_plugin?("vagrant-timezone")
		config.timezone.value = "CET"
  	end
	config.ssh.insert_key = false

	# masterblaster:
	config.vm.define "kube-boss" do |d|
		d.vm.hostname = "kube-boss.foo.io"
		d.vm.network(:private_network, { ip: "172.16.0.10" })
		d.vm.provision :shell, path: "prov/tools.sh"	# ansible
		d.vm.provision :shell, inline: 'PYTHONUNBUFFERED=1 ansible-playbook /vagrant/ansible/init.yml -c local'
		d.vm.provider "virtualbox" do |v|
			v.memory = 2048
		end
	end

	# workernodes:
	(1..N).each do |machine_id|
		config.vm.define "kube-#{machine_id}" do |machine|
			machine.vm.hostname = "kube-#{machine_id}.foo.io"
			machine.vm.network(:private_network, { ip: "172.16.0.#{10+machine_id}" })
			machine.vm.provider "virtualbox" do |v|
				v.memory = 1024
			end
		end
	end

	if Vagrant.has_plugin?("vagrant-vbguest")
		config.vbguest.auto_update = false
		config.vbguest.no_install = true
		config.vbguest.no_remote = true
	end
end