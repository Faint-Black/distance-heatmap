const std = @import("std");
const options = @import("build_options");
const rl = @cImport({
    @cInclude("raylib.h");
});

/// global constants
const window_width = 600;
const window_height = 600;
const framerate = 60;

/// global variables
var frame: usize = 0;

fn highestValue(values: []f32) f32 {
    var highest = values[0];
    for (values) |n| {
        if (n > highest)
            highest = n;
    }
    return highest;
}

fn normalizeSlice(values: []f32) void {
    const highest = highestValue(values);
    for (0..values.len) |i| {
        values[i] /= highest;
    }
}

const Vector = struct {
    x: f32,
    y: f32,

    fn add(a: Vector, b: Vector) Vector {
        return Vector{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    fn scale(self: Vector, scalar: f32) Vector {
        return Vector{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    fn dot(a: Vector, b: Vector) f32 {
        return (a.x * b.x) + (a.y * b.y);
    }

    fn cross(a: Vector, b: Vector) f32 {
        return (a.x * b.y) - (a.y * b.x);
    }

    fn magnitude(self: Vector) f32 {
        const x2 = self.x * self.x;
        const y2 = self.y * self.y;
        return std.math.sqrt(x2 + y2);
    }

    fn fromPoints(a: Vector, b: Vector) Vector {
        return Vector{
            .x = b.x - a.x,
            .y = b.y - a.y,
        };
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
    }

    pub fn update(self: HeatMap, particle: Vector) void {
        self.calculateUnormalized(particle);
        self.calculateNormalized();
        self.updatePixels();
    }

    fn calculateUnormalized(self: HeatMap, particle: Vector) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const i = x + y * self.width;
                const pixel_pos = Vector{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                };
                self.normalization_values[i] = Vector.fromPoints(pixel_pos, particle).magnitude();
            }
        }
    }

    fn calculateNormalized(self: HeatMap) void {
        normalizeSlice(self.normalization_values);
    }

    fn generateImage(self: HeatMap) rl.Image {
        return rl.Image{
            .data = self.pixels.ptr,
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
            .mipmaps = 1,
            .width = @intCast(self.width),
            .height = @intCast(self.height),
        };
    }

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

fn renderFrame(heatmap: *HeatMap, particles: []const Vector) void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);

    heatmap.render();

    for (particles) |p| {
        const x: i32 = @intFromFloat(p.x);
        const y: i32 = @intFromFloat(p.y);
        rl.DrawCircle(x, y, 10, rl.BLACK);
        rl.DrawCircle(x, y, 7, rl.BLUE);
    }

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

    const particles = [_]Vector{
        Vector{ .x = 200, .y = 200 },
    };

    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.SetTargetFPS(framerate);
    rl.InitWindow(window_width, window_height, "Distance Heatmap");
    while (!rl.WindowShouldClose()) {
        heatmap.update(particles[0]);
        renderFrame(&heatmap, &particles);
    }
}

test "normalization" {
    var float_array = [_]f32{ 0, 3, 1, 6, 9, 10, 2 };
    const expected_normalization = [_]f32{ 0, 0.3, 0.1, 0.6, 0.9, 1, 0.2 };
    try std.testing.expectEqual(10.0, highestValue(&float_array));
    normalizeSlice(&float_array);
    try std.testing.expectEqualSlices(f32, &expected_normalization, &float_array);
}
