---@diagnostic disable: duplicate-set-field
local h = require('tests.helpers')
local mock = h.mock

describe('transport', function()
  after_each(h.restore)

  it('persistent is the default and handles every request after attachment', function()
    local state = mock()
    require('ghostty-smart-splits.config').reset()
    local backend = require('smart-splits-backend-ghostty')
    assert.is_true(backend.activate())
    h.wait_until(function()
      return #state.persistent_starts == 1
    end, 'the persistent process never started')
    h.settle() -- Let the scheduled key-table claim go first.
    assert.is_true(backend.move('right'))
    assert.are.equal('goto_split:right', state.persistent_requests[#state.persistent_requests].action)
    assert.are.equal(1, #state.calls) -- Only the initial terminal lookup started osascript.
  end)

  it('persistent transport falls back when it cannot start', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ transport = 'persistent' })
    assert.is_true(backend.activate())
    h.wait_until(function()
      return #state.persistent_starts == 1
    end, 'the persistent process never started')
    require('ghostty-smart-splits.transport').stop()
    state.persistent_start_failure = true
    assert.is_true(backend.move('right'))
    assert.are.equal(2, #state.persistent_starts)
    assert.are.equal('goto_split:right', h.last_action(state))
  end)

  it('a nested request falls back instead of stealing the reply', function()
    local state = mock()
    local transport = require('ghostty-smart-splits.transport')
    local outer_send = vim.fn.chansend
    local nested_result, nested_handled
    local depth = 0
    h.stub(vim.fn, 'chansend', function(job, data)
      depth = depth + 1
      if depth == 1 then
        nested_result, nested_handled = transport.request({ command = 'perform', terminalID = 't', action = 'nested' })
      end
      return outer_send(job, data)
    end)

    local result, handled = transport.request({ command = 'perform', terminalID = 't', action = 'goto_split:left' })
    assert.is_false(nested_handled) -- Nested caller is told to use ephemeral osascript.
    assert.is_nil(nested_result)
    assert.is_true(handled) -- Outer caller still gets its own reply.
    assert.are.equal('true', result)
    assert.are.equal(1, #state.persistent_requests) -- Only the outer request reached the pipe.
  end)

  it('a burst of output does not desynchronise the next request', function()
    local state = mock()
    local transport = require('ghostty-smart-splits.transport')
    assert.are.equal('terminal-1', transport.request({ command = 'focused-terminal-id' }))

    -- Two whole replies plus a partial one, all in a single stdout event.
    local stale = vim.json.encode({ ok = true, result = 'stale' })
    state.persistent_callbacks.on_stdout(1, { stale, stale, '{"ok":true,"resu' })

    local result, handled = transport.request({ command = 'perform', terminalID = 't', action = 'goto_split:left' })
    assert.is_true(handled)
    assert.are.equal('true', result)
  end)
end)
