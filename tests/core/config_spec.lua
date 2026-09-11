local config = require('ghostty-smart-splits.config')
local h = require('tests.helpers')

describe('config', function()
  local warnings

  before_each(function()
    config.reset()
    warnings = {}
    h.stub(vim, 'notify_once', function(message)
      table.insert(warnings, message)
    end)
  end)
  after_each(function()
    h.restore()
    config.reset()
  end)

  it('uses the default key table', function()
    config.setup()
    assert.are.equal('nvim', config.key_table)
  end)

  it('accepts a custom key table', function()
    config.setup({ key_table = 'editor' })
    assert.are.equal('editor', config.key_table)
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
    assert.are.equal('persistent', config.transport)
    config.setup({ transport = 'ephemeral', key_table = 'editor' })
    assert.are.equal('ephemeral', config.transport)
    for _, value in ipairs({ 'bridge', true, 1 }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local ok, message = pcall(config.setup, { transport = value })
      assert.is_false(ok)
      assert(tostring(message):find("transport must be 'persistent' or 'ephemeral'", 1, true))
      assert.are.equal('ephemeral', config.transport)
      assert.are.equal('editor', config.key_table)
    end
    config.reset()
    assert.are.equal('persistent', config.transport)
  end)

  it('deprecated bridge still selects a transport and warns', function()
    config.setup({ bridge = false })
    assert.are.equal('ephemeral', config.transport)
    assert.is_false(config.bridge)
    assert.are.equal(1, #warnings)
    assert(warnings[1]:find('`bridge` is deprecated', 1, true))

    config.setup({ bridge = true })
    assert.are.equal('persistent', config.transport)
    assert.is_true(config.bridge)

    -- An explicit transport in the same call wins over the old name.
    config.setup({ bridge = true, transport = 'ephemeral' })
    assert.are.equal('ephemeral', config.transport)

    for _, value in ipairs({ 'false', 0, {} }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local ok, message = pcall(config.setup, { bridge = value })
      assert.is_false(ok)
      assert(tostring(message):find('bridge must be a boolean', 1, true))
      assert.are.equal('ephemeral', config.transport)
    end
  end)

  it('setup merges over the current options and reset restores defaults', function()
    config.setup({ key_table = 'editor', transport = 'ephemeral' })

    -- Naming one option leaves the rest alone, however many calls it takes.
    config.setup({ transport = 'persistent' })
    assert.are.equal('persistent', config.transport)
    assert.are.equal('editor', config.key_table)
    config.setup()
    assert.are.equal('editor', config.key_table)

    config.reset()
    assert.are.equal('nvim', config.key_table)
    assert.are.equal('persistent', config.transport)

    -- An explicit value still wins, and an invalid one is still rejected.
    config.setup({ key_table = 'other' })
    assert.are.equal('other', config.key_table)
    for _, value in ipairs({ '', 1, false }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      assert.is_false(pcall(config.setup, { key_table = value }))
      assert.are.equal('other', config.key_table)
    end
  end)

  it('unknown options are rejected instead of silently dropped', function()
    config.setup({ key_table = 'editor' })
    for _, opts in ipairs({ { bridge_enabled = true }, { keytable = 'x' } }) do
      local ok, message = pcall(config.setup, opts)
      assert.is_false(ok)
      assert(tostring(message):find('unknown option', 1, true))
    end
    assert.are.equal('editor', config.key_table)
    assert.are.equal('persistent', config.transport)
  end)
end)
