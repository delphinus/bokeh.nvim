-- bokeh.nvim plugin entry point.
-- Sourced automatically by Neovim. Guards against double-loading.

if vim.g.loaded_bokeh then return end
if vim.fn.has "nvim-0.10" == 0 then
  vim.notify("[bokeh] requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end
vim.g.loaded_bokeh = true

local actions = {
  on = function()
    require("bokeh").enable()
  end,
  off = function()
    require("bokeh").disable()
  end,
  toggle = function()
    require("bokeh").toggle()
  end,
}

vim.api.nvim_create_user_command("Bokeh", function(args)
  -- Bare `:Bokeh` toggles, which is what a "let me see the plain numbers for a
  -- second" reflex wants to be.
  local action = actions[args.args ~= "" and args.args or "toggle"]
  if not action then
    vim.notify("[bokeh] unknown argument: " .. args.args .. " (expected on, off or toggle)", vim.log.levels.ERROR)
    return
  end
  action()
end, {
  nargs = "?",
  bar = true,
  complete = function(lead)
    return vim.tbl_filter(function(name)
      return name:find(lead, 1, true) == 1
    end, { "on", "off", "toggle" })
  end,
  desc = "bokeh.nvim — :Bokeh [on|off|toggle]",
})
