-- Minimal Neovim config for the VHS tapes next to this file.
--
--   nvim -u demo/shot.lua lua/bokeh/init.lua
--
-- Loads nothing but bokeh.nvim, in standalone mode with every option left at
-- its default, so a recording shows what a new user actually gets rather than
-- a tuned setup. `unokai` is the colorscheme because its `LineNr` starts at
-- 4.2:1 against the background, which leaves the fade somewhere to go.

local root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h:h")
vim.opt.runtimepath:prepend(root)

vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.cursorlineopt = "number"
vim.o.wrap = false -- a wrapped line in the shot only muddies the gutter
vim.o.scrolloff = 999 -- keep the cursor centred so the fade is symmetric
vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false -- no pending-count flicker in the corner of a shot
vim.o.fillchars = "eob: "
vim.o.shortmess = vim.o.shortmess .. "I"

-- unokai ships with Neovim 0.11; habamax covers anything older.
if not pcall(vim.cmd.colorscheme, "unokai") then pcall(vim.cmd.colorscheme, "habamax") end

-- unokai paints floats as a light grey block, which is loud over the code.
-- The keystroke window below borrows these, so tone them down first.
vim.api.nvim_set_hl(0, "NormalFloat", { fg = "#f8f8f2", bg = "#1e1f1a" })
vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#5a5a52", bg = "#1e1f1a" })

require("bokeh").setup { standalone = true }

-- Keystrokes in the corner, when screenkey.nvim happens to be installed. The
-- stub keeps `:Screenkey` valid either way, so the tapes do not care.
local screenkey = vim.fn.stdpath "data" .. "/lazy/screenkey.nvim"
if vim.uv.fs_stat(screenkey) then
  vim.opt.runtimepath:append(screenkey)
  require("screenkey").setup {
    win_opts = { border = "rounded", width = 30, height = 1, title = "" },
    -- Its defaults label special keys with Nerd Font glyphs, which come out as
    -- tofu in VHS's font. These are plain Unicode that any monospace font has.
    keys = { ["<CR>"] = "↵", ["<ESC>"] = "Esc", ["<SPACE>"] = "␣", ["<BS>"] = "⌫", ["<TAB>"] = "⇥" },
    -- Do not fold repeats: ":Bokeh off" reading as "of..x2" helps nobody.
    compress_after = 9,
    clear_after = 4,
  }
else
  vim.api.nvim_create_user_command("Screenkey", function() end, { nargs = "*" })
end
