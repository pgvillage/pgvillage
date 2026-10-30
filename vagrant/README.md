# vagrant

A PgVillage demo environment on your laptop: an Ansible host, a minio host and three database hosts.

```bash
cd vagrant
vagrant up                      # PGV_OS=el or PGV_OS=suse for Rocky Linux or openSUSE boxes
vagrant ssh ansible
cd ~/git/pgvillage/
ansible-playbook -i inventories/standard -i inventories/${PGV_OS} -i inventories/vagrant functional-all.yml
```

Create the box first. See the [Vagrant docs](../docs/administrators-guide/platforms/vagrant/index.md) and
[Creating the boxes](../docs/administrators-guide/platforms/vagrant/boxes.md).
