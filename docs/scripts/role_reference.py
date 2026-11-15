"""Generate the role reference (docs/reference/roles/) from the roles in requirements.yml.

Run by the mkdocs-gen-files plugin (see mkdocs.yml) on every `mkdocs build` and `mkdocs serve`. It can also run on its
own, to look at the generated Markdown: `python docs/scripts/role_reference.py <output dir>`.

For every role in requirements.yml it installs the pinned version with ansible-galaxy (into a cache folder, reused on
the next build), and turns the comments in defaults/main.yml into a page. How the comments are read is described in
docs/developers/role-reference.md.
"""

from __future__ import annotations

import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap

REPO_ROOT = Path(__file__).resolve().parents[2]
REQUIREMENTS = REPO_ROOT / "requirements.yml"
# Installed roles, one folder per role and version. Override with ROLE_REFERENCE_CACHE.
CACHE_DIR = Path(os.environ.get("ROLE_REFERENCE_CACHE", REPO_ROOT / ".cache" / "role-reference"))
OUT_DIR = "reference/roles"

# A default that is longer than this, has more than one line or is a dict or list goes into a code block below the
# table. Jinja defaults always go into a code block (in the table when they are short and on one line).
MAX_INLINE_DEFAULT = 40

HEADING_RE = re.compile(r"^-{2,}\s*(.*?)\s*-{2,}$")
RULER_RE = re.compile(r"^[-=#*]{5,}$")
EXAMPLE_RE = re.compile(r"^(?:#+\s*)?(example\b.*?):?\s*$", re.IGNORECASE)
LIST_ITEM_RE = re.compile(r"^(?:[-*]|\d+[.)])\s+\S")
# A commented-out YAML line: `key: value` with a single word as value (or none), or a list item of those
CODE_LINE_RE = re.compile(r"""^\s*(?:-\s+)?[\w.$"'-]+:(?:\s+[^\s#]+)?\s*$""")
BOILERPLATE_RE = re.compile(r"^(defaults? (file|values) for\b.*|pgvillage\.?\w*|\w+)$", re.IGNORECASE)


class RoleReferenceError(RuntimeError):
    pass


# --------------------------------------------------------------------------------------------------------------------
# Installing the roles
# --------------------------------------------------------------------------------------------------------------------


@dataclass
class Role:
    name: str  # e.g. pgvillage.stolon
    version: str
    path: Path | None = None
    repo_url: str | None = None  # e.g. https://github.com/pgvillage/ansible-role-stolon

    @property
    def short_name(self) -> str:
        return self.name.split(".", 1)[-1]

    @property
    def tree_url(self) -> str | None:
        return f"{self.repo_url}/tree/{self.version}" if self.repo_url else None

    def blob_url(self, path: str) -> str | None:
        return f"{self.repo_url}/blob/{self.version}/{path}" if self.repo_url else None


def read_requirements() -> list[Role]:
    data = YAML(typ="safe").load(REQUIREMENTS.read_text())
    roles = []
    for item in data.get("roles") or []:
        name = item.get("name") or item.get("src")
        version = item.get("version")
        if not name or not version:
            raise RoleReferenceError(f"{REQUIREMENTS}: every role needs a name and a pinned version, got {item}")
        roles.append(Role(name=str(name), version=str(version)))
    return roles


