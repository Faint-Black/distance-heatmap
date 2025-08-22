# Distance heatmap
Visualization of the farthest locations from all points, calculated pixel-by-pixel and displayed in a variety of color schemes.

![Demo](ffmpeg/demo.gif)

The dot shown in pink is the absolute farthest point from all other particles at a given moment.

## Dependencies
* Zig 0.15.1
* Raylib 5.5

## Build and Run
To build and run, use:
```sh
zig build run
```

## Instructions
* Left/Right arrows to alternate heatmap color schemes.
* Spacebar to pause.
