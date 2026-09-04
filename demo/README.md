# Recording the README media

The images in the README are generated, not captured by hand, so they can be
redone whenever the defaults change.

```sh
brew install vhs        # or see https://github.com/charmbracelet/vhs

vhs demo/demo.tape      # assets/demo.gif
vhs demo/stills.tape    # assets/fade.png, assets/plain.png
```

Run both from the repository root — the tapes open `lua/bokeh/init.lua` by a
relative path.

## What is here

| File | Purpose |
|---|---|
| `shot.lua` | The Neovim config the tapes run against |
| `demo.tape` | The animated GIF: cursor movement, then `:Bokeh off` / `on` |
| `stills.tape` | The before/after pair, same buffer and cursor position |

`shot.lua` loads bokeh.nvim and nothing else, in `standalone` mode with every
option at its default, so the recordings show what a new user gets rather than
a tuned setup. The colorscheme is `unokai` because its `LineNr` starts at 4.2:1
against the background, which leaves the fade somewhere to go.

## Notes

- Keystrokes in the corner come from
  [screenkey.nvim](https://github.com/NStefan002/screenkey.nvim) when it is
  installed under `stdpath("data")/lazy`. Without it `shot.lua` defines a stub
  `:Screenkey`, so the tapes still run — you just get no keystroke window.
- `stills.tape` writes its video to `/tmp`. VHS requires a video `Output` even
  when only `Screenshot` is wanted, and an absolute path has to be quoted or
  the parser reads each segment as a command.
- Leave a `Sleep` between `Show` and `Screenshot`, and after `Screenshot`. VHS
  captures no frames if a `Show` block has no duration, and it keeps typing
  while a screenshot is still being written.
