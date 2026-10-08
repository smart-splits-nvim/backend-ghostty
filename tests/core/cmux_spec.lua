-- Evaluates scripts/ghostty.js under osascript without sending an Apple Event,
-- so it needs macOS but not cmux.
if vim.fn.has('macunix') == 0 then
  return
end

local script = vim.fn.getcwd() .. '/scripts/ghostty.js'

local function needs_move_check(versions)
  local result = vim
    .system({
      'osascript',
      '-l',
      'JavaScript',
      '-e',
      [[
        ObjC.import("Foundation");
        function run(argv) {
          eval(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(
            argv[0], $.NSUTF8StringEncoding, null)));
          return JSON.stringify(JSON.parse(argv[1]).map(cmuxNeedsMoveCheck));
        }
      ]],
      script,
      vim.json.encode(versions),
    })
    :wait(10000)
  assert.are.equal(0, result.code, result.stderr)
  return vim.json.decode(result.stdout)
end

describe('cmux', function()
  it('checks moves before 0.65.0, including nightlies and unreadable versions', function()
    assert.are.same(
      { true, true, true, true, true, true },
      needs_move_check({ '0.64.25', '0.64.25-nightly.18012345601', '0.9.0', '', 'unknown', vim.NIL })
    )
    assert.are.same(
      { false, false, false, false },
      needs_move_check({ '0.65.0', '0.65.0-nightly.18234567801', '0.100.0', '1.0.0' })
    )
  end)
end)
