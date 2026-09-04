# The "build your own column" still for the README.
#
#   vhs demo/example.tape     (from the repository root)
#
# Writes assets/example.png: absolute and relative side by side, fade split by
# direction. See demo/README.md for the VHS gotchas behind the sleeps.

Output "/tmp/bokeh-example.gif"

Require nvim

Set Shell zsh
Set FontSize 18
Set Width 900
Set Height 780
Set Padding 20
Set Theme { "background": "#282923", "foreground": "#f8f8f2" }

Hide
Type "nvim -u demo/example.lua lua/bokeh/init.lua" Enter
Sleep 3s
Type "120G"
Sleep 1500ms
Show
Sleep 1s

Screenshot assets/example.png
Sleep 1s

Hide
Type ":qa!" Enter
