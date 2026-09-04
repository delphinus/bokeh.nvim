# Still images for the README.
#
#   vhs demo/stills.tape      (from the repository root)
#
# Writes assets/fade.png and assets/plain.png — the same buffer at the same
# cursor position, with the fade on and off, so they can sit side by side.
# VHS insists on a video Output, so that one goes to /tmp; only the PNGs
# land in the repository.

Output "/tmp/bokeh-stills.gif"

Require nvim

Set Shell zsh
Set FontSize 18
Set Width 900
Set Height 780
Set Padding 20
Set Theme { "background": "#282923", "foreground": "#f8f8f2" }

Hide
Type "nvim -u demo/shot.lua lua/bokeh/init.lua" Enter
Sleep 3s
Type "120G"
Sleep 1500ms
Show
Sleep 1s

Screenshot assets/fade.png
Sleep 1s

Hide
Type ":Bokeh off" Enter
Sleep 1s
# Entering and leaving the command line clears the echoed command, so both
# shots have an empty last row and can sit side by side.
Type ":" Escape
Sleep 500ms
Show
Sleep 1s

Screenshot assets/plain.png
Sleep 1s

Hide
Type ":qa!" Enter
