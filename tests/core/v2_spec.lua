local h = require('tests.helpers')
local mock = h.mock

describe('smart-splits v2 compatibility', function()
  local core_setups

  before_each(function()
    -- The suite runs against v3 core; stand in for v2's `setup()`.
    core_setups = {}
    h.stub(package.loaded, 'smart-splits', {
      setup = function(opts)
        table.insert(core_setups, opts)
      end,
    })
    -- Drop the adapter registration setup() makes when the case ends.
    h.stub(package.preload, 'smart-splits.mux.ghostty', nil)
    h.stub(package.loaded, 'smart-splits.mux.ghostty', nil)
  end)
  after_each(h.restore)

  it('setup selects the Ghostty adapter and claims the key table', function()
    local state = mock()
    local v2 = require('smart-splits-backend-ghostty.v2')
    assert.is_false(pcall(require, 'smart-splits.mux.ghostty'))
    assert.is_true(v2.setup({ key_table = 'editor' }))
    assert.are.same({ { multiplexer_integration = 'ghostty', at_edge = 'stop' } }, core_setups)
    -- The module name v2 requires for `multiplexer_integration = 'ghostty'`.
    assert.are.equal(require('smart-splits-backend-ghostty.mux'), require('smart-splits.mux.ghostty'))
    h.wait_for_calls(state, 2)
    assert.are.equal('activate_key_table:editor', h.last_action(state))
    assert.is_true(v2.release_keys())
    assert.are.equal('deactivate_key_table', h.last_action(state))
  end)

  it('setup leaves smart-splits alone when disabled or unsupported', function()
    local state = mock()
    local v2 = require('smart-splits-backend-ghostty.v2')
    assert.is_false(v2.setup({ enable = false }))
    require('smart-splits-backend-ghostty.config').setup({ enable = true })
    state.linux = true
    assert.is_false(v2.setup())
    assert.are.same({}, core_setups)
    assert.is_nil(package.preload['smart-splits.mux.ghostty'])
    assert.are.equal(0, #state.calls)
  end)

  it('the v2 adapter drives the same Ghostty actions', function()
    local state = mock()
    local mux = require('smart-splits-backend-ghostty.mux')
    assert.are.equal('ghostty', mux.type)
    assert.is_true(mux.is_in_session())
    assert.is_true(mux.attach())
    h.wait_for_calls(state, 1)
    h.settle(10)
    assert.are.equal('terminal-1', mux.current_pane_id())
    assert.is_true(mux.next_pane('left'))
    assert.are.equal('goto_split:left', h.last_action(state))
    assert.is_true(mux.split_pane('down'))
    assert.are.equal('new_split:down', h.last_action(state))
    assert.is_false(mux.current_pane_at_edge())
  end)
end)
