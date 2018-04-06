# kubernetes 1.10 from scratch

## prerequisites:
- kubectl installed
- vagrant installed incl. vagrant-timezone plugin
- cfssl & cfssljson installed

## start:

```
sh ansible/certs/vagrant/kube-certgen.sh
vagrant up
vagrant ssh kube-0
sudo -i
cd /vagrant/ansible
ansible-playbook -i inventories/vagrant/vagrant.ini vagrant-install.yml
kubectl apply -f deployments/
```

## includes:
- docker
- clustered etcd on kube-0..2
- 4 VMs (kubernetes master on kube-0, worker on kube-1..3)
- TLS everywhere + certrotation
- nginx as default backend
- kubeDNS
- calico bound to etcd
- user "zepp" with access to `kubectl` and `etcdctl` - just do "su zepp" (default pw: wurst)
