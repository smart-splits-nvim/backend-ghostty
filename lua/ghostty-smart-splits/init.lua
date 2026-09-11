local M = {}
local ghostty = require('ghostty-smart-splits.ghostty')
local lifecycle = require('ghostty-smart-splits.lifecycle')

M.claim_keys = lifecycle.claim_keys
M.release_keys = lifecycle.release_keys

---Attach Ghostty and apply required smart-splits settings. False means unavailable.
---@param opts? GhosttySmartSplitsConfig
---@return boolean
function M.setup(opts)
  if not ghostty.detect() then
    return false
  end
  lifecycle.configure(opts)
  local smart_splits = require('smart-splits')
  smart_splits.setup({
    multiplexer_integration = 'ghostty',
    at_edge = 'stop',
  })
  return lifecycle.activate()
end

return M
