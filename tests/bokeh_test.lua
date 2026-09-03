-- bokeh core tests
-- Run: nvim --headless -u NONE --noplugin -l tests/bokeh_test.lua

package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

local bokeh = require "bokeh"

local pass_count = 0
local fail_count = 0

local function assert_eq(actual, expected, msg)
  if actual == expected then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
    print("FAIL: " .. msg)
    print("  expected: " .. vim.inspect(expected))
    print("  actual:   " .. vim.inspect(actual))
  end
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    fail_count = fail_count + 1
    print("ERROR: " .. name .. ": " .. tostring(err))
  end
end

---Build the argument table statuscol.nvim hands to a text segment.
---@param overrides? table
---@return table
local function args(overrides)
  return vim.tbl_extend("force", {
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    lnum = 10,
    relnum = 3,
    virtnum = 0,
    nu = true,
    rnu = true,
    nuw = 4,
  }, overrides or {})
end

-- ============================================================================
-- Before setup(): every entry point has to stay out of the way
-- ============================================================================

test("hl renders nothing before setup", function()
  assert_eq(bokeh.hl(args()), "", "no highlight without setup")
end)

test("segment still renders the number before setup", function()
  assert_eq(bokeh.segment(args()), "%=   3", "the column does not go blank")
end)

-- ============================================================================
-- setup
-- ============================================================================

vim.o.termguicolors = true
vim.api.nvim_set_hl(0, "Normal", { fg = 0xffffff, bg = 0x000000 })
vim.api.nvim_set_hl(0, "LineNr", { fg = 0x808080 })
bokeh.setup()

test("setup registers one highlight group per band", function()
  local config = bokeh.get_config()
  assert_eq(config.bands, 5, "default band count")
  for i = 1, config.bands do
    local hl = vim.api.nvim_get_hl(0, { name = "BokehFade" .. i })
    assert_eq(type(hl.fg), "number", "BokehFade" .. i .. " has a foreground")
  end
end)

test("the bands march from LineNr toward the Normal background", function()
  local previous = 0x808080
  for i = 1, bokeh.get_config().bands do
    local fg = vim.api.nvim_get_hl(0, { name = "BokehFade" .. i }).fg
    if fg >= previous then
      fail_count = fail_count + 1
      print(("FAIL: band %d is not darker than the one before (%06x -> %06x)"):format(i, previous, fg))
      return
    end
    previous = fg
  end
  pass_count = pass_count + 1
end)

test("the deepest band stops at `amount`, not at the target", function()
  -- amount = 0.7 from 0x808080 toward 0x000000 leaves roughly 30% brightness.
  local deepest = vim.api.nvim_get_hl(0, { name = "BokehFade5" }).fg
  assert_eq(deepest, 0x262626, "0x80 * 0.3 rounds to 0x26 on every channel")
end)

-- ============================================================================
-- band: distance to fade step
-- ============================================================================

test("the cursor line has no band", function()
  assert_eq(bokeh.band(0), nil, "relnum 0 keeps CursorLineNr")
end)

test("bands are assigned in order of distance", function()
  -- Defaults: 5 bands over a distance of 12, so 2.4 lines per band.
  assert_eq(bokeh.band(1), 1, "nearest")
  assert_eq(bokeh.band(2), 1, "still the first band")
  assert_eq(bokeh.band(3), 2, "second band")
  assert_eq(bokeh.band(5), 3, "third band")
  assert_eq(bokeh.band(8), 4, "fourth band")
  assert_eq(bokeh.band(10), 5, "deepest band")
end)

test("distance beyond the configured reach clamps to the deepest band", function()
  assert_eq(bokeh.band(12), 5, "exactly at the reach")
  assert_eq(bokeh.band(500), 5, "far past it")
end)

test("band count and distance are configurable", function()
  bokeh.setup { bands = 2, distance = 4 }
  assert_eq(bokeh.band(1), 1, "first half")
  assert_eq(bokeh.band(2), 1, "still the first half")
  assert_eq(bokeh.band(3), 2, "second half")
  assert_eq(bokeh.band(99), 2, "clamped")
  bokeh.setup()
end)

test("nonsense config falls back to the defaults with a warning", function()
  local notified = false
  local notify = vim.notify
  vim.notify = function()
    notified = true
  end
  bokeh.setup { bands = 0 }
  vim.notify = notify
  assert_eq(notified, true, "the user is told")
  assert_eq(bokeh.get_config().bands, 5, "back to the default band count")
  bokeh.setup()
end)

-- ============================================================================
-- hl: the highlight item
-- ============================================================================

