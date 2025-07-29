#!/usr/bin/bash

# generate palette
ffmpeg -y -framerate 10 -i frame_%04d.png -vf "scale=320:-1:flags=lanczos,palettegen=max_colors=64" palette.png

# generate gif
ffmpeg -y -framerate 10 -i frame_%04d.png -i palette.png -lavfi "scale=320:-1:flags=lanczos [x]; [x][1:v] paletteuse" demo.gif
