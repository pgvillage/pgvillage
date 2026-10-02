# Development guide

## Quick commands

If you want to change ansible roles, best way is to
- setup pgvillage (which will download the latest versions of roles)
- replace the roles with git cloned folders:
  Example:
  ```bash
  yq -r < requirements.yml '.roles[].name' | while read ROLE; do
    REPO=https://github.com/pgvillage/$(echo $ROLE | sed 's/pgvillage./ansible-role-/')
    D=~/.ansible/roles/"$ROLE"
    [ -d "$D/.git" ] && echo "$D already git" || { 
      rm -rf "$D"
      git clone "$REPO" "$D"
    }
  done
  ```
- check out the branch (if it exists)
  Example:
  ```bash
  for D in ~/.ansible/roles/pgvillage.*; do
    cd $D
    git checkout feat/ubuntu || echo keeping main
  done
  ```