test("hl names the band for the drawn line", function()
  assert_eq(bokeh.hl(args { relnum = 3 }), "%#BokehFade2#", "third line out")
  assert_eq(bokeh.hl(args { relnum = 30 }), "%#BokehFade5#", "far away")
end)

test("hl leaves the cursor line to CursorLineNr", function()
  assert_eq(bokeh.hl(args { relnum = 0 }), "", "no item on the cursor line")
end)

-- ============================================================================
-- segment: the rendered number
-- ============================================================================

test("segment fades the relative number", function()
  assert_eq(bokeh.segment(args { relnum = 3 }), "%#BokehFade2#%=   3%*", "faded and right-aligned")
end)

test("segment shows the absolute number on the cursor line, unfaded", function()
  assert_eq(bokeh.segment(args { relnum = 0, lnum = 10 }), "%=  10", "hybrid numbering")
end)

test("segment pads to 'numberwidth'", function()
  assert_eq(bokeh.segment(args { relnum = 0, lnum = 7, nuw = 6 }), "%=     7", "six columns wide")
  assert_eq(bokeh.segment(args { relnum = 0, lnum = 123456, nuw = 4 }), "%=123456", "a number wider than nuw")
end)

test("segment follows 'number' and 'relativenumber'", function()
  assert_eq(bokeh.segment(args { rnu = false, lnum = 42, relnum = 3 }), "%#BokehFade2#%=  42%*", "absolute only")
  assert_eq(bokeh.segment(args { nu = false, rnu = false }), "", "both off draws nothing")
end)

test("segment gives wrapped and virtual lines width but no number", function()
  assert_eq(bokeh.segment(args { virtnum = 1 }), "%=", "wrapped part of a line")
  assert_eq(bokeh.segment(args { virtnum = -1 }), "%=", "virtual line")
end)

-- ============================================================================
-- Turning it off — the whole point of the exercise
-- ============================================================================

test("disable drops the fade but keeps the numbers", function()
  bokeh.disable()
  assert_eq(bokeh.is_enabled(), false, "reported as off")
  assert_eq(bokeh.hl(args()), "", "no highlight item")
  assert_eq(bokeh.segment(args { relnum = 3 }), "%=   3", "the number is still drawn")
  bokeh.enable()
  assert_eq(bokeh.is_enabled(), true, "reported as on")
  assert_eq(bokeh.hl(args()), "%#BokehFade2#", "the fade is back")
end)

test("toggle flips and reports the new state", function()
  assert_eq(bokeh.toggle(), false, "first toggle turns it off")
  assert_eq(bokeh.toggle(), true, "second toggle turns it on")
end)

test("vim.g.bokeh_disable switches everything off", function()
  vim.g.bokeh_disable = true
  assert_eq(bokeh.hl(args()), "", "globally off")
  vim.g.bokeh_disable = nil
  assert_eq(bokeh.hl(args()), "%#BokehFade2#", "and back on")
end)

test("vim.b.bokeh_disable switches off one buffer", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].bokeh_disable = true
  assert_eq(bokeh.hl(args { buf = buf }), "", "the marked buffer")
  assert_eq(bokeh.hl(args()), "%#BokehFade2#", "other buffers are untouched")
  vim.api.nvim_buf_delete(buf, { force = true })
end)

test("vim.w.bokeh_disable switches off one window", function()
  local win = vim.api.nvim_get_current_win()
  vim.w[win].bokeh_disable = true
  assert_eq(bokeh.hl(args { win = win }), "", "the marked window")
  vim.w[win].bokeh_disable = nil
  assert_eq(bokeh.hl(args { win = win }), "%#BokehFade2#", "and back on")
end)

test("without 'termguicolors' the bands link to the source group instead", function()
  vim.o.termguicolors = false
  bokeh.setup()
  assert_eq(bokeh.hl(args()), "", "nothing to blend, so nothing is claimed")
  assert_eq(bokeh.segment(args { relnum = 3 }), "%=   3", "the number still renders")
  local hl = vim.api.nvim_get_hl(0, { name = "BokehFade1" })
  assert_eq(hl.link, "LineNr", "the band is a plain link")
  vim.o.termguicolors = true
  bokeh.setup()
end)

-- ============================================================================
-- statuscolumn: standalone rendering
-- ============================================================================

test("the standalone column keeps the fold and sign columns", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.number = true
  vim.wo.relativenumber = true
  local rendered = bokeh.statuscolumn()
  assert_eq(rendered:sub(1, 4), "%C%s", "fold column, then signs, then the number")
  assert_eq(rendered:find "%%=" ~= nil, true, "the number is right-aligned")
end)

print(string.format("bokeh_test: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then os.exit(1) end
