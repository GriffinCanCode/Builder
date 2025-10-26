// Zig project demonstrating common patterns
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("=== Builder Zig Example ===\n\n", .{});
    
    // String operations
    const message = "Hello from Zig!";
    try stdout.print("String Operations:\n", .{});
    try stdout.print("  Original: {s}\n", .{message});
    try stdout.print("  Length: {d}\n", .{message.len});
    
    // Array operations
    const numbers = [_]i32{1, 2, 3, 4, 5};
    try stdout.print("\nArray Operations:\n", .{});
    try stdout.print("  Original: [", .{});
    for (numbers, 0..) |num, i| {
        if (i > 0) try stdout.print(", ", .{});
        try stdout.print("{d}", .{num});
    }
    try stdout.print("]\n", .{});
    
    var sum: i32 = 0;
    for (numbers) |num| {
        sum += num;
    }
    try stdout.print("  Sum: {d}\n", .{sum});
    
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
    try stdout.print("\nRectangle:\n", .{});
    try stdout.print("  Dimensions: {d} x {d}\n", .{rect.width, rect.height});
    try stdout.print("  Area: {d}\n", .{rect.area()});
    try stdout.print("  Perimeter: {d}\n", .{rect.perimeter()});
    
    // Fibonacci function
    const fib = fibonacci(10);
    try stdout.print("\nFibonacci(10): {d}\n", .{fib});
}

fn fibonacci(n: i32) i32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

