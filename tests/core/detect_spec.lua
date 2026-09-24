local h = require('tests.helpers')
local mock = h.mock

describe('detect()', function()
  after_each(h.restore)

  it('returns true in a supported Ghostty session', function()
    mock()
    assert.is_true(require('smart-splits-backend-ghostty').detect())
  end)

  it('returns false when the backend is disabled, without Apple Events', function()
    local state = mock()
    local backend = require('smart-splits-backend-ghostty')
    backend.setup({ enable = false })
    assert.is_false(backend.detect())
    assert.is_false(require('smart-splits-backend-ghostty.mux').is_in_session())
    backend.setup({ enable = true })
    assert.is_true(backend.detect())
    assert.are.equal(0, #state.calls)
  end)

  it('returns false outside Ghostty', function()
    mock()
    vim.env.TERM_PROGRAM = 'other'
    assert.is_false(require('smart-splits-backend-ghostty').detect())
  end)
end)
