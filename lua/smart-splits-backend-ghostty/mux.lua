-- The adapter smart-splits v2 loads as `smart-splits.mux.ghostty`; v2.setup()
-- registers it under that name. v3 uses init.lua instead.
local backend = require('smart-splits-backend-ghostty')
local ghostty = require('smart-splits-backend-ghostty.ghostty')
local M = {
  type = 'ghostty',
  is_in_session = backend.detect,
  current_pane_id = ghostty.focused_terminal_id,
  next_pane = ghostty.move,
  resize_pane = ghostty.resize,
  split_pane = ghostty.split,
  -- Preserve the helpers exposed by the original module.
  attach = ghostty.attach,
  perform = ghostty.perform,
}

function M.current_pane_at_edge()
  return false
end

function M.current_pane_is_zoomed()
  return false
end

function M.update_mux_layout_details() end

return M
