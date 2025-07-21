#!/usr/bin/bash

# generate palette
ffmpeg -y -framerate 10 -i frame_%04d.png -vf "scale=480:-1:flags=lanczos,palettegen=max_colors=32" palette.png

# generate gif
ffmpeg -y -framerate 10 -i frame_%04d.png -i palette.png -lavfi "scale=480:-1:flags=lanczos [x]; [x][1:v] paletteuse" demo.gif
