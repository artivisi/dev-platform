#!/usr/bin/env bash
#
# Compiles every document in this repository.
#
# Documents import shared modules by root-relative path (/shared/..., /template/...)
# and the hardware document reads the Ansible tier files (/ansible/...), so typst
# is always invoked with --root at the repository root.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v typst >/dev/null; then
    echo "typst not found — install it before building." >&2
    exit 1
fi

# --- Diagrams ----------------------------------------------------------------
# Diagrams are mermaid (.mmd) so anyone can read and edit them without learning
# Typst, and so GitHub renders them in the browser. Typst cannot read mermaid, so
# each one is rendered to PNG here and the PNG is committed next to its source —
# the same arrangement as the compiled PDFs.
#
# mermaid-cli drives a headless browser. It is pointed at the system Chrome
# rather than downloading its own copy; if that path is wrong on your machine,
# fix scripts/puppeteer-config.json. Nothing is defaulted: a missing tool is a
# hard failure, because a silently skipped diagram means a document that builds
# successfully with a stale picture in it.
PUPPETEER_CONFIG="$HERE/scripts/puppeteer-config.json"

render_diagrams() {
    local mmd png changed=0
    shopt -s nullglob
    for mmd in "$HERE"/*/diagrams/*.mmd; do
        png="${mmd%.mmd}.png"
        [[ -f "$png" && "$png" -nt "$mmd" ]] && continue
        changed=1
        if ! command -v mmdc >/dev/null; then
            echo "mmdc not found, but $(basename "$mmd") needs rendering." >&2
            echo "  npm install -g @mermaid-js/mermaid-cli" >&2
            exit 1
        fi
        local chrome
        chrome="$(sed -n 's/.*"executablePath"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' "$PUPPETEER_CONFIG")"
        if [[ ! -x "$chrome" ]]; then
            echo "Chrome not found at: $chrome" >&2
            echo "  fix executablePath in scripts/puppeteer-config.json" >&2
            exit 1
        fi
        echo "==> $(basename "$mmd")"
        mmdc -p "$PUPPETEER_CONFIG" -i "$mmd" -o "$png" --scale 3 >/dev/null
    done
    shopt -u nullglob
    [[ $changed -eq 0 ]] && echo "==> diagrams up to date"
    return 0
}

render_diagrams

# PDFs are committed alongside their sources, so a rebuild that changes nothing
# must produce byte-identical files — otherwise every build marks all three
# documents modified and `git status` stops being able to tell you whether a
# document actually changed.
#
# Typst stamps the wall clock into the PDF unless SOURCE_DATE_EPOCH is set, so
# two builds of identical sources differ. It is pinned rather than derived from
# git: deriving it means the bytes change on the next commit even when the
# content did not, which is the same problem one step removed. The value is
# arbitrary and the metadata date it produces is meaningless — the date a reader
# sees is the one on the cover, set in each document's own `date:` field.
export SOURCE_DATE_EPOCH=1767225600      # 2026-01-01T00:00:00Z, a fixed sentinel

compile() {
    local src="$1" out="$2"
    echo "==> $src"
    typst compile --root . "$src" "$out"
}

compile hardware/spec.typ  hardware/Hardware-Specification.pdf
compile setup/guide.typ    setup/Setup-Guide.pdf
compile workflow/guide.typ workflow/Developer-Guide.pdf

echo
echo "Built. Eyeball every page before committing — layout defects such as"
echo "caption misclassification and diagram label collisions are not compile"
echo "errors and will not appear above."
