# Contributing

This project targets macOS and Ghostty. [Install Nix](https://nixos.org/download/)
with flakes enabled, then enter the pinned development environment:

```sh
nix develop
```

With direnv installed, run `direnv allow` once instead. The checked-in flake
provides the same Neovim, Lua, formatting, linting, type-checking, and command
runner versions locally and in CI.

Run the fast checks from the repository root:

```sh
just check
```

This runs formatting, LuaLS, Selene, and the focused tests in Neovim. Use
`just fmt`, `just lint`, `just typecheck`, or `just test` individually.
Pass Busted options through the environment, for example:
`BUSTED_ARGS='--filter=transport' just test`.

CI also runs the tests against Neovim 0.11 and nightly with the `ci-0_11`
and `ci-nightly` shells, for example:

```sh
nix develop .#ci-nightly --command just test
```

The nightly build comes from the
[nix-community binary cache](https://nix-community.org/cache/); without that
cache configured, Nix compiles Neovim from source. CI runs
`nix flake update neovim-nightly-overlay` first to test the latest nightly.

## Real Ghostty tests

These require a logged-in macOS desktop, Ghostty 1.3 or newer at
`/Applications/Ghostty.app`, Neovim 0.11 or newer, and macOS Automation
permission.

```sh
just test-e2e
```

The harness launches a separate Ghostty process with
`tests/e2e/ghostty.conf`, so existing sessions can stay open. It runs real
Neovim and Ghostty through smart-splits v2 and v3, using both the ephemeral and
persistent transports. It checks split movement, shell movement, resizing,
`Ctrl-Z`/`fg`, key-table lifecycle, and navigation after Neovim exits.
The v3 sessions also check all three `move.at_edge` modes at the outer edge
and with existing neighbors, directional pane creation, navigation out of
split zoom, and navigation in native macOS fullscreen. Each direction is
tested with both transports. Fullscreen tests temporarily switch macOS Spaces.

Persistent sessions verify a real `serve` child process and reject any
ephemeral fallback after initial attachment. The upstream v2/v3 checkouts are
downloaded to ignored `deps/` when needed; override them with
`SMART_SPLITS_DIR` and `SMART_SPLITS_V3_DIR`.

E2E is local-only because it needs a graphical session and Automation
permission. It is excluded from `just check` and CI.

## Benchmark

`just bench` launches its own Ghostty instance and window. Existing sessions
can stay open. It measures real ephemeral and persistent round-trips in two
temporary panes, prints latency statistics, and closes the test instance.

```sh
just bench
BENCH_ARGS='--pairs 30 --warmup 4 --json /tmp/ghostty-bench.json' just bench
```

Leave the benchmark window alone until it finishes. A forced interruption may
leave that disposable window open.

## Automation and transports

Both transports run [`scripts/ghostty.js`](scripts/ghostty.js) and address the
Ghostty process owning the current Neovim instance. The ephemeral transport
runs one command per osascript process; the persistent transport keeps the
script running with `serve` and reads newline-delimited JSON requests from
stdin. Syntax-check the scripts with:

```sh
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
osacompile -l JavaScript -o "$tmpdir/ghostty.scpt" scripts/ghostty.js
osacompile -l JavaScript -o "$tmpdir/tests.scpt" tests/ghostty.js
```

Use Conventional Commit prefixes such as `fix:` and `feat:`. Changes to
navigation, lifecycle handling, or the transports should
include `just test-e2e` results when possible.
