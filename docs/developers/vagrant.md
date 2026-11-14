## Part of a component

---

Bouwblok Postgresql

## ## Introduction

Om PostgreSQL te installeren wordt gebruik gemaakt van Ansible.

For developing playbooks and roles, it's handy to use a local environment.

---

dit kan middels Virtuele machines op eigen laptop.

VirtualBox is a popular tool for running virtual machines (VMs).

Vagrant is a tool that provides a command-line interface (CLI) for interacting with VirtualBox and virtual machines (VMs).

## ```markdown
Requirements and Dependencies
```

For using Vagrant and VirtualBox, these programs must first be installed on a local laptop.

Om Ansible playbooks te runnen is Ansible nodig.

So:

- Ansible

- VirtualBox

- Vagrant

\- Git

## Uitvoering

To roll out a few VMs using Vagrant, a `Vagrantfile` is needed.

Logging into these VMs using SSH keys requires an SSH key pair.

Create this and then place it next to the Vagrantfile in the same directory:

create directory: `mkdir ~/Virtualmachines`

create a key pair:

```shell
ssh-keygen -t rsa -b <size> -f ~/Virtualmachines/id_rsa
```

```

maak Vagrantfile aan met onderstaande vulling  ( deze maakt 7 VM's aan, pas eventueel aan naar behoefte ):

```ruby
Vagrant.configure("2") do |config|
```

# Base VM OS configuration.

```markdown
# config.vm.box = "generic/rhel8"
```

```markdown
# config.vm.box = "bento/rockylinux-8"
```

```markdown
config.vm.box = "bento/ubuntu-20.04"
```

```markdown
config.vm.synced_folder '.', '/vagrant', disabled: true
```

```markdown
config.ssh.insert_key = false
```

```markdown
config.vm.provider :virtualbox do |v|
```

v.memory = 2048

`vcpus = 4`

```markdown
# v.linked_clone = true
```

end

# Define three VMs with static private IP addresses.

boxes = \[

{ :name => "server1.example.com", :ip => "192.168.56.11" },

{ :name => "server2.example.com", :ip => "192.168.56.12" },

```markdown
{ name: "server3.example.com", ip: "192.168.56.13" },
```

```markdown
{ name: "server4.example.com", ip: "192.168.56.14" },
```

```markdown
{ "name": "server5.example.com", "ip": "192.168.56.15" },
```

```markdown
{:name => "server6.example.com", :ip => "192.168.56.16"},
```

```markdown
{ name: "server7.example.com", ip: "192.168.56.17" }
```

\]

```markdown
if Vagrant.has_plugin?('vagrant-registration')
```

```markdown
config.registration.username = 'mailaddress@hcs-company.com'
```

```markdown
config.registration.password = 'password_redhat.com'
```

end

# Allocate resources for each of the virtual machines.

```ruby
boxes.each do |opts|
```

```markdown
config.vm.define opts[:name] do |config|
```

```markdown
config.vm.hostname = opts[:name]
```

```markdown
config.vm.network :private_network, ip: opts[:ip]
```

```markdown
config.vm.provision "file", source: "id_rsa", destination: "/home/vagrant/.ssh/id_rsa"
```

```ruby
public_key = File.read("id_rsa.pub")
```

```markdown
config.vm.provision :shell, inline: "
```

```markdown
echo 'Copying Ansible VM public SSH keys to the VM'
```

```markdown
mkdir -p /home/vagrant/.ssh
```

chmod 700 /home/vagrant/.ssh

```shell
echo '#{public_key}' >> /home/vagrant/.ssh/authorized_keys
```

```markdown
chmod -R 600 /home/vagrant/.ssh/authorized_keys
```

```markdown
echo 'Host 192.168.*.*' >> /home/vagrant/.ssh/config
```

```markdown
echo 'StrictHostKeyChecking no' >> /home/vagrant/.ssh/config
```

```
echo 'UserKnownHostsFile /dev/null' >> /home/vagrant/.ssh/config
```

chmod -R 600 /home/vagrant/.ssh/config

`, privileged: false`

end

end

end

then run the following command:

```bash
vagrant up
```

