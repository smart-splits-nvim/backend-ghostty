local config = require('ghostty-smart-splits.config')

describe('config', function()
  before_each(config.reset)
  after_each(config.reset)

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

  it('bridge defaults to false and rejects invalid values without changing config', function()
    assert.is_false(config.bridge)
    config.setup({ bridge = true, key_table = 'editor' })
    assert.is_true(config.bridge)
    for _, value in ipairs({ 'false', 0, {} }) do
      ---@diagnostic disable-next-line: assign-type-mismatch
      local ok, message = pcall(config.setup, { bridge = value })
      assert.is_false(ok)
      assert(tostring(message):find('bridge must be a boolean', 1, true))
      assert.is_true(config.bridge)
      assert.are.equal('editor', config.key_table)
    end
    config.reset()
    assert.is_false(config.bridge)
  end)

  it('setup merges over the current options and reset restores defaults', function()
    config.setup({ key_table = 'editor', bridge = true })

    -- Naming one option leaves the rest alone, however many calls it takes.
    config.setup({ bridge = false })
    assert.is_false(config.bridge)
    assert.are.equal('editor', config.key_table)
    config.setup()
    assert.are.equal('editor', config.key_table)

    config.reset()
    assert.are.equal('nvim', config.key_table)
    assert.is_false(config.bridge)

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
    assert.is_false(config.bridge)
  end)
end)
