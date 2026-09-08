local h = require('tests.helpers')
local mock = h.mock

describe('v3 backend', function()
  after_each(h.restore)

  describe('protocol conformance', function()
    local backend = require('smart-splits-backend-ghostty')
    local protocol_tests = require('smart-splits.protocol_tests')
    for _, test in ipairs(protocol_tests.tests(backend)) do
      it(test.name, function()
        local result = test.fn()
        if result ~= true then
          error(result)
        end
      end)
    end
  end)

  it('configuration and detection have no side effects', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ key_table = 'editor' })
    backend.setup({ key_table = 'editor' })
    assert.is_true(backend.detect())
    assert.are.equal(0, #state.calls)
    assert.is_false(pcall(vim.api.nvim_get_autocmds, { group = 'GhosttySmartSplits' }))
    assert.is_false(backend.move('left'))
    assert.is_false(backend.resize('left'))
    assert.is_false(backend.move('left', { at_edge = 'split' }))
    assert.is_nil(backend.split) -- Core dropped `split` from the protocol.
    assert.are.equal(0, #state.calls)
    assert.is_true(backend.activate())
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:editor', h.last_action(state))
  end)

  for _, direction in ipairs({ 'left', 'right', 'up', 'down' }) do
    it('honors at_edge and returns failed splits to core: ' .. direction, function()
      local state = mock()
      local backend = require('smart-splits-backend-ghostty')
      backend.activate()
      h.wait_for_calls(state, 2)
      local move = 'goto_split:' .. direction
      local split = 'new_split:' .. direction

      -- Every mode prefers an existing neighbor and must not also split.
      for _, mode in ipairs({ 'stop', 'wrap', 'split' }) do
        local count = #state.calls
        assert.is_true(backend.move(direction, { at_edge = mode }))
        assert.are.equal(move, h.last_action(state))
        assert.are.equal(count + 1, #state.calls)
      end

      state.responses = { [move] = { code = 0, stdout = 'false' } }
      local count = #state.calls
      assert.is_false(backend.move(direction, { at_edge = 'stop' }))
      assert.is_false(backend.move(direction, { at_edge = 'wrap' }))
      assert.is_false(backend.move(direction))
      assert.are.equal(count + 3, #state.calls)

      assert.is_true(backend.move(direction, { at_edge = 'split' }))
      assert.are.equal(split, h.last_action(state))

      -- Returning false is what lets core create a Neovim split instead.
      state.responses[split] = { code = 0, stdout = 'false' }
      assert.is_false(backend.move(direction, { at_edge = 'split' }))
      assert.are.equal(split, h.last_action(state))
    end)
  end
end)
