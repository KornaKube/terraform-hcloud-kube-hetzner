#!/usr/bin/env python3
"""Generate a lightweight MkDocs site from README.md and kube.tf.example."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
KUBE_EXAMPLE = ROOT / "kube.tf.example"
SITE_DOCS = ROOT / "site-docs"
REPOSITORY_BLOB_BASE = (
    "https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/"
)
REPOSITORY_RAW_BASE = (
    "https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/"
)


def _extract_section(markdown: str, heading: str) -> str:
    pattern = re.compile(
        rf"^##+\s+{re.escape(heading)}\s*$([\s\S]*?)(?=^##+\s+|\Z)",
        re.MULTILINE,
    )
    match = pattern.search(markdown)
    return match.group(0).strip() if match else ""


def _extract_intro(markdown: str) -> str:
    lines = markdown.splitlines()
    cleaned: list[str] = []
    for line in lines:
        if line.startswith("# "):
            cleaned.append(line)
            continue
        if line.startswith("<") and line.endswith(">"):
            continue
        if line.strip().startswith("[!["):
            continue
        cleaned.append(line)
        if line.strip() == "---":
            break
    return "\n".join(cleaned).strip()


def _rewrite_repo_relative_links(markdown: str) -> str:
    """Keep extracted README links valid on the deployed MkDocs site."""

    link = re.compile(r"(!?\[[^\]]*\]\()([^)]+)(\))")

    def rewrite(match: re.Match[str]) -> str:
        target = match.group(2)
        if target.startswith(("#", "http://", "https://", "mailto:", "/", "../")):
            return match.group(0)
        base = (
            REPOSITORY_RAW_BASE
            if match.group(1).startswith("!")
            else REPOSITORY_BLOB_BASE
        )
        return f"{match.group(1)}{base}{target.removeprefix('./')}{match.group(3)}"

    return link.sub(rewrite, markdown)


def _module_body(example: str, module_name: str) -> str:
    match = re.search(rf'\bmodule\s+"{re.escape(module_name)}"\s*\{{', example)
    if not match:
        return example

    open_brace = example.rfind("{", match.start(), match.end())
    body_start = open_brace + 1
    depth = 1
    index = body_start
    in_string = False
    escaped = False
    in_block_comment = False

    while index < len(example):
        char = example[index]
        next_char = example[index + 1] if index + 1 < len(example) else ""

        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
                continue
            index += 1
            continue

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == "#":
            newline = example.find("\n", index)
            if newline == -1:
                break
            index = newline + 1
            continue

        if char == "/" and next_char == "/":
            newline = example.find("\n", index)
            if newline == -1:
                break
            index = newline + 1
            continue

        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return example[body_start:index]

        index += 1

    return example[body_start:]


def _update_depth(text: str, depth: int) -> int:
    in_string = False
    escaped = False
    index = 0

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == "#":
            break

        if char == "/" and next_char == "/":
            break

        if char == '"':
            in_string = True
        elif char in "{[(":
            depth += 1
        elif char in "}])":
            depth = max(0, depth - 1)

        index += 1

    return depth


def _code_before_comment(line: str) -> str:
    in_string = False
    escaped = False
    index = 0

    while index < len(line):
        char = line[index]
        next_char = line[index + 1] if index + 1 < len(line) else ""

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == "#":
            return line[:index]

        if char == "/" and next_char == "/":
            return line[:index]

        if char == '"':
            in_string = True

        index += 1

    return line


def _extract_configuration_keys(example: str) -> list[str]:
    keys: list[str] = []
    seen: set[str] = set()
    module_body = _module_body(example, "kube-hetzner")
    assignment = re.compile(r"^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=")
    commented_assignment = re.compile(r"^\s*#\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=")
    ignored = {"module", "variable", "locals", "output", "resource", "data", "terraform"}

    def add_key(key: str) -> None:
        if key in ignored or key in seen:
            return
        seen.add(key)
        keys.append(key)

    active_depth = 0
    commented_depth = 0

    for line in module_body.splitlines():
        code = _code_before_comment(line)

        if active_depth == 0:
            active_match = assignment.match(code)
            if active_match:
                add_key(active_match.group(1))

        if active_depth == 0:
            commented_match = commented_assignment.match(line)
            if commented_depth == 0 and commented_match:
                add_key(commented_match.group(1))
            if commented_depth > 0 or commented_match:
                commented_text = re.sub(r"^\s*#\s?", "", line)
                commented_depth = _update_depth(commented_text, commented_depth)

        active_depth = _update_depth(code, active_depth)

    return keys


def render() -> dict[Path, str]:
    readme = README.read_text(encoding="utf-8")
    kube_example = KUBE_EXAMPLE.read_text(encoding="utf-8")

    intro = _rewrite_repo_relative_links(_extract_intro(readme))
    quick_start = _rewrite_repo_relative_links(_extract_section(readme, "Quick Start"))
    architecture = _rewrite_repo_relative_links(_extract_section(readme, "Architecture"))

    index_content = "\n\n".join(
        [
            "# kube-hetzner",
            "> Generated from `README.md` by `scripts/sync_docs_site.py`.",
            intro or "",
            quick_start or "",
            architecture or "",
        ]
    ).strip() + "\n"

    keys = _extract_configuration_keys(kube_example)
    rows = "\n".join([f"- `{key}`" for key in keys])
    config_content = (
        "# Configuration Reference\n\n"
        "> Generated from `kube.tf.example` by `scripts/sync_docs_site.py`.\n\n"
        "## Detected Configuration Keys\n\n"
        f"{rows}\n"
    )

    return {
        SITE_DOCS / "index.md": index_content,
        SITE_DOCS / "configuration.md": config_content,
    }


def generate(*, check: bool = False) -> int:
    rendered = render()
    if check:
        stale = [
            path.relative_to(ROOT)
            for path, expected in rendered.items()
            if not path.is_file() or path.read_text(encoding="utf-8") != expected
        ]
        if stale:
            print("Generated site documentation is stale:")
            for path in stale:
                print(f"- {path}")
            return 1
        return 0

    SITE_DOCS.mkdir(parents=True, exist_ok=True)
    for path, content in rendered.items():
        path.write_text(content, encoding="utf-8")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail instead of writing when checked-in generated docs are stale",
    )
    args = parser.parse_args()
    raise SystemExit(generate(check=args.check))
