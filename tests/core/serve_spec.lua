-- Drives the real persistent process over stdin/stdout, the way transport.lua
-- does. Every request here is rejected before an Apple Event is built, so it
-- needs macOS but not Ghostty.
if vim.fn.has('macunix') == 0 then
  return
end

local root = vim.fn.getcwd()

describe('serve', function()
  local process

  after_each(function()
    if process then
      pcall(process.kill, process, 9)
      process = nil
    end
  end)

  it('answers each line, even one split mid-character, and exits when stdin closes', function()
    local output = ''
    process = vim.system({ 'osascript', '-l', 'JavaScript', root .. '/scripts/ghostty.js', 'serve' }, {
      stdin = true,
      stdout = function(_, data)
        output = output .. (data or '')
      end,
    })
    local function replies(count)
      assert(
        vim.wait(10000, function()
          return select(2, output:gsub('\n', '')) >= count
        end, 10),
        'serve did not reply: ' .. output
      )
      return vim.tbl_map(vim.json.decode, vim.split(vim.trim(output), '\n'))
    end

    -- The third request stops inside a two-byte character. The complete lines
    -- before it must be answered without waiting for the rest.
    process:write('not json\n{"command":"perform"}\n{"command":"caf\195')
    local first = replies(2)
    assert.is_false(first[1].ok)
    assert.are.same({ ok = false, error = 'perform needs a terminalID and an action' }, first[2])
    process:write('\169"}\n')
    assert.are.same({ ok = false, error = 'Unknown command: café' }, replies(3)[3])

    process:write(nil)
    local result = process:wait(10000)
    assert.are.equal(0, result.code)
    assert.are.equal(3, select(2, output:gsub('\n', '')))
  end)
end)
