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

This runs formatting, the documentation check, LuaLS, Selene, and the focused
tests in Neovim. Use `just fmt`, `just lint`, `just typecheck`, `just docs`, or
`just test` individually. Pass Busted options through the environment, for
example: `BUSTED_ARGS='--filter=transport' just test`.

## Documentation

`README.md` is the only place documentation is written. `just docs` regenerates
`doc/ghostty-smart-splits.txt` from it with
[panvimdoc](https://github.com/kdheepak/panvimdoc) and rebuilds `doc/tags`.
Both generated files are committed; run `just docs` and include the result in
any commit that touches the README. CI runs `just docs-check`, which fails when
they disagree.

`examples/ghostty.conf` duplicates the README's Ghostty config block by hand.
Keep the two in step when either changes.

panvimdoc comes from the pinned flake, so the output is identical locally and
in CI. A few README conventions keep the generated help readable:

- Headings become help tags. Keep them short and free of parentheses, or the
  tag and its table-of-contents entry overflow 78 columns. Two headings at the
  same level with the same text collide; `just docs` runs `:helptags` and fails
  on the duplicate.

- A link to another section must use the target heading as its text.
  panvimdoc builds the help cross-reference from the link text and ignores the
  `#anchor`, so `[the mappings below](#neovim-mappings)` produces a reference no
  tag matches. `just docs` fails on a dangling reference. Links to subheadings
  cannot work at all, because their tags carry the parent heading as a prefix.

- Content above the first `##` heading is not rendered as a section, so the
  title, tagline, and demo video sit between `<!-- panvimdoc-ignore-start -->`
  and `<!-- panvimdoc-ignore-end -->`.

- Separate list items with a blank line. panvimdoc re-wraps loose lists to 78
  columns and leaves tight ones on one long line.

- Prefer two-column tables. Wider ones are squeezed into narrow columns and
  their inline code markup is dropped.

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

Both transports run [`scripts/ghostty.js`](scripts/ghostty.js) and address the Ghostty or cmux process owning
the current Neovim instance.

cmux mirrors Ghostty's scripting dictionary under its own four-character codes so he script
keeps one code table per app.

The ephemeral transport runs one command per osascript process and the persistent transport
keeps the script running with `serve` and reads newline-delimited JSON requests from stdin.
Syntax-check the scripts with:

```sh
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
osacompile -l JavaScript -o "$tmpdir/ghostty.scpt" scripts/ghostty.js
osacompile -l JavaScript -o "$tmpdir/tests.scpt" tests/ghostty.js
```

Use Conventional Commit prefixes such as `fix:` and `feat:`. Changes to
navigation, lifecycle handling, or the transports should
include `just test-e2e` results when possible.
