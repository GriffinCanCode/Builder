#!/usr/bin/env ruby
# Ruby project demonstrating common patterns

puts "=== Builder Ruby Example ===\n\n"

# String operations
message = "Hello from Ruby!"
puts "String Operations:"
puts "  Original: #{message}"
puts "  Uppercase: #{message.upcase}"
puts "  Reversed: #{message.reverse}"

# Array operations
numbers = [1, 2, 3, 4, 5]
doubled = numbers.map { |x| x * 2 }
puts "\nArray Operations:"
puts "  Original: #{numbers.inspect}"
puts "  Doubled: #{doubled.inspect}"
puts "  Sum: #{numbers.sum}"

# Hash example
scores = {
  "Alice" => 95,
  "Bob" => 87,
  "Charlie" => 92
}

puts "\nHash Example:"
scores.each do |name, score|
  puts "  #{name}: #{score}"
end

# Class example
class Rectangle
  attr_reader :width, :height

  def initialize(width, height)
    @width = width
    @height = height
  end

  def area
    width * height
  end

  def perimeter
    2 * (width + height)
  end
end

rect = Rectangle.new(10, 5)
puts "\nRectangle:"
puts "  Dimensions: #{rect.width} x #{rect.height}"
puts "  Area: #{rect.area}"
puts "  Perimeter: #{rect.perimeter}"

# Block example
puts "\nFibonacci (first 10):"
fib = Enumerator.new do |y|
  a, b = 0, 1
  loop do
    y << a
    a, b = b, a + b
  end
end

puts "  " + fib.take(10).join(", ")

