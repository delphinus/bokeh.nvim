-- The "build your own column" shot for the README.
--
--   nvim -u demo/example.lua lua/bokeh/init.lua
--
-- Absolute and relative numbers side by side, with the fade split by
-- direction. None of that layout is bokeh's — the column below is twenty lines
-- of plain 'statuscolumn' — but every colour on the relative side is, and it
-- keeps working when the fade is switched off.

local root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h:h")
vim.opt.runtimepath:prepend(root)

vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.cursorlineopt = "number"
vim.o.wrap = false
vim.o.scrolloff = 999
vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false
vim.o.fillchars = "eob: "
vim.o.shortmess = vim.o.shortmess .. "I"

if not pcall(vim.cmd.colorscheme, "unokai") then pcall(vim.cmd.colorscheme, "habamax") end

-- ── everything below is what a user would write ─────────────────────────────

local bokeh = require "bokeh"

-- Cool blue above the cursor, green below, and a quieter tone for the absolute
-- column so the relative number stays the one that shouts.
vim.api.nvim_set_hl(0, "GutterAbove", { fg = "#7b9ac7" })
vim.api.nvim_set_hl(0, "GutterBelow", { fg = "#6aa781" })
vim.api.nvim_set_hl(0, "GutterAbsolute", { fg = "#6b7089" })

bokeh.setup {
  bands = 8,
  distance = 24,
  amount = 0.6,
  curve = "ease_in",
  from = { above = "GutterAbove", below = "GutterBelow" },
}

function _G.Gutter()
  local width = #tostring(vim.api.nvim_buf_line_count(0))
  if vim.v.virtnum ~= 0 then return (" "):rep(width + 5) end

  local absolute = tostring(vim.v.lnum)
  absolute = (" "):rep(width - #absolute) .. absolute

  -- Blank rather than "0" on the cursor line.
  local relative = vim.v.relnum == 0 and "" or tostring(vim.v.relnum)
  relative = (" "):rep(4 - #relative) .. relative

  local absolute_hl = vim.v.relnum == 0 and "%#CursorLineNr#" or "%#GutterAbsolute#"
  -- bokeh returns "" on the cursor line and while the fade is off, which falls
  -- through to whatever highlight is already in effect.
  return absolute_hl .. absolute .. bokeh.hl() .. relative .. " "
end

vim.o.statuscolumn = "%!v:lua.Gutter()"
