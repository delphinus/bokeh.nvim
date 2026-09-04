--- bokeh.nvim — depth of field for your line numbers.
---
--- Line numbers far from the cursor are blended toward the background in
--- discrete steps, so the ones you are about to jump to stay legible while the
--- rest recedes. Nothing else is drawn: signs, folds and the numbers' layout
--- stay with whoever owns your |'statuscolumn'|.
---
--- Three ways in, in order of how much this plugin takes over:
---
---   1. |bokeh.hl()| — returns just a `%#BokehFadeN#` highlight item. Put it in
---      front of a segment that already renders line numbers (for example
---      statuscol.nvim's `builtin.lnumfunc`) and keep that renderer's
---      behaviour.
---   2. |bokeh.segment()| — renders the number itself. Drop-in `text` segment
---      for statuscol.nvim.
---   3. `standalone = true` — sets |'statuscolumn'| to fold, signs and a faded
---      number column, no other plugin involved.
---
--- The fade is driven by |v:relnum|, which is the *distance* from the cursor
--- line and is therefore symmetric: lines above and below fade alike.
local color = require "bokeh.color"

local M = {}

--- Prefix of the generated highlight groups: `BokehFade1` .. `BokehFade{bands}`,
--- or `BokehFadeAbove1` / `BokehFadeBelow1` .. when `from` names two groups.
--- Band 1 is nearest the cursor, `bands` is the most faded.
local GROUP = "BokehFade"

---@class bokeh.Config
---@field bands? integer       Number of fade steps (default: 5).
---@field distance? integer    Distance at which the deepest band starts (default: 12).
---@field amount? number       How far the deepest band is blended, 0..1 (default: 0.7).
---@field curve? bokeh.Curve   Distribution of the steps (default: "linear").
---@field target? string|integer  Colour to fade toward (default: `Normal` background).
---@field from? string|bokeh.Directional  Group(s) the fade starts from (default: "LineNr").
---@field standalone? boolean  Set |'statuscolumn'| ourselves (default: false).
---@field enabled? boolean     Start enabled (default: true).
---@field redraw? "auto"|boolean  Keep the fade in sync without |'relativenumber'| (default: "auto").

---@class bokeh.Directional
---@field above string  Highlight group for lines above the cursor.
---@field below string  Highlight group for lines below the cursor.

---@alias bokeh.Curve "linear"|"ease_in"|"ease_out"|fun(t: number): number

---@type bokeh.Config
local defaults = {
  bands = 5,
  distance = 12,
  amount = 0.7,
  curve = "linear",
  target = nil,
  from = "LineNr",
  standalone = false,
  enabled = true,
  redraw = "auto",
}

local config = vim.deepcopy(defaults)

local state = {
  --- setup() has run. Before that every entry point renders as if disabled.
  ready = false,
  --- Runtime on/off, flipped by |bokeh.toggle()| and `:Bokeh`.
  enabled = true,
  --- False when the fade cannot be computed (no 'termguicolors', or the source
  --- group has no foreground). The bands then link to `from` and we stay out of
  --- the way instead of rendering a wrong colour.
  usable = false,
  --- Distance covered by one band.
  step = 1,
  --- 'statuscolumn' as it was before standalone mode took over.
  saved_stc = nil,
  --- True when `from` names a group per direction.
  directional = false,
  --- Ready-made `%#Group#` items indexed by band, so the render path does no
  --- string building at all. Directional configs fill `items.above` /
  --- `items.below` instead of the array part.
  items = {},
}

--- Named easings for `curve`. `t` runs 0..1 across the bands and the result
--- scales `amount`, so ease_in keeps nearby lines crisp and drops off late,
--- ease_out fades hard right next to the cursor.
local curves = {
  linear = function(t)
    return t
  end,
  ease_in = function(t)
    return t * t
  end,
  ease_out = function(t)
    return 1 - (1 - t) * (1 - t)
  end,
}

---Ask Neovim to redraw every 'statuscolumn'.
---
--- `nvim__redraw()` is experimental, hence the guard; the fallback is a full
--- redraw, which is heavier but only ever runs on an explicit toggle.
---@param opts? table
local function redraw(opts)
  if vim.api.nvim__redraw then
    local ok = pcall(vim.api.nvim__redraw, opts or { statuscolumn = true, valid = false })
    if ok then return end
  end
  pcall(vim.cmd.redraw, { bang = true })
end

---Resolve the colour the bands fade toward.
---@return integer  24-bit RGB
local function resolve_target()
  local explicit = color.to_rgb(config.target)
  if explicit then return explicit end
  local normal = color.attrs "Normal"
  if normal and normal.bg then return normal.bg end
  -- A transparent background leaves us nothing to read, so fall back to the
  -- extreme implied by 'background'.
  return vim.o.background == "dark" and 0x000000 or 0xffffff
end

---The band sets to build, one per source group.
---
--- A plain `from` yields a single unnamed set; a directional one yields
--- "Above" and "Below".
---@return { suffix: string, source: string, key: string? }[]
local function band_sets()
  if type(config.from) == "table" then
    return {
      { suffix = "Above", source = config.from.above, key = "above" },
      { suffix = "Below", source = config.from.below, key = "below" },
    }
  end
  return { { suffix = "", source = config.from } }
end

---(Re-)register the fade highlight groups and the items that name them.
---
--- Called at setup and again on every |ColorScheme|, so the bands track the
--- colorscheme instead of freezing at the colours present at startup.
local function resolve_highlights()
  local sets = band_sets()
  state.directional = #sets > 1
  state.items = {}

  local attrs_of = {}
  state.usable = vim.o.termguicolors
  for _, set in ipairs(sets) do
    local from = color.attrs(set.source)
    attrs_of[set.suffix] = from
    if not (from and from.fg) then state.usable = false end
  end

  -- Build the `%#Group#` items up front. The render path then does a table
  -- lookup instead of concatenating a string for every screen line.
  for _, set in ipairs(sets) do
    local items = {}
    for i = 1, config.bands do
      items[i] = "%#" .. GROUP .. set.suffix .. i .. "#"
    end
    if set.key then
      state.items[set.key] = items
    else
      state.items = items
    end
  end

  if not state.usable then
    -- Nothing to blend, so link the bands to their source and stay out of the
    -- way rather than rendering a wrong colour.
    for _, set in ipairs(sets) do
      for i = 1, config.bands do
        vim.api.nvim_set_hl(0, GROUP .. set.suffix .. i, { link = set.source })
      end
    end
    return
  end

  local target = resolve_target()
  local curve = type(config.curve) == "function" and config.curve or curves[config.curve] or curves.linear

  for _, set in ipairs(sets) do
    local from = attrs_of[set.suffix]
    for i = 1, config.bands do
      -- Other attributes of the source group (bold, italic, …) are kept so a
      -- faded number still looks like a line number.
      local attrs = vim.deepcopy(from)
      attrs.fg = color.blend(from.fg, target, curve(i / config.bands) * config.amount)
      vim.api.nvim_set_hl(0, GROUP .. set.suffix .. i, attrs)
    end
  end
end

---Memoise the `vim.b` / `vim.w` accessors.
---
--- Indexing `vim.b[buf]` builds a fresh proxy table every time, which measures
--- around 280ns — far too much for something evaluated once per screen line per
--- redraw. Reading a field off an existing proxy is ~28ns and still goes to
--- live state, so caching the proxy costs nothing in correctness.
---@param scope table  `vim.b` or `vim.w`
---@return table
local function var_cache(scope)
  return setmetatable({}, {
    __index = function(cache, id)
      local proxy = scope[id]
      rawset(cache, id, proxy)
      return proxy
    end,
  })
end

local buf_vars = var_cache(vim.b)
local win_vars = var_cache(vim.w)

---Whether the fade should apply right now, for this buffer and window.
---@param args? table  statuscol.nvim segment args
---@return boolean
local function active(args)
  if not (state.ready and state.enabled and state.usable) then return false end
  if vim.g.bokeh_disable then return false end
  local buf = args and args.buf or vim.api.nvim_get_current_buf()
  if buf_vars[buf].bokeh_disable then return false end
  local win = args and args.win or vim.api.nvim_get_current_win()
  if win_vars[win].bokeh_disable then return false end
  return true
end

---Build the argument table |bokeh.segment()| expects when nothing supplies one.
---
--- 'statuscolumn' is evaluated with the window being drawn as the current
--- window, so the plain accessors already describe the right window.
---@return table
local function current_args()
  local win = vim.api.nvim_get_current_win()
  return {
    buf = vim.api.nvim_get_current_buf(),
    win = win,
    lnum = vim.v.lnum,
    relnum = vim.v.relnum,
    virtnum = vim.v.virtnum,
    nu = vim.wo[win].number,
    rnu = vim.wo[win].relativenumber,
    nuw = vim.wo[win].numberwidth,
  }
end

---Map a distance from the cursor line to a fade band.
---@param relnum integer  |v:relnum|; always >= 0, so above and below match
---@return integer|nil    Band index, or nil for the cursor line itself
function M.band(relnum)
  if not relnum or relnum <= 0 then return nil end
  return math.min(config.bands, math.ceil(relnum / state.step))
end

---Return the highlight item for the line currently being drawn.
---
--- Empty string on the cursor line (leaving |hl-CursorLineNr| alone) and
--- whenever the fade is disabled. Use this to colour a line number renderer you
--- already have: >lua
---
---   local bokeh = require "bokeh"
---   require("statuscol").setup {
---     segments = {
---       { text = { bokeh.hl, require("statuscol.builtin").lnumfunc } },
---     },
---   }
--- <
---@param args? table  statuscol.nvim segment args
---@return string
function M.hl(args)
  if not active(args) then return "" end
  local band = M.band(args and args.relnum or vim.v.relnum)
  if not band then return "" end
  if not state.directional then return state.items[band] end
  -- |v:relnum| is a distance and says nothing about direction, so the cursor
  -- line has to be read. It costs ~57ns, which is affordable once per drawn
  -- line; the alternative, caching it per redraw, buys little and can go stale.
  local lnum = args and args.lnum or vim.v.lnum
  local cursor = vim.api.nvim_win_get_cursor(args and args.win or 0)[1]
  return lnum > cursor and state.items.below[band] or state.items.above[band]
end

---Render the line number for the line currently being drawn, faded.
---
--- Matches the built-in number column cell for cell: |'numberwidth'| counts the
--- separating space, so the number is right-aligned in one column less than
--- that, and with 'relativenumber' set the cursor line's absolute number goes
--- to the left instead. Use |bokeh.hl()| in front of another renderer if you
--- want a different layout — statuscol.nvim's `relculright` or its `thousands`
--- separator, say.
---@param args? table  statuscol.nvim segment args
---@return string
function M.segment(args)
  args = args or current_args()
  if not (args.nu or args.rnu) then return "" end
  -- Wrapped and virtual lines get the width but not the number, so the text
  -- next to them stays aligned.
  if args.virtnum ~= 0 then return "%= " end

  local number = args.rnu and (args.relnum > 0 and args.relnum or (args.nu and args.lnum or 0)) or args.lnum
  local text = tostring(number)
  local pad = (" "):rep(math.max(0, (args.nuw or 4) - 1 - #text))

  local body
  if args.rnu and args.nu and args.relnum == 0 then
    body = text .. pad .. "%="
  else
    body = "%=" .. pad .. text
  end
  body = body .. " "

  local hl = M.hl(args)
  return hl == "" and body or hl .. body .. "%*"
end

---'statuscolumn' expression used by `standalone = true`.
---
--- Fold column, sign column, then the faded numbers — the order Neovim draws
--- them in by default.
---@return string
function M.statuscolumn()
  return "%C%s" .. M.segment()
end

---Apply a 'statuscolumn' value to every window, and to windows opened later.
---
--- 'statuscolumn' is window-local; new windows inherit it from the window they
--- are split off, so setting every existing window is enough to cover the
--- session.
---@param value string
local function apply_stc(value)
  vim.o.statuscolumn = value
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    pcall(vim.api.nvim_set_option_value, "statuscolumn", value, { win = win })
  end
end

---Whether the fade is currently on.
---@return boolean
function M.is_enabled()
  return state.enabled
end

---Turn the fade on.
function M.enable()
  state.enabled = true
  if config.standalone then apply_stc "%!v:lua.require'bokeh'.statuscolumn()" end
  redraw()
end

---Turn the fade off.
---
--- In standalone mode the |'statuscolumn'| in force before setup is restored,
--- so the column goes back to whatever it was. Otherwise the line numbers keep
--- rendering, just with |hl-LineNr| instead of the bands — this plugin cannot
--- unhook itself from someone else's statuscolumn.
function M.disable()
  state.enabled = false
  if config.standalone then apply_stc(state.saved_stc or "") end
  redraw()
end

---Flip the fade.
---@return boolean  The state after flipping
function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
  return state.enabled
end

---Recompute the fade bands from the current colours.
---
--- Already done on every |ColorScheme|. Call it by hand when the groups named
--- by `from` are themselves defined by your config: `:colorscheme` clears every
--- highlight group, and the order autocommands run in decides whether they are
--- back by the time the bands are rebuilt. Redefine them, then refresh.
function M.refresh()
  if not state.ready then return end
  resolve_highlights()
  redraw()
end

---Return the resolved configuration.
---@return bokeh.Config
function M.get_config()
  return vim.deepcopy(config)
end

---Initialise bokeh.nvim.
---
--- Registers the fade highlight groups, keeps them in sync with the
--- colorscheme, and — only when `standalone` is set — takes over
--- |'statuscolumn'|. |'number'| and |'relativenumber'| are never changed: what
--- the number column shows stays your decision.
---
--- ── statuscol.nvim, rendering the numbers ourselves ────────────────────────
---
---   require("bokeh").setup()
---
---   local builtin = require "statuscol.builtin"
---   require("statuscol").setup {
---     relculright = true,
---     segments = {
---       { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
---       { text = { require("bokeh").segment }, click = "v:lua.ScLa" },
---     },
---   }
---
--- ── statuscol.nvim, keeping its own line number renderer ───────────────────
---
---   { text = { require("bokeh").hl, builtin.lnumfunc }, click = "v:lua.ScLa" },
---
--- ── No other plugin ────────────────────────────────────────────────────────
---
---   require("bokeh").setup { standalone = true }
---
--- ── A deeper, shorter fade ─────────────────────────────────────────────────
---
---   require("bokeh").setup {
---     bands = 8,
---     distance = 6,
---     amount = 0.85,
---     curve = "ease_in",
---   }
---
---@param opts? bokeh.Config  Partial config; merged over the defaults
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  if type(config.bands) ~= "number" or config.bands < 1 then
    vim.notify("[bokeh] `bands` must be >= 1; using " .. defaults.bands, vim.log.levels.WARN)
    config.bands = defaults.bands
  end
  config.bands = math.floor(config.bands)
  if type(config.distance) ~= "number" or config.distance < 1 then
    vim.notify("[bokeh] `distance` must be >= 1; using " .. defaults.distance, vim.log.levels.WARN)
    config.distance = defaults.distance
  end
  config.amount = math.min(1, math.max(0, config.amount))
  state.step = config.distance / config.bands

  resolve_highlights()

  local group = vim.api.nvim_create_augroup("Bokeh", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = resolve_highlights })
  -- Drop the memoised variable accessors along with what they point at.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      buf_vars[ev.buf] = nil
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      win_vars[tonumber(ev.match)] = nil
    end,
  })
  -- Losing or gaining 24-bit colour changes whether we can blend at all.
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "termguicolors",
    callback = resolve_highlights,
  })

  -- 'statuscolumn' is only re-evaluated on cursor movement when
  -- 'relativenumber' is set (see |'statuscolumn'|). Without that the fade would
  -- keep pointing at the line the cursor used to be on, so nudge the redraw
  -- ourselves in exactly that case.
  if config.redraw ~= false then
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = group,
      callback = function()
        if config.redraw == "auto" and vim.wo.relativenumber then return end
        redraw { win = 0, statuscolumn = true }
      end,
    })
  end

  -- Remember what to hand back when the fade is switched off later.
  if config.standalone then state.saved_stc = vim.o.statuscolumn end

  state.ready = true
  state.enabled = config.enabled ~= false
  if state.enabled and config.standalone then apply_stc "%!v:lua.require'bokeh'.statuscolumn()" end
end

return M
