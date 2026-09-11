# backend-ghostty

Navigate between Neovim splits and Ghostty panes on macOS with the same keys.
smart-splits handles Neovim windows first; at an editor edge, the matching Ghostty binding handles the pane.

A macOS bridge for [smart-splits.nvim](https://github.com/smart-splits-nvim/smart-splits.nvim).

Supports smart-splits v2 and the experimental v3 backend.

https://github.com/user-attachments/assets/774b72c1-acd5-48fa-9b03-406f2cc740ab

## Requirements

- Neovim 0.11+, smart-splits.nvim, and Ghostty 1.3+ or [cmux](https://cmux.com) on macOS.
- Ghostty AppleScript enabled (the default) and macOS Automation permission.

### cmux

cmux embeds Ghostty and reads the same Ghostty config file so the same configuration applies; run `cmux reload-config` after editing it.

cmux reports `goto_split` as performed even when no pane lies in that direction, so a move is called successful only once focus has actually left the Neovim pane.
That costs one extra pane lookup per move in cmux.

## Installation

Choose one integration below, then add the [Neovim mappings](#neovim-mappings) and [Ghostty configuration](#ghostty-configuration).
Both are required.

### smart-splits v2

With lazy.nvim:

```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  lazy = false,
  dependencies = { 'smart-splits-nvim/backend-ghostty' },
  config = function()
    require('smart-splits').setup({}) -- Your existing options.
    require('ghostty-smart-splits').setup()
  end,
}
```

With `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  'https://github.com/smart-splits-nvim/smart-splits.nvim',
  'https://github.com/smart-splits-nvim/backend-ghostty',
})

require('smart-splits').setup({}) -- Your existing options.
require('ghostty-smart-splits').setup()
```

### smart-splits v3 (experimental)

Use smart-splits' `v3` Git ref.
The protocol and backend may change before release.

With lazy.nvim:

```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  branch = 'v3',
  lazy = false,
  dependencies = {
    {
      'smart-splits-nvim/backend-ghostty',
      main = 'smart-splits-backend-ghostty',
    },
  },
  opts = {
    mux = {
      backend = 'smart-splits-backend-ghostty',
    },
    move = {
      at_edge = 'stop',
    },
  },
}
```

With `vim.pack` (Neovim 0.12+):

```lua
vim.pack.add({
  {
    src = 'https://github.com/smart-splits-nvim/smart-splits.nvim',
    version = 'v3',
  },
  'https://github.com/smart-splits-nvim/backend-ghostty',
})

require('smart-splits').setup({
  mux = {
    backend = 'smart-splits-backend-ghostty',
  },
  move = {
    at_edge = 'stop',
  },
})
```

Do not call the v2 `ghostty-smart-splits` setup when using v3.

## Neovim mappings

Neither plugin creates mappings automatically.
Add these after your plugin setup (after `require('lazy').setup(...)` when using lazy.nvim).
They work with both v2 and v3 and match the Ghostty configuration below.

```lua
local splits = require('smart-splits')

vim.keymap.set('n', '<C-h>', splits.move_cursor_left)
vim.keymap.set('n', '<C-j>', splits.move_cursor_down)
vim.keymap.set('n', '<C-k>', splits.move_cursor_up)
vim.keymap.set('n', '<C-l>', splits.move_cursor_right)

vim.keymap.set('n', '<M-h>', splits.resize_left)
vim.keymap.set('n', '<M-j>', splits.resize_down)
vim.keymap.set('n', '<M-k>', splits.resize_up)
vim.keymap.set('n', '<M-l>', splits.resize_right)
```

These mappings apply in Normal mode.
`<M-...>` is the Mac Option/Alt key.

## Ghostty configuration

Copy this to your Ghostty config, reload it, then start Neovim in the target pane.

```ini
# Outside Neovim.
# Move
keybind = performable:ctrl+h=goto_split:left
keybind = performable:ctrl+j=goto_split:down
keybind = performable:ctrl+k=goto_split:up
keybind = performable:ctrl+l=goto_split:right

# Resize
keybind = performable:alt+h=resize_split:left,30
keybind = performable:alt+j=resize_split:down,30
keybind = performable:alt+k=resize_split:up,30
keybind = performable:alt+l=resize_split:right,30

# Inside Neovim.
keybind = nvim/
# Move
keybind = nvim/ctrl+h=text:\x08
keybind = nvim/ctrl+j=text:\x0a
keybind = nvim/ctrl+k=text:\x0b
keybind = nvim/ctrl+l=text:\x0c

# Resize
keybind = nvim/alt+h=esc:h
keybind = nvim/alt+j=esc:j
keybind = nvim/alt+k=esc:k
keybind = nvim/alt+l=esc:l
```

The keys in Neovim and Ghostty must match.

## Configuration

Both integrations accept the same backend options:

| Option | Default | Behavior |
| --- | --- | --- |
| `key_table` | `'nvim'` | Ghostty key table used while Neovim is active. |
| `transport` | `'persistent'` | How actions and pane lookups reach Ghostty. `'persistent'` keeps one `osascript` process running and falls back to `'ephemeral'` when it cannot answer. `'ephemeral'` starts `osascript` for every request. |
| `bridge` | | Deprecated alias for `transport`: `true` selects `'persistent'` and `false` selects `'ephemeral'`. It still works, with a warning. |

With v2, pass them to the plugin setup:

```lua
require('ghostty-smart-splits').setup({
  key_table = 'nvim',
  transport = 'persistent', -- Or 'ephemeral' to start osascript for every request.
})
```

With v3, configure the backend **before** smart-splits selects and activates it:

```lua
require('smart-splits-backend-ghostty').setup({
  key_table = 'nvim',
  transport = 'persistent', -- Or 'ephemeral' to start osascript for every request.
})
require('smart-splits').setup({
  mux = { backend = 'smart-splits-backend-ghostty' },
  move = { at_edge = 'stop' },
})
```

`setup` merges over the current options: a call that names one option leaves the rest alone, so the transport can be switched at runtime without repeating `key_table`.
An unknown option name is an error rather than a silent no-op.
Call `require('ghostty-smart-splits.config').reset()` to restore every default.

Changing `key_table` to a different name while it is claimed is an error; release it first.
Switching to `'ephemeral'` stops a running persistent process immediately; switching to `'persistent'` starts one on the next attachment or action.

The v2 setup adds `multiplexer_integration = 'ghostty'` and `at_edge = 'stop'`.

### v3 edge behavior

Set `move.at_edge` in smart-splits, not in the backend options:

```lua
require('smart-splits').setup({
  mux = { backend = 'smart-splits-backend-ghostty' },
  move = { at_edge = 'wrap' }, -- 'stop', 'wrap', or 'split'
})
```

Movement first tries a Neovim window, then a neighboring Ghostty pane.
If neither exists in the requested direction:

| `move.at_edge` | Behavior |
| --- | --- |
| `'stop'` | Stay in the current Neovim window. |
| `'wrap'` | Wrap to the opposite edge of the Neovim layout within the current Ghostty pane. With one Neovim window, stay there. Ghostty panes are not wrapped. |
| `'split'` | Create and focus a Ghostty pane in that direction. If Ghostty cannot create it, smart-splits falls back to creating a Neovim split. |

All three modes navigate to an existing Ghostty neighbor.
In particular, `'stop'` does not prevent crossing the Neovim/Ghostty boundary.
A custom `move.at_edge` function is handled by smart-splits after the backend cannot move.

### Zoom and fullscreen

The backend does not detect zoom/fullscreen or suppress navigation in those states.
Movement inside Neovim still takes priority.
At an editor edge, Ghostty handles the usual `goto_split` action.
There is no `disable_nav_when_zoomed` backend option.

On Ghostty 1.3.1, navigating to a neighbor from a zoomed pane leaves split zoom.
Window fullscreen also allows navigation between Neovim windows and Ghostty panes.

### Diagnostics

In local measurements, actions took about 15 ms with `'persistent'` versus about 100 ms with `'ephemeral'`; results vary by machine.

### Persistent transport

The default, `transport = 'persistent'`, keeps [`scripts/ghostty.js`](scripts/ghostty.js) running in one `osascript` process per Neovim instance, instead of starting a new process for every request.
Both transports address the Ghostty process that owns Neovim, so separate Ghostty instances can run alongside each other.
Every request goes through the persistent process, including the pane lookups smart-splits v2 makes before and after each move.
Nothing needs to be built.
Set `transport = 'ephemeral'` if you would rather not keep a process running.

#### Migrating from the bridge

Earlier versions started `osascript` for every request unless you built and enabled a compiled Swift bridge.
The persistent transport is now the default, and both bridge settings still work but are deprecated:

- `bridge = true` selects `'persistent'`, the new default, and `bridge = false` selects `'ephemeral'`.
  Either warns once per session: remove `bridge = true`, or replace `bridge = false` with `transport = 'ephemeral'`.
- `make bridge` no longer builds anything; it prints a deprecation notice and succeeds.
  Remove `build = 'make bridge'` or the `PackChanged` build hook from your config.

Run `just bench` from the Nix development shell to benchmark locally.

## How it works

Ghostty's `performable` bindings give Neovim first chance at each key.
This plugin uses Ghostty's AppleScript API when smart-splits reaches an editor edge, and keeps a temporary key table active while Neovim is running.

## API

```lua
require('ghostty-smart-splits').claim_keys()
require('ghostty-smart-splits').release_keys()
```

Keys are claimed and released automatically on Neovim suspend, resume, and exit.
Use the functions above only when managing the table manually.

Run `:checkhealth ghostty-smart-splits` for local prerequisites.
With v3, `:checkhealth smart-splits` also includes backend diagnostics.

## Limitations

- macOS only.
  Action AppleScript calls are synchronous and time out after one second.
- The initial Ghostty terminal comes from the focused pane and the lookup is asynchronous.
  Later actions keep using that terminal instead of following focus changes.
  A failed lookup is retried when Neovim next regains focus, so answering the macOS Automation prompt recovers the session without restarting Neovim.
  After five failures it stops trying and warns once.
- Do not stack another Ghostty key table above this one while Neovim is active.
  If a crash or config reload leaves stale state, Ghostty's `deactivate_all_key_tables` action can recover it, but clears every table.
