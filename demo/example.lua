-- The "build your own column" shot for the README.
--
--   nvim -u demo/example.lua lua/bokeh/init.lua
--
-- Absolute and relative numbers side by side, with the fade split by
-- direction. None of that layout is bokeh's — the column below is a page of
-- plain 'statuscolumn' — but every colour on the relative side is, and it keeps
-- working when the fade is switched off.

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
  -- Whether a number is drawn at all is the renderer's call, not bokeh's, and
  -- each option folds its own column, the way the built-in number column does.
  -- Neovim opens help windows with 'number' and 'relativenumber' both off, and
  -- ftplugins commonly do the same for quickfix and terminal windows.
  local nu, rnu = vim.wo.number, vim.wo.relativenumber
  if not (nu or rnu) then return "" end

  local absolute_width = nu and #tostring(vim.api.nvim_buf_line_count(0)) or 0
  local relative_width = rnu and 4 or 0
  if vim.v.virtnum ~= 0 then return (" "):rep(absolute_width + relative_width + 1) end

  local column = ""

  if nu then
    local absolute = tostring(vim.v.lnum)
    local hl = vim.v.relnum == 0 and "%#CursorLineNr#" or "%#GutterAbsolute#"
    column = hl .. (" "):rep(absolute_width - #absolute) .. absolute
  end

  if rnu then
    -- Blank rather than "0" on the cursor line — unless the absolute column is
    -- folded away, where "0" is the only number left to mark it with.
    local relative = vim.v.relnum > 0 and tostring(vim.v.relnum) or (nu and "" or "0")
    -- bokeh returns "" on the cursor line and while the fade is off, which
    -- falls through to whatever highlight is already in effect — the absolute
    -- column's, or CursorLineNr when there is no absolute column.
    local hl = bokeh.hl()
    if hl == "" and vim.v.relnum == 0 then hl = "%#CursorLineNr#" end
    column = column .. hl .. (" "):rep(relative_width - #relative) .. relative
  end

  return column .. " "
end

vim.o.statuscolumn = "%!v:lua.Gutter()"
