# Smart-splits revisions to test against
SMART_SPLITS_V2_REV := "master"
SMART_SPLITS_V3_REV := "v3"

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
test-e2e: bridge deps-v2 deps-v3
    SMART_SPLITS_DIR="$(cd "${SMART_SPLITS_DIR:-deps/smart-splits.nvim}" && pwd)" \
      SMART_SPLITS_V3_DIR="$(cd "${SMART_SPLITS_V3_DIR:-deps/smart-splits-v3.nvim}" && pwd)" \
      nvim --headless -u NONE -i NONE -l tests/e2e/run.lua

# Benchmark real transports in a dedicated Ghostty instance (macOS only)
bench: bridge
    nvim --headless -u NONE -i NONE -l tests/bench/run.lua ${BENCH_ARGS:-}

# Build the optional macOS bridge
bridge:
    make bridge

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
check: fmt-check lint typecheck test
