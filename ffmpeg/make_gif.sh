#!/usr/bin/bash

# generate palette
ffmpeg -y -framerate 30 -i frame_%04d.png -vf palettegen palette.png

# generate gif
ffmpeg -y -framerate 30 -i frame_%04d.png -i palette.png -lavfi "paletteuse" output.gif
