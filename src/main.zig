const std = @import("std");
const options = @import("build_options");
const Vector = @import("vector.zig").Vector;
const rl = @cImport({
    @cInclude("raylib.h");
});

/// global variables
const window_width = 600;
const window_height = 600;
const framerate = 60;
var frame: usize = 0;

/// GIF generation variables
var screenshot_counter: usize = 0;
const gif_framerate = 10;
const gif_duration = 10;

/// returns the highest element of a float array
fn highestValue(values: []f32) f32 {
    var highest = values[0];
    for (values) |n| {
        if (n > highest)
            highest = n;
    }
    return highest;
}

/// returns the lowest element of a float array
fn lowestValue(values: []f32) f32 {
    var lowest = values[0];
    for (values) |n| {
        if (n < lowest)
            lowest = n;
    }
    return lowest;
}

/// divides each element with the highest number
fn normalizeSlice(values: []f32) void {
    const highest = highestValue(values);
    for (0..values.len) |i| {
        values[i] /= highest;
    }
}

const Particle = struct {
    position: Vector,
    velocity: Vector,

    pub fn update(self: *Particle) void {
        if (self.position.x < 0.0 or self.position.x > window_width)
            self.velocity.x *= -1;
        if (self.position.y < 0.0 or self.position.y > window_height)
            self.velocity.y *= -1;

        self.position.x += self.velocity.x;
        self.position.y += self.velocity.y;
    }

    pub fn render(self: Particle) void {
        const x: i32 = @intFromFloat(self.position.x);
        const y: i32 = @intFromFloat(self.position.y);
        rl.DrawCircle(x, y, 10, rl.BLACK);
        rl.DrawCircle(x, y, 7, rl.BLUE);
    }
};

const HeatMap = struct {
    /// resolution, in pixels
    width: usize,
    height: usize,
    /// heatmap variables
    normalization_values: []f32,
    /// drawing related variables
    pixels: []rl.Color,
    texture: rl.Texture2D,
    farthest_point: Vector,

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) HeatMap {
        const total_pixels = w * h;
        const normalization_values = allocator.alloc(f32, total_pixels) catch unreachable;
        const pixels = allocator.alloc(rl.Color, total_pixels) catch unreachable;
        return HeatMap{
            .width = w,
            .height = h,
            .normalization_values = normalization_values,
            .pixels = pixels,
            .texture = undefined,
            .farthest_point = Vector{ .x = 0, .y = 0 },
        };
    }

    pub fn deinit(self: HeatMap, allocator: std.mem.Allocator) void {
        rl.UnloadTexture(self.texture);
        allocator.free(self.normalization_values);
        allocator.free(self.pixels);
    }

    pub fn render(self: *HeatMap) void {
        if (!rl.IsTextureValid(self.texture)) {
            // generate texture for first time
            self.texture = rl.LoadTextureFromImage(self.generateImage());
        } else {
            // only update it the subsequent times
            rl.UpdateTexture(self.texture, self.pixels.ptr);
        }
        rl.DrawTexture(self.texture, 0, 0, rl.WHITE);

        const farthest_point_pos = rl.Vector2{
            .x = self.farthest_point.x,
            .y = self.farthest_point.y,
        };
        rl.DrawCircleV(farthest_point_pos, 10.0, rl.PINK);
    }

    pub fn update(self: *HeatMap, particles: []Particle) void {
        self.calculateUnormalized(particles);
        self.calculateNormalized();
        self.updatePixels();
    }

    /// for each pixel, calculate the distance to the closest particle
    fn calculateUnormalized(self: HeatMap, particles: []Particle) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const i = x + y * self.width;
                const pixel_pos = Vector{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                };
                var closest_distance: f32 = std.math.floatMax(f32);
                for (particles) |p| {
                    const distance = Vector.fromPoints(pixel_pos, p.position);
                    const distance_len = distance.magnitude();
                    if (distance_len < closest_distance)
                        closest_distance = distance_len;
                }
                self.normalization_values[i] = closest_distance;
            }
        }
    }

    /// for each pixel, normalize the distance values
    fn calculateNormalized(self: *HeatMap) void {
        normalizeSlice(self.normalization_values);
        var index_of_farthest: usize = undefined;
        for (0..self.normalization_values.len) |i| {
            if (self.normalization_values[i] == 1.0) {
                index_of_farthest = i;
                break;
            }
        }
        self.farthest_point = Vector{
            .x = @floatFromInt(index_of_farthest % self.width),
            .y = @floatFromInt(index_of_farthest / self.width),
        };
    }

    /// helper for generating the first texture
    fn generateImage(self: HeatMap) rl.Image {
        return rl.Image{
            .data = self.pixels.ptr,
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
            .mipmaps = 1,
            .width = @intCast(self.width),
            .height = @intCast(self.height),
        };
    }

    /// turns the normalized values into a grayscale image
    fn updatePixels(self: HeatMap) void {
        for (0..self.pixels.len) |i| {
            const normal: f32 = self.normalization_values[i] * 255;
            const grayscale: u8 = 255 - @as(u8, @intFromFloat(normal));
            self.pixels[i] = rl.Color{
                .r = grayscale,
                .g = grayscale,
                .b = grayscale,
                .a = 255,
            };
        }
    }
};