def install_roles(roles: list[Role]) -> None:
    """Install every role into CACHE_DIR/<name>/<version>, unless it is there already."""
    missing = []
    for role in roles:
        role.path = CACHE_DIR / role.name / role.version
        info = role.path / ".role-reference.json"
        if info.is_file():
            role.repo_url = json.loads(info.read_text()).get("repo_url")
        else:
            missing.append(role)
    if not missing:
        return
    # Prefer the ansible-galaxy of the Python that runs mkdocs (e.g. a venv that isn't activated)
    galaxy = shutil.which("ansible-galaxy", path=str(Path(sys.executable).parent)) or shutil.which("ansible-galaxy")
    if not galaxy:
        raise RoleReferenceError(
            "ansible-galaxy not found: install the docs requirements (pip install -r docs-requirements.txt)"
        )
    for role in missing:
        with tempfile.TemporaryDirectory(prefix="role-reference-") as tmp:
            cmd = [galaxy, "role", "install", "--force", "--no-deps", "-p", tmp, f"{role.name},{role.version}"]
            result = subprocess.run(cmd, check=False, capture_output=True, text=True)
            installed = Path(tmp) / role.name
            if result.returncode != 0 or not (installed / "defaults").is_dir():
                raise RoleReferenceError(
                    f"Could not install {role.name} {role.version} for the role reference (no network?).\n"
                    f"The roles are cached in {CACHE_DIR}; a build without network only works when they are there.\n"
                    f"{' '.join(cmd)}:\n{result.stdout}{result.stderr}"
                )
            # "- downloading role from https://github.com/<owner>/<repo>/archive/<version>.tar.gz"
            match = re.search(r"downloading role from (https://github\.com/[^/\s]+/[^/\s]+)/archive/", result.stdout)
            repo_url = match.group(1) if match else None
            if role.path.exists():
                shutil.rmtree(role.path)
            role.path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(installed, role.path)
            (role.path / ".role-reference.json").write_text(json.dumps({"repo_url": repo_url}))
            role.repo_url = repo_url


# --------------------------------------------------------------------------------------------------------------------
# Reading defaults/main.yml
# --------------------------------------------------------------------------------------------------------------------


@dataclass
class Var:
    name: str
    line: int  # 0-based line of the key
    end: int  # 0-based line after the value
    description: list[str] = field(default_factory=list)  # comment lines, without '#'
    examples: list[tuple[str, list[str]]] = field(default_factory=list)  # (caption, lines)
    after: list[str] = field(default_factory=list)  # comment block right after the value (commented-out code)
    heading: str | None = None  # `--- Heading ---` in the comment block above the variable
    children: list[Var] = field(default_factory=list)
    raw: list[str] = field(default_factory=list)  # source lines of `name: value`, dedented
    value: object = None
    inherited: bool = False


@dataclass
class Note:
    """A comment block that doesn't belong to a variable (a heading and/or text between the variables)."""

    line: int
    heading: str | None
    text: list[str]


def uncomment(line: str) -> str:
    text = line.strip()[1:]
    return text.removeprefix(" ")


def is_comment(line: str) -> bool:
    return line.strip().startswith("#")


def is_blank(line: str) -> bool:
    return not line.strip() or line.strip() == "---"


def comment_block_above(lines: list[str], line: int) -> tuple[int, list[str]]:
    """The comment lines directly above `line` (no blank line between): (first line, uncommented lines)."""
    start = line
    while start > 0 and is_comment(lines[start - 1]):
        start -= 1
    return start, [uncomment(x) for x in lines[start:line]]


def looks_like_code(block: list[str]) -> bool:
    """True when every line of a comment block is commented-out YAML, e.g. `#  uid: 26`."""
    return bool(block) and all(CODE_LINE_RE.match(x) or not x.strip() for x in block)


def split_heading(block: list[str]) -> tuple[str | None, list[str]]:
    """A section heading at the start of a comment block: `--- Title ---`, or a title between ruler lines."""
    if block and RULER_RE.match(block[0].strip()) and len(block) > 1:
        heading = block[1].strip()
        rest = [x for x in block[2:] if not RULER_RE.match(x.strip())]
        while rest and not rest[0].strip():
            rest = rest[1:]
        return heading, rest
    if block and (match := HEADING_RE.match(block[0].strip())) and match.group(1):
        rest = block[1:]
        while rest and not rest[0].strip():
            rest = rest[1:]
        return match.group(1), rest
    return None, block


