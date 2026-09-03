--- Colour maths for bokeh.nvim.
---
--- Colours are handled as plain 24-bit RGB integers, which is what
--- |nvim_get_hl()| hands back and what |nvim_set_hl()| accepts, so no string
--- parsing happens on the render path. Everything except `attrs()` is pure and
--- therefore testable without a running UI.
local M = {}

---Split a 24-bit RGB integer into its components.
---@param rgb integer
---@return integer r, integer g, integer b
function M.split(rgb)
  return math.floor(rgb / 0x10000) % 0x100, math.floor(rgb / 0x100) % 0x100, rgb % 0x100
end

---Join colour components back into a 24-bit RGB integer.
---@param r integer
---@param g integer
---@param b integer
---@return integer
function M.join(r, g, b)
  return r * 0x10000 + g * 0x100 + b
end

---Blend `from` toward `to`.
---
--- `t` is clamped to 0..1: 0 returns `from` unchanged, 1 returns `to`.
---@param from integer  24-bit RGB
---@param to integer    24-bit RGB
---@param t number      Blend ratio
---@return integer
function M.blend(from, to, t)
  t = math.min(1, math.max(0, t))
  local fr, fg, fb = M.split(from)
  local tr, tg, tb = M.split(to)
  local function mix(a, b)
    return math.floor(a + (b - a) * t + 0.5)
  end
  return M.join(mix(fr, tr), mix(fg, tg), mix(fb, tb))
end

---Format a 24-bit RGB integer the way Neovim writes colours in `:highlight`.
---@param rgb integer
---@return string
function M.hex(rgb)
  return ("#%06x"):format(rgb)
end

---Coerce a user-supplied colour into a 24-bit RGB integer.
---
--- Accepts `"#rrggbb"`, `"rrggbb"`, and integers as-is. Returns nil for
--- anything else so callers can fall back rather than render a wrong colour.
---@param value string|integer|nil
---@return integer|nil
function M.to_rgb(value)
  if type(value) == "number" then return value end
  if type(value) ~= "string" then return nil end
  return tonumber((value:gsub("^#", "")), 16)
end

---Read the resolved attributes of a highlight group.
---
--- Links are followed, so `LineNr` still yields concrete colours when a
--- colorscheme defines it as a link.
---@param group string
---@return table|nil  nil when the group does not exist
function M.attrs(group)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or vim.tbl_isempty(hl) then return nil end
  return hl
end

return M
