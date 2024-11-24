# Introduction

Om binnen de Acme infrastructuur op de juiste manier met ssh naar alle servers te kunnen connecten dient de ssh config juist geconfigureerd te worden.

# **Ingredients**

- an account on the management server `gurus-dbabh-server1`
- a password-encrypted SSH private key
- MobaXTerm with the correct configuration
  - settings > configuration > ssh > ssh agents
    - "Use internal SSH AGent MobAgent" must be enabled
    - "Load following keys at startup" must have the path to the key
  - Connection to `gurus-dbabh-server1.int.corp.com` with
    - "Advanced SSH Sessions" > " Use private key" must contain the private key

# Setting up the correct SSH configuration

Make sure that on the bh server the `~/.ssh/config` file contains the following information:

ForwardAgent yes

ForwardX11 yes

ServerAliveInterval 30

TCPKeepAlive yes

Host knmi

User root

Hostname bvlha.knmi.nl

```
Host *
```

StrictHostKeyChecking no

```
UserKnownHostsFile=/dev/null
```

```
Host 10.0.1.**
```

StrictHostKeyChecking no

```markdown
UserKnownHostsFile=/dev/null
```

```
ProxyCommand ssh -W %h:%p gurus-satl6-server1.int.corp.com
```

```
Host 10.0.4.**
```

StrictHostKeyChecking no

```markdown
UserKnownHostsFile=/dev/null
```

```markdown
ProxyCommand ssh -W %h:%p gurus-satl6-server1.int.corp.com
```

```
Host acme-*
```

StrictHostKeyChecking no

```markdown
UserKnownHostsFile=/dev/null
```

```markdown
ProxyCommand ssh -W %h:%p gurus-satl6-server1.int.corp.com
```

```
Host gurus-* !gurus-satl6-server1.int.corp.com
```

StrictHostKeyChecking no

```
UserKnownHostsFile=/dev/null
```

```markdown
ProxyCommand ssh -W %h:%p gurus-satl6-server1.int.corp.com
```

```
Host *.knmi.nl
```

User root

StrictHostKeyChecking no

```
UserKnownHostsFile=/dev/null
```

```markdown
ProxyCommand ssh -W %h:%p root@145.23.210.14
```

Host \*.acme.nl

User doej

Replace doe(j) (reference to last name and initial John Doe) with your own DWO account.

Nu kun je middels ssh conencten naar alle database servers die je in beheer hebt.

Ansible neemt deze config over bij uitvoering.