def split_examples(block: list[str], var_names: set[str]) -> tuple[list[str], list[tuple[str, list[str]]]]:
    """Split a comment block in its description and its examples.

    An example starts with a line `Example...` (the rest of the block is YAML), or with a line that sets a variable of
    the role (`<var>:` without indentation), e.g. a commented-out alternative value.
    """
    for i, text in enumerate(block):
        if (match := EXAMPLE_RE.match(text.strip())) and i + 1 < len(block) and block[i + 1].strip():
            caption = match.group(1).rstrip(":")
            if caption.lower() == "example":
                caption = "Example"
            return block[:i], [(caption, dedent(block[i + 1 :]))]
        key = re.match(r"^([A-Za-z_]\w*):(\s|$)", text)
        if key and key.group(1) in var_names and i + 1 <= len(block):
            desc = block[:i]
            caption = "Example"
            # The prose line just above is the caption, e.g. "For one host only, use the following:"
            if desc and desc[-1].strip().endswith(":"):
                caption = desc.pop().strip().rstrip(":")
            while desc and not desc[-1].strip():
                desc.pop()
            return desc, [(caption, dedent(block[i:]))]
    return block, []


def dedent(lines: list[str]) -> list[str]:
    indents = [len(x) - len(x.lstrip()) for x in lines if x.strip()]
    cut = min(indents) if indents else 0
    lines = [x[cut:] for x in lines]
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def parse_defaults(path: Path) -> tuple[list[str], list[Var | Note]]:
    """Return the file header and the variables and notes of a defaults file, in file order."""
    text = path.read_text()
    lines = text.splitlines()
    data = YAML().load(text)
    if not isinstance(data, CommentedMap):
        return [], []
    var_names = {str(k) for k in data}
    keys = [(str(k), data.lc.key(k)[0]) for k in data]
    used: set[int] = set()  # comment lines that are part of a description, example or note

    def value_end(start: int, stop: int) -> int:
        """The line after the value that starts at `start`; `stop` is the next key (or the end of the file)."""
        end = stop
        while end > start + 1 and (is_blank(lines[end - 1]) or is_comment(lines[end - 1])):
            end -= 1
        return end

    def read_var(name: str, line: int, stop: int, value, siblings: list[Var]) -> Var:
        var = Var(name=name, line=line, end=value_end(line, stop), value=value)
        start, block = comment_block_above(lines, line)
        if looks_like_code(block):
            block = []
        else:
            used.update(range(start, line))
        var.heading, block = split_heading(block)
        var.description, var.examples = split_examples(block, var_names)
        # One comment block above several variables (no blank line between them) describes each of them
        if not block and siblings and line > 0 and not is_blank(lines[line - 1]) and not is_comment(lines[line - 1]):
            prev = siblings[-1]
            var.description, var.inherited = prev.description, True
        return var

    # The header: the comment blocks before the first variable that are not directly above it
    header: list[str] = []
    first = keys[0][1] if keys else len(lines)
    above_first, _ = comment_block_above(lines, first)
    for i in range(above_first):
        if is_comment(lines[i]) and split_heading([uncomment(x) for x in lines[i : i + 2]])[0]:
            break  # a `--- Section ---` heading: from here on, notes
        if is_comment(lines[i]):
            header.append(uncomment(lines[i]))
            used.add(i)
        elif not lines[i].strip() and header:
            header.append("")
    header = [x for x in header if not BOILERPLATE_RE.match(x.strip())] if header else []
    header = dedent(header)
    while header and not header[0].strip():
        header.pop(0)

    top: list[Var] = []
    for idx, (name, line) in enumerate(keys):
        stop = keys[idx + 1][1] if idx + 1 < len(keys) else len(lines)
        stop_block, _ = comment_block_above(lines, stop) if idx + 1 < len(keys) else (stop, [])
        var = read_var(name, line, stop, data[name], top)
        # Nested keys of a dict get their own rows when they have comments
        value = data[name]
        if isinstance(value, CommentedMap) and value:
            child_keys = [(str(k), value.lc.key(k)[0]) for k in value]
            children: list[Var] = []
            for cidx, (cname, cline) in enumerate(child_keys):
                cstop = child_keys[cidx + 1][1] if cidx + 1 < len(child_keys) else var.end
                children.append(read_var(cname, cline, cstop, value[cname], children))
            if any(c.description and not c.inherited for c in children):
                var.children = children
        # Comment lines right after the value (no blank line between), and not directly above the next variable:
        # commented-out code that belongs to this variable, e.g. a commented-out value
        after_start = var.end
        if after_start < stop_block and is_comment(lines[after_start]):
            after_stop = after_start
            while after_stop < stop_block and is_comment(lines[after_stop]):
                after_stop += 1
            after_heading = split_heading([uncomment(x) for x in lines[after_start : after_start + 2]])[0]
            if not after_heading and (after_stop >= len(lines) or is_blank(lines[after_stop])):
                var.after = [uncomment(x) for x in lines[after_start:after_stop]]
                used.update(range(after_start, after_stop))
        top.append(var)

    # Source of every variable, without the comment lines that are now in a description of a nested key
    for var in [*top, *(c for v in top for c in v.children)]:
        raw = [x for i, x in enumerate(lines[var.line : var.end], start=var.line) if i not in used]
        var.raw = dedent(raw)

    # Comment blocks that are not used yet, between the variables: notes (e.g. `--- Section ---` headings)
    i = 0
    notes: list[Note] = []
    while i < len(lines):
        if is_comment(lines[i]) and i not in used and not any(v.line <= i < v.end for v in top):
            start = i
            while i < len(lines) and is_comment(lines[i]) and i not in used:
                i += 1
            heading, text = split_heading([uncomment(x) for x in lines[start:i]])
            notes.append(Note(line=start, heading=heading, text=text))
        else:
            i += 1

    items = sorted([*top, *notes], key=lambda x: x.line)
    return header, items


