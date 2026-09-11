---Plugin options, merged additively so a call that names one option leaves the
---rest alone. Read them as fields: `config.transport`, not `config.get_transport()`.
---@class GhosttySmartSplitsConfigModule
---@field key_table string Ghostty key table used while Neovim is active.
---@field transport GhosttySmartSplitsTransport How actions and pane lookups reach Ghostty.
---@field bridge boolean Deprecated: whether `transport` is `'persistent'`.
local M = {}

---`persistent` keeps one osascript process running and falls back to `ephemeral`
---when it cannot answer; `ephemeral` starts osascript for every request.
---@alias GhosttySmartSplitsTransport 'persistent'|'ephemeral'

---@class GhosttySmartSplitsConfig
---@field key_table? string Name of the Ghostty key table used while Neovim is active.
---@field transport? GhosttySmartSplitsTransport How actions and pane lookups reach Ghostty (default 'persistent').
---@field bridge? boolean Deprecated: use `transport`. true is 'persistent', false is 'ephemeral'.

local defaults = {
  key_table = 'nvim',
  transport = 'persistent',
}

local validators = {
  key_table = function(value)
    return type(value) == 'string' and value ~= '', 'key_table must be a non-empty string'
  end,
  transport = function(value)
    return value == 'persistent' or value == 'ephemeral', "transport must be 'persistent' or 'ephemeral'"
  end,
  bridge = function(value)
    return type(value) == 'boolean', 'bridge must be a boolean'
  end,
}

local options = vim.deepcopy(defaults)

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
---@param opts? GhosttySmartSplitsConfig
function M.setup(opts)
  opts = opts or {}
  validate(opts)
  local changes = vim.tbl_extend('force', {}, opts)
  if changes.bridge ~= nil then
    vim.notify_once(
      "ghostty-smart-splits: `bridge` is deprecated; use `transport = 'persistent'` or `transport = 'ephemeral'`",
      vim.log.levels.WARN
    )
    -- An explicit `transport` in the same call wins over the old name.
    if changes.transport == nil then
      changes.transport = changes.bridge and 'persistent' or 'ephemeral'
    end
    changes.bridge = nil
  end
  options = vim.tbl_extend('force', options, changes)
end

---The key table `opts` would select, without applying it. Lets a caller reject
---a change before any option is stored.
---@param opts? GhosttySmartSplitsConfig
---@return string
function M.resolve_key_table(opts)
  local name = (opts or {}).key_table
  if name == nil then
    return options.key_table
  end
  local ok, message = validators.key_table(name)
  assert(ok, message)
  return name
end

---Restore every option to its default.
function M.reset()
  options = vim.deepcopy(defaults)
end

setmetatable(M, {
  __index = function(_, key)
    -- Keep answering the deprecated boolean for code that still reads it.
    if key == 'bridge' then
      return options.transport == 'persistent'
    end
    return options[key]
  end,
})

return M
