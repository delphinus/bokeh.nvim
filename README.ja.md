# bokeh.nvim

行番号に被写界深度を。

カーソル行から遠い行番号ほど段階的に背景へ溶かします。これから飛ぼうとしている
近くの行はくっきり残り、それ以外は後ろへ退きます。

```
  12 │ local color = require "bokeh.color"      ← 薄い
   8 │
   4 │ function M.band(relnum)
   2 │   if relnum <= 0 then
   1 │     return nil
 142 │   end                                    ← カーソル行、そのまま
   1 │
   3 │ end
```

やるのはこれだけです。サイン、折り畳み、行番号の並べ方は `'statuscolumn'` を
持っているものに任せます。

[English README](README.md)

## 必要なもの

- Neovim 0.10 以降
- `'termguicolors'` (フェードを 24 bit カラーで計算するため)
- 任意で [statuscol.nvim](https://github.com/luukvbaal/statuscol.nvim)

## インストール

[lazy.nvim](https://github.com/folke/lazy.nvim) の場合:

```lua
{ "delphinus/bokeh.nvim", opts = {} }
```

## 使い方

bokeh.nvim がどこまで受け持つかで 3 通りあります。

### 1. 既にある行番号の描画に色を付ける

`require("bokeh").hl` は `%#BokehFadeN#` というハイライト項目を返すだけです。
行番号を描くセグメントの前に置けば、そちらの挙動 — statuscol.nvim の桁区切り、
`relculright`、行番号列へのサイン表示など — をそのまま保てます。

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

### 2. bokeh.nvim に行番号を描かせる

`require("bokeh").segment` は statuscol.nvim の `text` セグメントとしてそのまま
使えます。`'number'`、`'relativenumber'`、`'numberwidth'` は組み込みの行番号列と
同じように扱い、常に右揃えにします (`relculright = true` 相当)。

```lua
segments = {
  { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
  { text = { require("bokeh").segment }, click = "v:lua.ScLa" },
}
```

### 3. 単体で使う

他のプラグインを使わず、bokeh.nvim が `'statuscolumn'` に折り畳み列・サイン列・
フェードした行番号列を設定します。

```lua
require("bokeh").setup { standalone = true }
```

## 設定

既定値:

```lua
require("bokeh").setup {
  bands = 5,          -- フェードの段数
  distance = 12,      -- 最も薄い段に到達する距離
  amount = 0.7,       -- 最も薄い段でどこまで溶かすか (0..1)
  curve = "linear",   -- "linear" | "ease_in" | "ease_out" | fun(t: number): number
  target = nil,       -- 溶かす先の色。nil なら `Normal` の背景色
  from = "LineNr",    -- フェードの起点となるハイライトグループ
  standalone = false, -- 自分で 'statuscolumn' を設定する
  enabled = true,     -- 有効な状態で始める
  redraw = "auto",    -- 'relativenumber' 無しでもフェードを追従させる
}
```

短い距離で深く落とす場合:

```lua
require("bokeh").setup { bands = 8, distance = 6, amount = 0.85, curve = "ease_in" }
```

`curve` は段の刻み方を決めます。`ease_in` はカーソル近くをくっきり保って遠くで
一気に落とし、`ease_out` はカーソルのすぐ隣から強く落とします。どちらも合わない
場合は `fun(t: number): number` を渡してください。`t` は段を通して 0..1 で動き、
戻り値が `amount` に掛かります。

## 一時的に無効にする

```vim
:Bokeh          " 切り替え
:Bokeh off
:Bokeh on
```

```lua
require("bokeh").disable()
require("bokeh").enable()
require("bokeh").toggle()   -- 切り替えた後の状態を返す
require("bokeh").is_enabled()
```

描画のたびに参照される、スコープごとの変数もあります。

```lua
vim.g.bokeh_disable = true          -- 全体
vim.b[buf].bokeh_disable = true     -- そのバッファだけ
vim.w[win].bokeh_disable = true     -- そのウィンドウだけ
```

単体モードで無効にすると、`setup()` 前の `'statuscolumn'` を復元します。それ以外の
モードでは行番号の描画は続き、フェードの段の代わりに `LineNr` が使われます
(他のプラグインの statuscolumn から自分を外すことはできないため)。

## ハイライトグループ

`BokehFade1` 〜 `BokehFade{bands}` で、段 1 がカーソルに最も近く、`bands` が最も
薄い段です。`from` (既定は `LineNr`) から他の属性を保ったまま作られ、
`ColorScheme` のたびに計算し直すので、起動時の色に固定されずカラースキームに
追従します。

ブレンドでは作れない色にしたい場合は、後から上書きしてください。

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "BokehFade5", { fg = "#2a2f45", italic = true })
  end,
})
```

カーソル行には一切触れないので、`CursorLineNr` がそのまま残ります。

## `'relativenumber'` について

`'statuscolumn'` は、`'relativenumber'` が設定されている場合にのみカーソル移動で
再評価されます (`:help 'statuscolumn'`)。`'number'` だけを有効にしていると、
フェードは移動前のカーソル位置を指したままになるので、その場合に限り bokeh.nvim
が自分で再描画を促します。`redraw = false` で切れますし、`redraw = true` にすれば
常に促します。

`:checkhealth bokeh` で、この点と `'termguicolors'`、フェードの段の状態を確認でき
ます。

## やらないこと

- 絶対行番号と相対行番号を並べて表示すること。それには
  [line-numbers.nvim](https://github.com/shrynx/line-numbers.nvim) か
  statuscol.nvim を使ってください。bokeh.nvim は色を付けるだけです。
- カーソルの上と下でフェードを変えること。`v:relnum` はカーソル行からの**距離**で
  あって向きを持たないので、これを実現するには描画する行ごとにカーソル位置を引く
  必要があります。

## ライセンス

MIT