# --------------------------------------------------------------------------------------------------------------------
# Writing Markdown
# --------------------------------------------------------------------------------------------------------------------


# Variables of the role that is being rendered: in descriptions, their names link to their row
LINK_NAMES: set[str] = set()


def prose(text: str) -> str:
    """Markdown for a line of comment text: `<` escaped and variable names linked, outside `code`."""
    parts = re.split(r"(`[^`]*`)", text)
    for i, part in enumerate(parts):
        if i % 2:
            name = part.strip("`")
            if name in LINK_NAMES:
                parts[i] = f"[{part}](#{name})"
            continue
        part = part.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        if LINK_NAMES:
            part = re.sub(
                r"(?<![\w./{-])("
                + "|".join(sorted(map(re.escape, LINK_NAMES), key=len, reverse=True))
                + r")(?![\w{-])",
                lambda m: f"[`{m.group(1)}`](#{m.group(1)})",
                part,
            )
        parts[i] = part
    return "".join(parts)


def comment_to_markdown(block: list[str]) -> str:
    """Turn comment text into Markdown: paragraphs, lists, and indented parts as code blocks."""
    out: list[str] = []
    code: list[str] = []
    prev = "blank"  # blank, prose, list

    def flush_code():
        nonlocal code
        if code:
            out.extend(["", "```yaml", *dedent(code), "```", ""])
            code = []

    for text in block:
        stripped = text.strip()
        indented = len(text) - len(text.lstrip()) >= 2
        if code and (indented or not stripped):
            code.append(text)
            continue
        flush_code()
        if not stripped:
            out.append("")
            prev = "blank"
        elif LIST_ITEM_RE.match(stripped) and not indented:
            if prev == "prose":
                out.append("")
            out.append(prose(stripped))
            prev = "list"
        elif indented and prev == "list":
            out.append("  " + prose(stripped))
        elif indented and prev == "prose" and out and out[-1].rstrip().endswith(":"):
            code.append(text)
        else:
            if prev == "list" and not indented:
                out.append("")
            out.append(prose(stripped))
            prev = "prose"
    flush_code()
    return "\n".join(out).strip()


def code_block(lines: list[str], caption: str | None = None) -> str:
    title = f' title="{caption}"' if caption else ""
    return "\n".join([f"```yaml{title}", *lines, "```"])


def is_jinja(text: str) -> bool:
    return "{{" in text or "{%" in text


def scalar_source(var: Var) -> str | None:
    """The source of a one-line scalar default (without the key), or None."""
    if len(var.raw) != 1:
        return None
    value = var.raw[0].split(":", 1)[1].strip()
    if value in ("|", ">", "|-", ">-", "|+", ">+"):
        return None
    return value


