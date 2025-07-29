const std = @import("std");
const options = @import("build_options");
const Vector = @import("vector.zig").Vector;
const HeatMap = @import("heatmap.zig").HeatMap;
const rl = @cImport({
    @cInclude("raylib.h");
});

/// global variables
const window_width = 600;
const window_height = 600;
const framerate = 60;
var frame: usize = 0;
var screenshot_counter: usize = 0;

fn renderFrame(heatmap: *HeatMap) void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);

    heatmap.render();

    rl.EndDrawing();
    frame += 1;
}

pub fn main() void {
    // set up allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var particles = [_]HeatMap.Particle{
        .{
            .position = .{ .x = 200, .y = 200 },
            .velocity = .{ .x = 3, .y = 1 },
        },
        .{
            .position = .{ .x = 500, .y = 200 },
            .velocity = .{ .x = 1, .y = 5 },
        },
        .{
            .position = .{ .x = 0, .y = 0 },
            .velocity = .{ .x = 4, .y = 5 },
        },
        .{
            .position = .{ .x = 10, .y = 10 },
            .velocity = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = window_width - 10, .y = 10 },
            .velocity = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = window_width - 10, .y = window_height - 10 },
            .velocity = .{ .x = 0, .y = 0 },
        },
        .{
            .position = .{ .x = 10, .y = window_height - 10 },
            .velocity = .{ .x = 0, .y = 0 },
        },
    };

    var heatmap = HeatMap.init(allocator, window_width, window_height, particles[0..]);
    defer heatmap.deinit(allocator);

    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.SetTargetFPS(framerate);
    rl.InitWindow(window_width, window_height, "Distance Heatmap");
    while (!rl.WindowShouldClose()) {
        heatmap.update();
        renderFrame(&heatmap);

        if (options.generate_gif) {
            const gif_framerate = 10;
            const gif_duration = 10;
            if (screenshot_counter >= (gif_framerate * gif_duration)) {
                break;
            } else {
                takeScreenshot(framerate / gif_framerate);
            }
        }
    }
}

fn takeScreenshot(frameskip: comptime_int) void {
    if (frame % frameskip == 0) {
        var buffer: [256]u8 = undefined;
        const filename = std.fmt.bufPrint(&buffer, "frame_{:0>4}.png\x00", .{screenshot_counter}) catch unreachable;
        rl.TakeScreenshot(filename.ptr);
        screenshot_counter += 1;
    }
}
