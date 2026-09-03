-- bokeh.color tests
-- Run: nvim --headless -u NONE --noplugin -l tests/color_test.lua

package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

local color = require "bokeh.color"

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

-- ============================================================================
-- split / join: 24-bit RGB integers to components and back
-- ============================================================================

test("split takes an RGB integer apart", function()
  local r, g, b = color.split(0x123456)
  assert_eq(r, 0x12, "red")
  assert_eq(g, 0x34, "green")
  assert_eq(b, 0x56, "blue")
end)

test("split handles the extremes", function()
  local r, g, b = color.split(0x000000)
  assert_eq(r + g + b, 0, "black is all zero")
  r, g, b = color.split(0xffffff)
  assert_eq(r, 0xff, "white red")
  assert_eq(g, 0xff, "white green")
  assert_eq(b, 0xff, "white blue")
end)

test("join is the inverse of split", function()
  for _, rgb in ipairs { 0x000000, 0x0000ff, 0x00ff00, 0xff0000, 0x808080, 0xffffff, 0x1a2b3c } do
    assert_eq(color.join(color.split(rgb)), rgb, ("round trip %06x"):format(rgb))
  end
end)

-- ============================================================================
-- blend: the fade itself
-- ============================================================================

test("blend at t=0 returns the source untouched", function()
  assert_eq(color.blend(0xc0c0c0, 0x000000, 0), 0xc0c0c0, "no blending")
end)

test("blend at t=1 returns the target", function()
  assert_eq(color.blend(0xc0c0c0, 0x000000, 1), 0x000000, "fully faded")
end)

test("blend at t=0.5 lands halfway, rounding to nearest", function()
  assert_eq(color.blend(0xffffff, 0x000000, 0.5), 0x808080, "white to black")
  assert_eq(color.blend(0x000000, 0xffffff, 0.5), 0x808080, "black to white is symmetric")
end)

test("blend clamps t outside 0..1", function()
  assert_eq(color.blend(0xffffff, 0x000000, -1), 0xffffff, "negative t")
  assert_eq(color.blend(0xffffff, 0x000000, 9), 0x000000, "t past 1")
end)

test("blend moves each channel independently", function()
  -- Red stays, green climbs to full, blue falls to zero.
  assert_eq(color.blend(0xff0044, 0xffff00, 1), 0xffff00, "channels reach the target")
end)

test("blend is monotonic as t grows", function()
  local previous = 0xffffff
  for i = 1, 10 do
    local current = color.blend(0xffffff, 0x000000, i / 10)
    if current >= previous then
      fail_count = fail_count + 1
      print(("FAIL: step %d did not darken (%06x -> %06x)"):format(i, previous, current))
      return
    end
    previous = current
  end
  pass_count = pass_count + 1
end)

-- ============================================================================
-- hex / to_rgb
-- ============================================================================

test("hex formats the way Neovim writes colours", function()
  assert_eq(color.hex(0x1a2b3c), "#1a2b3c", "six digits")
  assert_eq(color.hex(0x000000), "#000000", "zero is padded")
end)

test("to_rgb accepts the shapes a user might configure", function()
  assert_eq(color.to_rgb "#1a2b3c", 0x1a2b3c, "leading hash")
  assert_eq(color.to_rgb "1a2b3c", 0x1a2b3c, "bare hex")
  assert_eq(color.to_rgb(0x1a2b3c), 0x1a2b3c, "integer passes through")
end)

test("to_rgb returns nil for anything it cannot read", function()
  assert_eq(color.to_rgb(nil), nil, "nil")
  assert_eq(color.to_rgb "rebeccapurple", nil, "colour name")
  assert_eq(color.to_rgb {}, nil, "table")
end)

-- ============================================================================
-- attrs: reading highlight groups
-- ============================================================================

test("attrs follows links to concrete colours", function()
  vim.api.nvim_set_hl(0, "BokehTestBase", { fg = 0x336699 })
  vim.api.nvim_set_hl(0, "BokehTestLink", { link = "BokehTestBase" })
  local attrs = color.attrs "BokehTestLink"
  assert_eq(attrs and attrs.fg, 0x336699, "the linked-to colour comes back")
end)

test("attrs returns nil for an undefined group", function()
  assert_eq(color.attrs "BokehTestNoSuchGroupAnywhere", nil, "undefined group")
end)

print(string.format("color_test: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then os.exit(1) end