def default_cell(var: Var, anchor: str) -> tuple[str, bool]:
    """The contents of the Default column, and whether the default goes into a code block below the table."""
    value = scalar_source(var)
    if value is None or len(value) > MAX_INLINE_DEFAULT and not (value in ("{}", "[]")):
        return f'<a href="#{anchor}">see below</a>', True
    if value == "":
        return "", False
    if is_jinja(value):
        return f"\n```yaml\n{value}\n```\n", False
    return f"<code>{html.escape(value)}</code>", False


def var_details(var: Var, anchor: str, long_default: bool) -> str:
    parts = [f"#### `{var.name}` {{ #{anchor} }}"]
    if long_default:
        parts.append(code_block(var.raw, "Default"))
    for caption, lines in var.examples:
        parts.append(code_block(lines, caption))
    if var.after:
        prose = [x for x in var.after if not (CODE_LINE_RE.match(x) or x.startswith(" "))]
        code = [x for x in var.after if x not in prose]
        caption = " ".join(x.strip() for x in prose).rstrip(":.") or "Example (commented out in defaults/main.yml)"
        code = dedent(code) if code else var.after
        if not re.match(rf"{re.escape(var.name)}:(\s|$)", code[0]):
            # The commented-out value without its key, e.g. the keys of a dict below `var: {}`
            code = [f"{var.name}:", *("  " + x if x.strip() else x for x in code)]
        parts.append(code_block(code, caption))
    return "\n\n".join(parts)


def row(name: str, anchor: str, default: str, description: str) -> str:
    return "\n".join(
        [
            '<tr markdown="1">',
            f'<td markdown="span" id="{anchor}"><code>{name}</code></td>',
            f'<td markdown="block">{default}</td>',
            f'<td markdown="block">\n\n{description}\n\n</td>',
            "</tr>",
        ]
    )


def render_table(vars_: list[Var]) -> str:
    rows: list[str] = []
    details: list[str] = []
    for var in vars_:
        anchor = var.name
        details_anchor = f"{var.name}--details"
        default, long_default = default_cell(var, details_anchor)
        description = comment_to_markdown(var.description)
        has_details = long_default or var.examples or var.after
        if var.examples or var.after:
            description += f'\n\n<a href="#{details_anchor}">Example</a>'
        rows.append(row(var.name, anchor, default, description))
        for child in var.children:
            child_anchor = f"{var.name}.{child.name}"
            value = scalar_source(child)
            if value is not None and len(value) <= MAX_INLINE_DEFAULT and not is_jinja(value):
                cdefault = f"<code>{html.escape(value)}</code>" if value else ""
            elif value is not None and len(value) <= MAX_INLINE_DEFAULT:
                cdefault = f"\n```yaml\n{value}\n```\n"
            else:
                cdefault = f'see <a href="#{details_anchor}"><code>{var.name}</code></a>'
            rows.append(row(f"{var.name}.{child.name}", child_anchor, cdefault, comment_to_markdown(child.description)))
        if has_details:
            details.append(var_details(var, details_anchor, long_default))
    table = "\n".join(
        [
            '<table class="role-reference" markdown="1">',
            "<thead><tr><th>Variable</th><th>Default</th><th>Description</th></tr></thead>",
            '<tbody markdown="1">',
            *rows,
            "</tbody>",
            "</table>",
        ]
    )
    return "\n\n".join([table, *details])


