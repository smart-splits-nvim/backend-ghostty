# Smart-splits revisions to test against
SMART_SPLITS_V2_REV := "master"
SMART_SPLITS_V3_REV := "v3"

# Vimdoc header line; panvimdoc stamps a date instead when this is empty.
DOC_DESCRIPTION := "Neovim-first Ghostty navigation on macOS"

# Clone smart-splits v2 (no-op if already present)
[private]
deps-v2:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${SMART_SPLITS_DIR:-deps/smart-splits.nvim}"
    if [ -d "$dir/.git" ]; then
      exit 0
    fi
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    git clone --filter=blob:none --no-checkout https://github.com/smart-splits-nvim/smart-splits.nvim "$dir"
    git -C "$dir" checkout --quiet "${SMART_SPLITS_V2_REF:-{{SMART_SPLITS_V2_REV}}}"

# Clone smart-splits v3 at the requested revision
[private]
deps-v3:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${SMART_SPLITS_V3_DIR:-deps/smart-splits-v3.nvim}"
    rev="${SMART_SPLITS_V3_REF:-{{SMART_SPLITS_V3_REV}}}"
    if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$(git -C "$dir" rev-parse "$rev" 2>/dev/null)" ]; then
      exit 0
    fi
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    git clone --filter=blob:none --no-checkout https://github.com/smart-splits-nvim/smart-splits.nvim "$dir"
    git -C "$dir" checkout --quiet "$rev"

# Force re-clone smart-splits dependencies
[private]
deps-force:
    rm -rf "${SMART_SPLITS_DIR:-deps/smart-splits.nvim}" "${SMART_SPLITS_V3_DIR:-deps/smart-splits-v3.nvim}"
    just deps-v2
    just deps-v3

# Run focused core tests
test: test-core

test-core: deps-v3
    SMART_SPLITS_DIR="$(cd "${SMART_SPLITS_V3_DIR:-deps/smart-splits-v3.nvim}" && pwd)" \
      XDG_STATE_HOME="${TEST_STATE_HOME:-/tmp/ghostty-smart-splits.nvim}" \
      busted --run=core ${BUSTED_ARGS:-} < /dev/null

# Run real Ghostty workflows in a dedicated instance (macOS only)
test-e2e: deps-v2 deps-v3
    SMART_SPLITS_DIR="$(cd "${SMART_SPLITS_DIR:-deps/smart-splits.nvim}" && pwd)" \
      SMART_SPLITS_V3_DIR="$(cd "${SMART_SPLITS_V3_DIR:-deps/smart-splits-v3.nvim}" && pwd)" \
      nvim --headless -u NONE -i NONE -l tests/e2e/run.lua

# Benchmark real transports in a dedicated Ghostty instance (macOS only)
bench:
    nvim --headless -u NONE -i NONE -l tests/bench/run.lua ${BENCH_ARGS:-}

# Regenerate doc/ and examples/ from README.md into DEST
[private]
gen-docs dest:
    #!/usr/bin/env bash
    set -euo pipefail
    src="$PWD"
    mkdir -p "{{dest}}/doc"
    cd "{{dest}}"
    if [ "$PWD" != "$src" ]; then
      cp "$src/README.md" README.md
    fi
    # panvimdoc writes doc/<project>.txt relative to the working directory, and
    # reports failures on stdout, so keep its output for the error path.
    # GITHUB_ACTIONS=true makes it look for its Lua filters in /scripts, which
    # only exists inside its own Docker action; unset it so it finds its own.
    if ! out="$(GITHUB_ACTIONS=false panvimdoc \
      --project-name ghostty-smart-splits \
      --input-file README.md \
      --description "{{DOC_DESCRIPTION}}" \
      --shift-heading-level-by -1 \
      --toc true \
      --dedup-subheadings true \
      --demojify true 2>&1)"; then
      printf '%s\n' "$out" >&2
      exit 1
    fi
    # panvimdoc pads the blank lines inside code blocks; .editorconfig trims
    # trailing whitespace everywhere. sed -i is not portable, hence the copy.
    tmp="$(mktemp)"
    sed -e 's/[[:space:]]*$//' doc/ghostty-smart-splits.txt > "$tmp"
    mv "$tmp" doc/ghostty-smart-splits.txt
    # doc/tags is committed: Neovim does not build it for plugins dropped into
    # pack/*/start, and :help then fails with E149. Output is byte-identical
    # across Neovim versions and locales, so it diffs cleanly.
    # This also catches duplicate tags, which panvimdoc emits without
    # complaining and plugin managers swallow behind a pcall. Neovim reports
    # E154 on stderr but still exits 0, hence the stderr test.
    if ! err="$(nvim --headless -u NONE -i NONE -c 'helptags doc' -c 'quitall' 2>&1)" \
      || [ -n "$err" ]; then
      printf '%s\n' "$err" >&2
      echo >&2 "helptags rejected the generated vimdoc."
      exit 1
    fi

# Regenerate the vimdoc and its tags from README.md
docs: (gen-docs ".")

# Fail if the generated docs are stale
docs-check:
    #!/usr/bin/env bash
    set -euo pipefail
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    just gen-docs "$tmpdir"
    if ! diff -ru doc "$tmpdir/doc"; then
      echo >&2 "README.md and doc/ disagree. Run 'just docs' and commit the result."
      exit 1
    fi

# Check formatting
fmt-check:
    stylua --check lua tests

# Format code
fmt:
    stylua lua tests

# Run Selene
lint:
    selene ./lua/ ./tests/

# Run LuaLS type checking
typecheck: deps-v3
    #!/usr/bin/env bash
    set -euo pipefail
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    VIMRUNTIME="$(nvim --clean -i NONE --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quitall')" \
      lua-language-server --check=. --checklevel=Warning --check_format=pretty \
      --configpath=.luarc.json --logpath="$tmpdir/luals"

# Run all fast checks
check: fmt-check docs-check lint typecheck test
