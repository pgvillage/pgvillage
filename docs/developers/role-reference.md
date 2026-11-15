---
title: The role reference
summary: How the role reference is generated from the comments in defaults/main.yml
---

# The role reference

The pages under [Reference > Roles](../reference/roles/index.md) are generated on every docs build (`mkdocs build` and
`mkdocs serve`): the comments in `defaults/main.yml` of a role are its documentation. To change the reference of a
variable, change the comment above it in the role, release the role, and bump its version in `requirements.yml`.

## How the pages are made

The [mkdocs-gen-files](https://oprypin.github.io/mkdocs-gen-files/) plugin runs `docs/scripts/role_reference.py`. For
every role in `requirements.yml` it:

1. installs the pinned version with `ansible-galaxy` into `.cache/role-reference/<role>/<version>/` (the next build
   reuses it; set `ROLE_REFERENCE_CACHE` to use another folder). Without network the build fails, unless the roles are
   in the cache already;
2. reads `meta/main.yml` (`galaxy_info.description`) and `defaults/main.yml`;
3. writes `reference/roles/<role>.md`, and `reference/roles/index.md` with all roles.

To look at the generated Markdown without mkdocs: `python docs/scripts/role_reference.py <output folder>`.

## Writing the comments

```yaml
# --- Restarts ---

# Seconds to wait after a restart of a host, before the next host is restarted.
# Restarts are rolling: one host at a time.
role_restart_delay: 10

# OS user and group that run the service.
role_user: role
role_group: role

# Dictionary of instances. Each key is an instance name.
# Example:
# role_instances:
#   main:
#     port: 6432
role_instances: {}

# Default settings of every instance.
role_instance_defaults:
  # Port to listen on, must be unique per instance.
  port: 6432
```

- The comment block directly above a variable (no blank line between) is its description. One block above several
  variables (no blank lines between them, like `role_user` and `role_group`) describes each of them.
- The description is Markdown: `code`, lists (`- item`), paragraphs (an empty `#` line). Lines indented by two spaces
  or more after a line that ends with `:` become a code block. Names of variables of the role become links.
- A line `Example:` (or `Example ...:`, the text becomes the title) starts an example: the rest of the comment block is
  YAML and becomes a code block. A line that sets a variable of the role (`# role_var: ...`, not indented) does the
  same, with the line above it (when it ends with `:`) as the title.
- Comment lines right after a value (no blank line between, and a blank line after them), such as a commented-out
  value, are shown with that variable.
- A comment block on its own (blank lines around it) is shown as text between the variables. A line
  `--- Title ---` starts a section with that title, also as the first line of a description.
- Comments above the keys of a dictionary default (like `role_instance_defaults.port`) give those keys their own rows.
- Short defaults are in the table; dictionaries, lists, multi-line and long values are shown below the table, as in
  `defaults/main.yml`. Jinja defaults are shown as they are, in a code block.
- Variables that start with `_` are internal and not shown. They belong in `vars/main.yml`.
- Comments at the top of the file (before the first variable, with a blank line between) are the introduction of the
  page. A first line like `defaults file for <role>` is left out.
