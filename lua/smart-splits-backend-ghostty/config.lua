---`persistent` keeps one osascript process running and falls back to `ephemeral`
---when it cannot answer; `ephemeral` starts osascript for every request.
---@alias GhosttyBackend.Transport 'persistent'|'ephemeral'

---@class GhosttyBackend.Config
---@field enable boolean Set false to make `detect()` fail without uninstalling the plugin.
---@field key_table string Ghostty key table used while Neovim is active.
---@field transport GhosttyBackend.Transport How actions and pane lookups reach Ghostty.

---@class GhosttyBackend.PartialConfig
---@field enable? boolean Set false to make `detect()` fail without uninstalling the plugin.
---@field key_table? string Name of the Ghostty key table used while Neovim is active.
---@field transport? GhosttyBackend.Transport How actions and pane lookups reach Ghostty (default 'persistent').

local M = {}

---@type GhosttyBackend.Config
M.defaults = {
  enable = true,
  key_table = 'nvim',
  transport = 'persistent',
}

---@type GhosttyBackend.Config
M.options = vim.deepcopy(M.defaults)

local validators = {
  enable = function(value)
    return type(value) == 'boolean', 'enable must be a boolean'
  end,
  key_table = function(value)
    return type(value) == 'string' and value ~= '', 'key_table must be a non-empty string'
  end,
  transport = function(value)
    return value == 'persistent' or value == 'ephemeral', "transport must be 'persistent' or 'ephemeral'"
  end,
}

---Validate every option before anything is stored, so a rejected call leaves
---the previous configuration intact.
---@param opts table
local function validate(opts)
  for key, value in pairs(opts) do
    local validator = validators[key]
    assert(validator, ('unknown option `%s`'):format(tostring(key)))
    local ok, message = validator(value)
    assert(ok, message)
  end
end

---Merge over the current options rather than over the defaults. Ghostty holds
---the active key table and the transport is switched at runtime, so resetting
---either from a call that never mentioned it would desynchronise the plugin
---from the terminal. Call reset() for a clean slate.
---@param opts? GhosttyBackend.PartialConfig
---@return GhosttyBackend.Config
function M.setup(opts)
  opts = opts or {}
  validate(opts)
  M.options = vim.tbl_extend('force', M.options, opts)
  return M.options
end

---The key table `opts` would select, without applying it. Lets a caller reject
---a change before any option is stored.
---@param opts? GhosttyBackend.PartialConfig
---@return string
function M.resolve_key_table(opts)
  local name = (opts or {}).key_table
  if name == nil then
    return M.options.key_table
  end
  local ok, message = validators.key_table(name)
  assert(ok, message)
  return name
end

---Restore every option to its default.
function M.reset()
  M.options = vim.deepcopy(M.defaults)
end

return M
