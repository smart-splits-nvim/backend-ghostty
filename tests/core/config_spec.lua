local config = require('smart-splits-backend-ghostty.config')
local h = require('tests.helpers')

describe('config', function()
  before_each(function()
    config.reset()
  end)
  after_each(function()
    h.restore()
    config.reset()
  end)

  it('uses the defaults', function()
    assert.are.same({ enable = true, key_table = 'nvim', transport = 'persistent' }, config.setup())
    assert.are.same(config.defaults, config.options)
  end)

  it('rejects a non-boolean enable without changing config', function()
    config.setup({ enable = false })
    for _, value in ipairs({ 'false', 0 }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local ok, message = pcall(config.setup, { enable = value })
      assert.is_false(ok)
      assert(tostring(message):find('enable must be a boolean', 1, true))
      assert.is_false(config.options.enable)
    end
  end)

  it('accepts a custom key table', function()
    config.setup({ key_table = 'editor' })
    assert.are.equal('editor', config.options.key_table)
  end)

  it('rejects invalid key tables', function()
    for _, value in ipairs({ '', 1, false }) do
      local ok, message = pcall(config.setup, { key_table = value })
      assert.is_false(ok)
      assert(type(message) == 'string')
      assert.are.equal('key_table must be a non-empty string', message:match('key_table must be a non%-empty string$'))
    end
  end)

  it('transport defaults to persistent and rejects invalid values without changing config', function()
    assert.are.equal('persistent', config.options.transport)
    config.setup({ transport = 'ephemeral', key_table = 'editor' })
    assert.are.equal('ephemeral', config.options.transport)
    for _, value in ipairs({ 'bridge', true, 1 }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local ok, message = pcall(config.setup, { transport = value })
      assert.is_false(ok)
      assert(tostring(message):find("transport must be 'persistent' or 'ephemeral'", 1, true))
      assert.are.equal('ephemeral', config.options.transport)
      assert.are.equal('editor', config.options.key_table)
    end
    config.reset()
    assert.are.equal('persistent', config.options.transport)
  end)

  it('setup merges over the current options and reset restores defaults', function()
    config.setup({ key_table = 'editor', transport = 'ephemeral' })

    -- Naming one option leaves the rest alone, however many calls it takes.
    config.setup({ transport = 'persistent' })
    assert.are.equal('persistent', config.options.transport)
    assert.are.equal('editor', config.options.key_table)
    config.setup()
    assert.are.equal('editor', config.options.key_table)

    config.reset()
    assert.are.equal('nvim', config.options.key_table)
    assert.are.equal('persistent', config.options.transport)

    -- An explicit value still wins, and an invalid one is still rejected.
    config.setup({ key_table = 'other' })
    assert.are.equal('other', config.options.key_table)
    for _, value in ipairs({ '', 1, false }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      assert.is_false(pcall(config.setup, { key_table = value }))
      assert.are.equal('other', config.options.key_table)
    end
  end)

  it('unknown options are rejected instead of silently dropped', function()
    config.setup({ key_table = 'editor' })
    -- `bridge` was an alias for `transport` and has been removed.
    for _, opts in ipairs({ { bridge = true }, { bridge_enabled = true }, { keytable = 'x' } }) do
      local ok, message = pcall(config.setup, opts)
      assert.is_false(ok)
      assert(tostring(message):find('unknown option', 1, true))
    end
    assert.are.equal('editor', config.options.key_table)
    assert.are.equal('persistent', config.options.transport)
  end)
end)
