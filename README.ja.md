# bokeh.nvim

行番号に被写界深度を。

カーソル行から遠い行番号ほど段階的に背景へ溶かします。これから飛ぼうとしている
近くの行はくっきり残り、それ以外は後ろへ退きます。

![demo](assets/demo.gif)

やるのはこれだけです。サイン、折り畳み、行番号の並べ方は `'statuscolumn'` を
持っているものに任せます。

同じバッファの同じカーソル位置で、フェードを入れた場合と切った場合:

| `:Bokeh on` | `:Bokeh off` |
|---|---|
| ![フェードあり](assets/fade.png) | ![フェード無し](assets/plain.png) |

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
使えます。組み込みの行番号列と桁単位で一致します。`'numberwidth'` は区切りの
空白を含む幅なので、番号はそれより 1 桁狭い幅に右揃えされ、`'relativenumber'`
有効時のカーソル行の絶対番号は左に寄ります。別の並べ方にしたい場合 —
statuscol.nvim の `relculright` や桁区切りを使いたい場合など — は `hl` を他の
描画の前に置いてください。

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
  from = "LineNr",    -- フェードの起点となるハイライトグループ。{ above = …, below = … } も可
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

### カーソルの上と下で色を変える

`v:relnum` は距離であって向きを持たないので、既定ではカーソルの上下は同じように
薄くなります。向きごとにグループを指定すると塗り分けられます。

```lua
require("bokeh").setup {
  from = { above = "LineNrAbove", below = "LineNrBelow" },
}
```

`BokehFadeN` の代わりに `BokehFadeAbove1` 〜 と `BokehFadeBelow1` 〜 が作られ、
それぞれの向きの色を起点にフェードします。カーソル行の取得は描画する 1 行あたり
約 57 ns なので、画面全体でも 3 µs 程度です。

## 自分でガターを組む

外から使う口は `hl` だけなので、`'statuscolumn'` で書けるものなら何にでも
フェードを乗せられます。絶対と相対を並べて、向きで塗り分けた例:

![2 列のガター](assets/example.png)

```lua
local bokeh = require "bokeh"

vim.api.nvim_set_hl(0, "GutterAbove", { fg = "#7b9ac7" })
vim.api.nvim_set_hl(0, "GutterBelow", { fg = "#6aa781" })
vim.api.nvim_set_hl(0, "GutterAbsolute", { fg = "#6b7089" })

bokeh.setup { from = { above = "GutterAbove", below = "GutterBelow" } }

function _G.Gutter()
  local width = #tostring(vim.api.nvim_buf_line_count(0))
  if vim.v.virtnum ~= 0 then return (" "):rep(width + 5) end

  local absolute = tostring(vim.v.lnum)
  absolute = (" "):rep(width - #absolute) .. absolute

  -- カーソル行の相対列は "0" ではなく空にする。
  local relative = vim.v.relnum == 0 and "" or tostring(vim.v.relnum)
  relative = (" "):rep(4 - #relative) .. relative

  local absolute_hl = vim.v.relnum == 0 and "%#CursorLineNr#" or "%#GutterAbsolute#"
  return absolute_hl .. absolute .. bokeh.hl() .. relative .. " "
end

vim.o.statuscolumn = "%!v:lua.Gutter()"
```

この並べ方は bokeh の機能ではありませんし、そうである必要もありません。`hl()` は
カーソル行とフェードを切っているときに空文字列を返すので、どちらの場合でも列の
形は保たれます。全体は [demo/example.lua](demo/example.lua) にあります。

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
薄い段です。`from` を向きごとに指定した場合は `BokehFadeAbove1` 〜 と
`BokehFadeBelow1` 〜 になります。`from` (既定は `LineNr`) から他の属性を保ったまま
作られ、`ColorScheme` のたびに計算し直すので、起動時の色に固定されずカラースキーム
に追従します。

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

- 絶対行番号と相対行番号を並べて表示すること。bokeh.nvim は色を付けるだけです。
  列は自分で書くか ([自分でガターを組む](#自分でガターを組む) 参照)、
  [line-numbers.nvim](https://github.com/shrynx/line-numbers.nvim) を使ってください。
- マーク、折り畳み、サイン、折り返しインジケータ。いずれもフェードではなく
  statuscolumn の担当です。

## ライセンス

MIT