def render_role(role: Role) -> str:
    assert role.path
    meta_path = role.path / "meta" / "main.yml"
    meta = YAML(typ="safe").load(meta_path.read_text()) if meta_path.is_file() else {}
    info = (meta or {}).get("galaxy_info") or {}
    description = str(info.get("description") or "").strip()

    defaults = role.path / "defaults" / "main.yml"
    header, items = parse_defaults(defaults) if defaults.is_file() else ([], [])
    LINK_NAMES.clear()
    LINK_NAMES.update(x.name for x in items if isinstance(x, Var) and not x.name.startswith("_"))

    out = [
        "---",
        f"title: {role.short_name}",
        f"summary: The variables of the {role.name} role {role.version}",
        "---",
        "",
        f"# {role.short_name}",
        "",
    ]
    if description:
        out += [description, ""]
    source = f"[{role.name} {role.version}]({role.tree_url})" if role.tree_url else f"{role.name} {role.version}"
    defaults_link = role.blob_url("defaults/main.yml")
    out += [
        f"Role {source}, the version in `requirements.yml`. The variables below are the defaults of the role, from "
        + (f"[defaults/main.yml]({defaults_link})." if defaults_link else "defaults/main.yml."),
        "",
    ]
    if header:
        out += [comment_to_markdown(header), ""]

    out += ["## Variables", ""]
    pending: list[Var] = []

    def flush():
        if pending:
            out.extend([render_table(pending), ""])
            pending.clear()

    for item in items:
        if isinstance(item, Note):
            flush()
            if item.heading:
                out += [f"### {item.heading}", ""]
            if any(x.strip() for x in item.text):
                description, examples = split_examples(item.text, {x.name for x in items if isinstance(x, Var)})
                text = comment_to_markdown(description)
                # A commented-out variable in a note, e.g. "Alternative locations:" followed by `# var: value`
                if looks_like_code(item.text):
                    text = code_block(dedent(item.text))
                out += [text, ""]
                for caption, lines in examples:
                    out += [code_block(lines, caption), ""]
            continue
        if item.name.startswith("_"):
            continue  # internal
        if item.heading:
            flush()
            out += [f"### {item.heading}", ""]
        pending.append(item)
    flush()
    return "\n".join(out).rstrip() + "\n"


def render_index(roles: list[Role], descriptions: dict[str, str]) -> str:
    out = [
        "---",
        "title: Roles",
        "summary: The variables of the PgVillage roles",
        "---",
        "",
        "# Roles",
        "",
        (
            "PgVillage deploys a cluster with these roles. Every page lists the variables of the role (the version in "
            "`requirements.yml`), with their defaults and descriptions. Set them in your inventory to change the "
            "defaults; see [The inventory](../../deploy/inventory/index.md)."
        ),
        "",
        (
            "The pages are generated from the comments in `defaults/main.yml` of every role, see "
            "[The role reference](../../developers/role-reference.md)."
        ),
        "",
        "| Role | Version | Description |",
        "| ---- | ------- | ----------- |",
    ]
    for role in sorted(roles, key=lambda r: r.short_name):
        desc = descriptions.get(role.name, "").replace("|", "\\|").replace("\n", " ")
        out.append(f"| [{role.short_name}]({role.short_name}.md) | {role.version} | {desc} |")
    return "\n".join(out) + "\n"


def generate(write) -> None:
    roles = read_requirements()
    install_roles(roles)
    descriptions = {}
    for role in roles:
        assert role.path
        meta_path = role.path / "meta" / "main.yml"
        meta = YAML(typ="safe").load(meta_path.read_text()) if meta_path.is_file() else {}
        descriptions[role.name] = str(((meta or {}).get("galaxy_info") or {}).get("description") or "").strip()
        write(f"{OUT_DIR}/{role.short_name}.md", render_role(role))
    write(f"{OUT_DIR}/index.md", render_index(roles, descriptions))


def main(standalone: bool) -> None:
    if standalone:
        if len(sys.argv) != 2:
            raise SystemExit(f"usage: {sys.argv[0]} <output dir>")
        # Standalone: write the pages into a folder
        target = Path(sys.argv[1])

        def write(path: str, text: str) -> None:
            dest = target / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text)

        generate(write)
        return

    import mkdocs_gen_files

    def write(path: str, text: str) -> None:
        with mkdocs_gen_files.open(path, "w") as f:
            f.write(text)
        mkdocs_gen_files.set_edit_path(path, None)

    generate(write)


if __name__ in ("__main__", "<run_path>"):
    try:
        main(standalone=__name__ == "__main__")
    except RoleReferenceError as err:
        if __name__ == "__main__":
            raise SystemExit(f"role reference: {err}") from None
        from mkdocs.exceptions import PluginError

        raise PluginError(f"role reference: {err}") from None
