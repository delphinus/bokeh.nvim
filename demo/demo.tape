# The animated demo in the README.
#
#   vhs demo/demo.tape        (from the repository root)
#
# Two things a still cannot show: that the fade follows the cursor, and what
# the column looks like without it.

Output assets/demo.gif

Require nvim

Set Shell zsh
Set FontSize 18
Set Width 900
Set Height 780
Set Padding 20
Set Framerate 30
Set TypingSpeed 90ms
# Matches unokai's Normal background so the padding does not band against it.
Set Theme { "background": "#282923", "foreground": "#f8f8f2" }

Hide
Type "nvim -u demo/shot.lua lua/bokeh/init.lua" Enter
Sleep 3s
Type ":Screenkey" Enter
Sleep 1s
Type "120G"
Sleep 1s
Show

Sleep 2s

# The fade recentres on every move — this is the part a still cannot show.
Type "12j"
Sleep 1800ms
Type "20k"
Sleep 1800ms
Type "8j"
Sleep 1800ms

# And this is what it is doing, against the plain column.
Type ":Bokeh off" Enter
Sleep 2500ms
Type ":Bokeh on" Enter
Sleep 2500ms

Hide
Type ":qa!" Enter
