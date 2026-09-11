local h = require('tests.helpers')

describe('health', function()
  after_each(h.restore)

  it('health checks prerequisites without Apple Events', function()
    local state = h.mock()
    state.linux = true
    local reports = {}
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function(message)
            table.insert(reports, { level, message })
          end
        end,
      })
    )
    require('ghostty-smart-splits.health').check()
    assert.are.equal(0, #state.calls)
    local warned = false
    for _, report in ipairs(reports) do
      if report[1] == 'warn' and report[2]:find('Only macOS', 1, true) then
        warned = true
      end
    end
    assert.is_true(warned)
  end)

  it('health reports the transport and its status without starting it', function()
    local state = h.mock()
    local reports
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function(message)
            table.insert(reports, { level, message })
          end
        end,
      })
    )
    local function check(expected_level, expected_message)
      reports = {}
      require('ghostty-smart-splits.health').check()
      local found = false
      for _, report in ipairs(reports) do
        if report[1] == expected_level and report[2]:find(expected_message, 1, true) then
          found = true
        end
      end
      assert.is_true(found)
      assert.are.equal(0, #state.persistent_starts)
      assert.are.equal(0, #state.calls)
    end
    check('info', "transport = 'ephemeral': each request starts osascript")
    require('smart-splits-backend-ghostty').setup({ transport = 'persistent' })
    check('info', "transport = 'persistent': starts on the next attachment or action")
    require('smart-splits-backend-ghostty').setup({ transport = 'ephemeral' })
    check('info', "transport = 'ephemeral': each request starts osascript")
  end)

  it('health names cmux, which also reports TERM_PROGRAM=ghostty', function()
    h.mock()
    local reports
    h.stub(
      vim,
      'health',
      setmetatable({}, {
        __index = function(_, level)
          return function(message)
            table.insert(reports, { level, message })
          end
        end,
      })
    )
    local function reported(expected_message)
      reports = {}
      require('ghostty-smart-splits.health').check()
      for _, report in ipairs(reports) do
        if report[1] == 'ok' and report[2] == expected_message then
          return true
        end
      end
      return false
    end
    assert.is_true(reported('Running in Ghostty'))
    vim.env.CMUX_SURFACE_ID = 'surface-1'
    assert.is_true(reported('Running in cmux'))
  end)
end)
