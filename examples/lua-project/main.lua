-- Lua project demonstrating common patterns

print("=== Builder Lua Example ===\n")

-- String operations
local message = "Hello from Lua!"
print("String Operations:")
print("  Original: " .. message)
print("  Uppercase: " .. string.upper(message))
print("  Length: " .. #message)

-- Table operations (arrays)
local numbers = {1, 2, 3, 4, 5}
local doubled = {}
for i, v in ipairs(numbers) do
    doubled[i] = v * 2
end

print("\nTable Operations:")
print("  Original: {" .. table.concat(numbers, ", ") .. "}")
print("  Doubled: {" .. table.concat(doubled, ", ") .. "}")

local sum = 0
for _, v in ipairs(numbers) do
    sum = sum + v
end
print("  Sum: " .. sum)

-- Table as dictionary
local scores = {
    Alice = 95,
    Bob = 87,
    Charlie = 92
}

print("\nDictionary:")
for name, score in pairs(scores) do
    print("  " .. name .. ": " .. score)
end

-- Function and table as object
local Rectangle = {}
Rectangle.__index = Rectangle

function Rectangle.new(width, height)
    local self = setmetatable({}, Rectangle)
    self.width = width
    self.height = height
    return self
end

function Rectangle:area()
    return self.width * self.height
end

function Rectangle:perimeter()
    return 2 * (self.width + self.height)
end

local rect = Rectangle.new(10, 5)
print("\nRectangle:")
print("  Dimensions: " .. rect.width .. " x " .. rect.height)
print("  Area: " .. rect:area())
print("  Perimeter: " .. rect:perimeter())

-- Fibonacci function
local function fibonacci(n)
    if n <= 1 then return n end
    return fibonacci(n - 1) + fibonacci(n - 2)
end

print("\nFibonacci (first 10):")
local fibs = {}
for i = 0, 9 do
    fibs[i + 1] = fibonacci(i)
end
print("  " .. table.concat(fibs, ", "))

