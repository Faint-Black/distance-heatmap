const std = @import("std");
const Vector = @import("vector.zig").Vector;
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const HeatMap = struct {
    /// resolution, in pixels
    width: usize,
    height: usize,
    /// heatmap variables
    normalization_values: []f32,
    particles: []Particle,
    /// drawing related variables
    pixels: []rl.Color,
    texture: rl.Texture2D,
    farthest_point: Vector,
    colorscheme: ColorGradient,
    is_paused: bool,

    /// points from which distance will be calculated
    pub const Particle = struct {
        position: Vector,
        velocity: Vector,

        pub fn update(self: *Particle, right: f32, bottom: f32) void {
            if (self.position.x < 0.0 or self.position.x > right)
                self.velocity.x *= -1;
            if (self.position.y < 0.0 or self.position.y > bottom)
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

    /// heatmap color, first color means the farthest points
    const ColorGradient = enum {
        black_and_white,
        red_and_green,
        green_and_red,
        black_and_red,

        fn next(self: ColorGradient) ColorGradient {
            return switch (self) {
                .black_and_white => .red_and_green,
                .red_and_green => .green_and_red,
                .green_and_red => .black_and_red,
                .black_and_red => .black_and_white,
            };
        }

        fn previous(self: ColorGradient) ColorGradient {
            return switch (self) {
                .black_and_white => .black_and_red,
                .red_and_green => .black_and_white,
                .green_and_red => .red_and_green,
                .black_and_red => .green_and_red,
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize, particles: []Particle) HeatMap {
        const total_pixels = w * h;
        const normalization_values = allocator.alloc(f32, total_pixels) catch unreachable;
        const pixels = allocator.alloc(rl.Color, total_pixels) catch unreachable;
        return HeatMap{
            .width = w,
            .height = h,
            .normalization_values = normalization_values,
            .particles = particles,
            .pixels = pixels,
            .texture = undefined,
            .farthest_point = Vector{ .x = 0, .y = 0 },
            .colorscheme = .black_and_white,
            .is_paused = false,
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

        for (self.particles) |p|
            p.render();

        const farthest_point_pos = rl.Vector2{
            .x = self.farthest_point.x,
            .y = self.farthest_point.y,
        };
        rl.DrawCircleV(farthest_point_pos, 8.0, rl.BLACK);
        rl.DrawCircleV(farthest_point_pos, 6.0, rl.PINK);
    }

    pub fn update(self: *HeatMap) void {
        if (rl.IsKeyPressed(rl.KEY_RIGHT))
            self.colorscheme = self.colorscheme.next();
        if (rl.IsKeyPressed(rl.KEY_LEFT))
            self.colorscheme = self.colorscheme.previous();
        if (rl.IsKeyPressed(rl.KEY_SPACE))
            self.is_paused = !self.is_paused;

        if (self.is_paused)
            return;

        for (self.particles) |*p| {
            const right_border: f32 = @floatFromInt(self.width);
            const bottom_border: f32 = @floatFromInt(self.height);
            p.update(right_border, bottom_border);
        }
        self.calculateUnormalized();
        self.calculateNormalized();
        self.updatePixels();
    }

    /// for each pixel, calculate the distance to the closest particle
    fn calculateUnormalized(self: HeatMap) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const i = x + y * self.width;
                const pixel_pos = Vector{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                };
                var closest_distance: f32 = std.math.floatMax(f32);
                for (self.particles) |p| {
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

    /// turns the normalized values into a colorful image
    fn updatePixels(self: HeatMap) void {
        for (0..self.pixels.len) |i| {
            // farthest point = 255
            // closest point = 0
            const normal_float: f32 = self.normalization_values[i] * 255;
            const normal_byte: u8 = @as(u8, @intFromFloat(normal_float));
            const normal_byte_complement: u8 = 255 - normal_byte;
            const color = switch (self.colorscheme) {
                .black_and_white => rl.Color{
                    .r = normal_byte_complement,
                    .g = normal_byte_complement,
                    .b = normal_byte_complement,
                    .a = 255,
                },
                .red_and_green => rl.Color{
                    .r = normal_byte,
                    .g = normal_byte_complement,
                    .b = 0,
                    .a = 255,
                },
                .green_and_red => rl.Color{
                    .r = normal_byte_complement,
                    .g = normal_byte,
                    .b = 0,
                    .a = 255,
                },
                .black_and_red => rl.Color{
                    .r = normal_byte_complement,
                    .g = 0,
                    .b = 0,
                    .a = 255,
                },
            };
            self.pixels[i] = color;
        }
    }
};

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

test "normalization" {
    var float_array = [_]f32{ 7, 3, 1, 6, 9, 10, 2 };

    try std.testing.expectEqual(10.0, highestValue(&float_array));
    try std.testing.expectEqual(1.0, lowestValue(&float_array));

    normalizeSlice(&float_array);
    const expected_normalization = [_]f32{ 0.7, 0.3, 0.1, 0.6, 0.9, 1, 0.2 };
    try std.testing.expectEqualSlices(f32, &expected_normalization, &float_array);
}
