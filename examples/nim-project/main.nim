# Nim project demonstrating common patterns
import strutils, sequtils, tables

echo "=== Builder Nim Example ===\n"

# String operations
let message = "Hello from Nim!"
echo "String Operations:"
echo "  Original: ", message
echo "  Uppercase: ", message.toUpperAscii()
echo "  Length: ", message.len

# Sequence operations
let numbers = @[1, 2, 3, 4, 5]
let doubled = numbers.map(proc(x: int): int = x * 2)
echo "\nSequence Operations:"
echo "  Original: ", numbers
echo "  Doubled: ", doubled
echo "  Sum: ", numbers.foldl(a + b)

# Table (dictionary)
var scores = initTable[string, int]()
scores["Alice"] = 95
scores["Bob"] = 87
scores["Charlie"] = 92

echo "\nTable:"
for name, score in scores:
  echo "  ", name, ": ", score

# Object type
type Rectangle = object
  width: int
  height: int

proc area(r: Rectangle): int =
  r.width * r.height

proc perimeter(r: Rectangle): int =
  2 * (r.width + r.height)

let rect = Rectangle(width: 10, height: 5)
echo "\nRectangle:"
echo "  Dimensions: ", rect.width, " x ", rect.height
echo "  Area: ", rect.area()
echo "  Perimeter: ", rect.perimeter()

# Fibonacci function
proc fibonacci(n: int): int =
  if n <= 1: n
  else: fibonacci(n - 1) + fibonacci(n - 2)

echo "\nFibonacci (first 10):"
var fibs: seq[int] = @[]
for i in 0..9:
  fibs.add(fibonacci(i))
echo "  ", fibs.join(", ")

