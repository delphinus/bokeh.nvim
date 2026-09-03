# bokeh.nvim

Depth of field for your line numbers.

Line numbers far from the cursor are blended toward the background in discrete
steps, so the ones you are about to jump to stay legible and the rest recedes.

```
  12 │ local color = require "bokeh.color"      ← faded
   8 │
   4 │ function M.band(relnum)
   2 │   if relnum <= 0 then
   1 │     return nil
 142 │   end                                    ← cursor line, untouched
   1 │
   3 │ end
```

That is all it does. Signs, folds and the layout of the number column stay with
whoever owns your `'statuscolumn'`.

[日本語版の README](README.ja.md)

## Requirements

- Neovim 0.10+
- `'termguicolors'` (the fade is computed as 24-bit colour)
- Optionally [statuscol.nvim](https://github.com/luukvbaal/statuscol.nvim)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "delphinus/bokeh.nvim", opts = {} }
```

## Usage

There are three ways in, in order of how much bokeh.nvim takes over.

### 1. Colour a line number renderer you already have

`require("bokeh").hl` returns nothing but a `%#BokehFadeN#` highlight item.
Put it in front of a segment that renders line numbers and keep that renderer's
behaviour — statuscol.nvim's thousands separator, `relculright`, sign-in-number
column and so on all keep working.

```lua
local bokeh = require "bokeh"
bokeh.setup()

local builtin = require "statuscol.builtin"
require("statuscol").setup {
  relculright = true,
  segments = {
    { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
    { text = { bokeh.hl, builtin.lnumfunc }, click = "v:lua.ScLa" },
  },
}
```

### 2. Let bokeh.nvim render the numbers

`require("bokeh").segment` is a drop-in statuscol.nvim `text` segment. It
honours `'number'`, `'relativenumber'` and `'numberwidth'` the way the built-in
number column does, and right-aligns throughout (the equivalent of
`relculright = true`).

```lua
segments = {
  { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
  { text = { require("bokeh").segment }, click = "v:lua.ScLa" },
}
```

### 3. Standalone

No other plugin involved: bokeh.nvim sets `'statuscolumn'` to the fold column,
the sign column and a faded number column.

```lua
require("bokeh").setup { standalone = true }
```

## Configuration

Defaults:

```lua
require("bokeh").setup {
  bands = 5,          -- number of fade steps
  distance = 12,      -- distance at which the deepest band starts
  amount = 0.7,       -- how far the deepest band is blended, 0..1
  curve = "linear",   -- "linear" | "ease_in" | "ease_out" | fun(t: number): number
  target = nil,       -- colour to fade toward; nil means the `Normal` background
  from = "LineNr",    -- highlight group the fade starts from
  standalone = false, -- set 'statuscolumn' ourselves
  enabled = true,     -- start enabled
  redraw = "auto",    -- keep the fade in sync without 'relativenumber'
}
```

A deeper, shorter fade:

```lua
require("bokeh").setup { bands = 8, distance = 6, amount = 0.85, curve = "ease_in" }
```

`curve` shapes how the steps are distributed. `ease_in` keeps lines near the
cursor crisp and drops off late; `ease_out` fades hard right next to the cursor.
Pass your own `fun(t: number): number` if neither fits — `t` runs 0..1 across the
bands and the result scales `amount`.

## Turning it off

```vim
:Bokeh          " toggle
:Bokeh off
:Bokeh on
```

```lua
require("bokeh").disable()
require("bokeh").enable()
require("bokeh").toggle()   -- returns the state after flipping
require("bokeh").is_enabled()
```

Per scope, checked on every drawn line:

```lua
vim.g.bokeh_disable = true          -- everywhere
vim.b[buf].bokeh_disable = true     -- one buffer
vim.w[win].bokeh_disable = true     -- one window
```

In standalone mode, switching off restores the `'statuscolumn'` that was in
force before `setup()`. Otherwise the line numbers keep rendering, just with
`LineNr` instead of the fade bands — bokeh.nvim cannot unhook itself from
someone else's statuscolumn.

## Highlight groups

`BokehFade1` … `BokehFade{bands}`, where band 1 is nearest the cursor and
`bands` is the most faded. They are derived from `from` (`LineNr` by default),
keeping its other attributes, and are recomputed on every `ColorScheme` so they
track your colorscheme instead of freezing at startup.

Override them after the fact if you want colours the blend cannot produce:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "BokehFade5", { fg = "#2a2f45", italic = true })
  end,
})
```

The cursor line is never touched, so it keeps `CursorLineNr`.

## A note on `'relativenumber'`

`'statuscolumn'` is only re-evaluated on cursor movement when
`'relativenumber'` is set — see `:help 'statuscolumn'`. With only `'number'`
on, the fade would keep pointing at the line the cursor used to be on, so
bokeh.nvim forces the redraw itself in exactly that case. Set `redraw = false`
to opt out, or `redraw = true` to force it unconditionally.

`:checkhealth bokeh` reports this along with `'termguicolors'` and the state of
the fade bands.

## Non-goals

- Rendering absolute and relative numbers side by side. Use
  [line-numbers.nvim](https://github.com/shrynx/line-numbers.nvim) or
  statuscol.nvim for that; bokeh.nvim only colours.
- Fading above and below the cursor differently. `v:relnum` is the *distance*
  from the cursor line and carries no direction, so this would need the cursor
  position on every drawn line.

## License

MIT
