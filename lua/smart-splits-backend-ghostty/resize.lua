---@module 'smart-splits.backend'

local ghostty = require('smart-splits-backend-ghostty.ghostty')

local M = {}

---@param direction SmartSplitsDirection
---@param opts? SmartSplitsBackendResizeOpts
---@return boolean
function M.resize(direction, opts)
  opts = opts or {}
  return ghostty.resize(direction, opts.amount)
end

return M
