---@module 'smart-splits.backend'

local ghostty = require('smart-splits-backend-ghostty.ghostty')

local M = {}

-- Core delegates `at_edge` here and only handles it inside Neovim's layout when
-- this returns false. Ghostty cannot wrap, so `wrap` is left to core; `split`
-- becomes a Ghostty split, falling back to a Neovim one when Ghostty refuses.
---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendMoveOpts
---@return boolean
function M.move(direction, opts)
  opts = opts or {}
  if ghostty.move(direction) then
    return true
  end
  if opts.at_edge == 'split' then
    return ghostty.split(direction)
  end
  return false
end

return M
