--- `:checkhealth bokeh`.
---
--- Reports the two things that silently break the fade — no 24-bit colour, and
--- a stale fade when 'relativenumber' is off — plus which highlight groups are
--- actually registered.
local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local info = vim.health.info or vim.health.report_info

function M.check()
  start "bokeh.nvim"

  local bokeh = require "bokeh"
  local config = bokeh.get_config()

  if vim.fn.has "nvim-0.10" == 1 then
    ok("Neovim " .. tostring(vim.version()))
  else
    warn "Neovim 0.10+ required"
  end

  if vim.o.termguicolors then
    ok "'termguicolors' is on"
  else
    warn(
      "'termguicolors' is off, so the fade cannot be computed",
      { "Set `vim.o.termguicolors = true`, or drop bokeh.nvim on this terminal." }
    )
  end

  local from = require("bokeh.color").attrs(config.from)
  if from and from.fg then
    ok(("`%s` resolves to %s"):format(config.from, require("bokeh.color").hex(from.fg)))
  else
    warn(("`%s` has no foreground colour to fade from"):format(config.from), {
      "Pick another group with `from`, or set the colour in your colorscheme.",
    })
  end

  local registered = 0
  for i = 1, config.bands do
    if not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "BokehFade" .. i })) then registered = registered + 1 end
  end
  if registered == config.bands then
    ok(("%d fade bands registered (BokehFade1..%d)"):format(registered, config.bands))
  else
    warn(("only %d of %d fade bands are registered; has setup() run?"):format(registered, config.bands))
  end

  if not (vim.wo.number or vim.wo.relativenumber) then
    warn "both 'number' and 'relativenumber' are off in this window, so there is nothing to fade"
  elseif vim.wo.relativenumber then
    ok "'relativenumber' is on, so the fade follows the cursor by itself"
  elseif config.redraw == false then
    warn("'relativenumber' is off and `redraw` is false, so the fade will lag behind the cursor", {
      'Set `redraw = "auto"` (the default) to have bokeh.nvim force the redraw.',
    })
  else
    info "'relativenumber' is off; bokeh.nvim forces the statuscolumn redraw on cursor movement"
  end

  if config.standalone then
    info "standalone mode: bokeh.nvim owns 'statuscolumn'"
  elseif package.loaded["statuscol"] then
    info "statuscol.nvim is loaded; wire `segment` or `hl` into its `segments`"
  else
    info "not in standalone mode; `segment` or `hl` must be wired into a 'statuscolumn'"
  end

  if bokeh.is_enabled() then
    ok "enabled"
  else
    info "disabled (`:Bokeh on` to turn it back on)"
  end
end

return M