fn renderFrame(heatmap: *HeatMap, particles: []Particle) void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);

    heatmap.render();
    for (particles) |p| p.render();

    rl.EndDrawing();
    frame += 1;
}

pub fn main() void {
    // set up allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var heatmap = HeatMap.init(allocator, window_width, window_height);
    defer heatmap.deinit(allocator);

    var particles = [_]Particle{
        Particle{
            .position = .{ .x = 200, .y = 200 },
            .velocity = .{ .x = 3, .y = 1 },
        },
        Particle{
            .position = .{ .x = 500, .y = 200 },
            .velocity = .{ .x = 1, .y = 5 },
        },
        Particle{
            .position = .{ .x = 0, .y = 0 },
            .velocity = .{ .x = 4, .y = 4 },
        },
        Particle{
            .position = .{ .x = 0, .y = 0 },
            .velocity = .{ .x = 0, .y = 0 },
        },
        Particle{
            .position = .{ .x = window_width, .y = 0 },
            .velocity = .{ .x = 0, .y = 0 },
        },
        Particle{
            .position = .{ .x = window_width, .y = window_height },
            .velocity = .{ .x = 0, .y = 0 },
        },
        Particle{
            .position = .{ .x = 0, .y = window_height },
            .velocity = .{ .x = 0, .y = 0 },
        },
    };

    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.SetTargetFPS(framerate);
    rl.InitWindow(window_width, window_height, "Distance Heatmap");
    while (!rl.WindowShouldClose()) {
        for (&particles) |*p| {
            p.update();
        }
        heatmap.update(&particles);
        renderFrame(&heatmap, &particles);

        if (options.generate_gif) {
            const screenshot_delay = framerate / gif_framerate;
            if ((frame <= (framerate * gif_duration)) and (frame % screenshot_delay == 0)) {
                var buffer: [256]u8 = undefined;
                const filename = std.fmt.bufPrint(&buffer, "frame_{:0>4}.png\x00", .{screenshot_counter}) catch unreachable;
                rl.TakeScreenshot(filename.ptr);
                screenshot_counter += 1;
            }
        }
    }
}

test "normalization" {
    var float_array = [_]f32{ 7, 3, 1, 6, 9, 10, 2 };

    try std.testing.expectEqual(10.0, highestValue(&float_array));
    try std.testing.expectEqual(1.0, lowestValue(&float_array));

    normalizeSlice(&float_array);
    const expected_normalization = [_]f32{ 0.7, 0.3, 0.1, 0.6, 0.9, 1, 0.2 };
    try std.testing.expectEqualSlices(f32, &expected_normalization, &float_array);
}
