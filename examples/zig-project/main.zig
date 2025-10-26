// Zig project demonstrating common patterns
const std = @import("std");

pub fn main() void {
    std.debug.print("=== Builder Zig Example ===\n\n", .{});

    // String operations
    const message = "Hello from Zig!";
    std.debug.print("String Operations:\n", .{});
    std.debug.print("  Original: {s}\n", .{message});
    std.debug.print("  Length: {d}\n", .{message.len});

    // Array operations
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    std.debug.print("\nArray Operations:\n", .{});
    std.debug.print("  Original: [", .{});
    for (numbers, 0..) |num, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d}", .{num});
    }
    std.debug.print("]\n", .{});

    var sum: i32 = 0;
    for (numbers) |num| {
        sum += num;
    }
    std.debug.print("  Sum: {d}\n", .{sum});

    // Rectangle struct
    const Rectangle = struct {
        width: i32,
        height: i32,

        fn area(self: @This()) i32 {
            return self.width * self.height;
        }

        fn perimeter(self: @This()) i32 {
            return 2 * (self.width + self.height);
        }
    };

    const rect = Rectangle{ .width = 10, .height = 5 };
    std.debug.print("\nRectangle:\n", .{});
    std.debug.print("  Dimensions: {d} x {d}\n", .{ rect.width, rect.height });
    std.debug.print("  Area: {d}\n", .{rect.area()});
    std.debug.print("  Perimeter: {d}\n", .{rect.perimeter()});

    // Fibonacci function
    const fib = fibonacci(10);
    std.debug.print("\nFibonacci(10): {d}\n", .{fib});

    // Option type (comptime)
    comptime {
        const result = @as(i32, 42);
        _ = result;
    }
}

fn fibonacci(n: i32) i32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}
