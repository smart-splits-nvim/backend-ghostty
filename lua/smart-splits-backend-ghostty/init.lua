---@module 'smart-splits.backend'

local config = require('smart-splits-backend-ghostty.config')
local ghostty = require('smart-splits-backend-ghostty.ghostty')
local health = require('smart-splits-backend-ghostty.health')
local lifecycle = require('smart-splits-backend-ghostty.lifecycle')
local move = require('smart-splits-backend-ghostty.move')
local resize = require('smart-splits-backend-ghostty.resize')

---@type SmartSplitsBackend
local M = {
  name = 'smart-splits-backend-ghostty',
  protocol_version = '3.0.0',
  -- Configuration is inert: only the selected backend may attach or claim keys.
  ---@param opts? GhosttyBackend.PartialConfig
  setup = function(opts)
    lifecycle.configure(opts)
  end,
  detect = function()
    return config.options.enable and ghostty.detect()
  end,
  move = move.move,
  resize = resize.resize,
  activate = lifecycle.activate,
  health = health.report,
  claim_keys = lifecycle.claim_keys,
  release_keys = lifecycle.release_keys,
}

return M
