# Distance heatmap
Visualization of the farthest locations from all points, calculated pixel-by-pixel and displayed in grayscale.

![Demo](ffmpeg/demo.gif)

As shown in pink is the absolute farthest point from all other particles at a given moment.

## Build and Run
To build and run, use:
```sh
zig build run --release=fast
```
