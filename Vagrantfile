Vagrant.configure(2) do |config|

  config.vm.box = "centos/7"
  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 2
    v.check_guest_additions = false
  end



$setup_vm = <<'SCRIPT'
sudo yum -y install parted
sudo parted /dev/sdb mklabel GPT
sudo parted -a opt /dev/sdb mkpart primary ext4  0% 100%
sudo mkfs.ext4 /dev/sdb1
sudo mount /dev/sdb1 /mnt
sudo cp -a /var/* /mnt
sudo mount /dev/sdb1 /var && sudo umount /mnt
cat /etc/mtab | grep /dev/sdb >> /etc/fstab
SCRIPT


config.vm.define "borgserver" do |b|
    b.vm.network "private_network", ip: "192.168.0.10", virtualbox__intnet: "net1"
    b.vm.hostname = "borgserver"
	b.vm.disk :disk, size: "10GB", name: "extra_storage"
 	b.vm.provision "shell", inline: $setup_vm,        keep_color: true
end
  


#    nfss.vm.provision "shell", path: "nfss_script.sh"

#
#  config.vm.define "client" do |client|
#    client.vm.network "private_network", ip: "192.168.0.20", virtualbox__intnet: "net1"
#    client.vm.hostname = "client"
#    nfsc.vm.provision "shell", path: "nfsc_script.sh"
#  end

end
