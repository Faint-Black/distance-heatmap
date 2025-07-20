const sqrt = @import("std").math.sqrt;

pub const Vector = struct {
    x: f32,
    y: f32,

    pub fn add(a: Vector, b: Vector) Vector {
        return Vector{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    pub fn scale(self: Vector, scalar: f32) Vector {
        return Vector{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    pub fn dot(a: Vector, b: Vector) f32 {
        return (a.x * b.x) + (a.y * b.y);
    }

    pub fn cross(a: Vector, b: Vector) f32 {
        return (a.x * b.y) - (a.y * b.x);
    }

    pub fn magnitude(self: Vector) f32 {
        const x2 = self.x * self.x;
        const y2 = self.y * self.y;
        return sqrt(x2 + y2);
    }

    pub fn fromPoints(a: Vector, b: Vector) Vector {
        return Vector{
            .x = b.x - a.x,
            .y = b.y - a.y,
        };
    }
};
