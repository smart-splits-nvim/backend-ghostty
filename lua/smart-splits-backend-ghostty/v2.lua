-- smart-splits v2 integration. v2 has no backend protocol: it requires
-- `smart-splits.mux.<multiplexer_integration>` and never calls `activate()`,
-- so setup() registers that module and activates in one go.
local backend = require('smart-splits-backend-ghostty')
local lifecycle = require('smart-splits-backend-ghostty.lifecycle')

local M = {}

M.claim_keys = lifecycle.claim_keys
M.release_keys = lifecycle.release_keys

---Attach Ghostty and apply required smart-splits settings. False means unavailable.
---@param opts? GhosttyBackend.PartialConfig
---@return boolean
function M.setup(opts)
  lifecycle.configure(opts)
  if not backend.detect() then
    return false
  end
  -- Registered here rather than shipped as lua/smart-splits/mux/ghostty.lua, so
  -- this plugin has one top-level module and plugin managers can find it.
  package.preload['smart-splits.mux.ghostty'] = function()
    return require('smart-splits-backend-ghostty.mux')
  end
  local smart_splits = require('smart-splits')
  smart_splits.setup({
    multiplexer_integration = 'ghostty',
    at_edge = 'stop',
  })
  return lifecycle.activate()
end

return M
