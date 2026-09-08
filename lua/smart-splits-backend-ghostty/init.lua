-- smart-splits v3 interface; transport and lifecycle are shared with v2.
local ghostty = require('ghostty-smart-splits.ghostty')
local session = require('ghostty-smart-splits.session')
local M = {
  name = 'ghostty',
  protocol_version = '3.0.0',
}

-- Configuration is inert: only the selected backend may attach or claim keys.
---@param opts? GhosttySmartSplitsConfig
function M.setup(opts)
  session.configure(opts)
end
M.detect = ghostty.detect
M.activate = session.activate

-- Core delegates `at_edge` here and only handles it inside Neovim's layout when
-- this returns false. Ghostty cannot wrap, so `wrap` is left to core; `split`
-- becomes a Ghostty split, falling back to a Neovim one when Ghostty refuses.
---@param opts? { at_edge?: 'stop'|'wrap'|'split' }
function M.move(direction, opts)
  if ghostty.move(direction) then
    return true
  end
  if (opts or {}).at_edge == 'split' then
    return ghostty.split(direction)
  end
  return false
end

function M.resize(direction, opts)
  return ghostty.resize(direction, (opts or {}).amount)
end

function M.health()
  require('ghostty-smart-splits.health').report()
end

return M
