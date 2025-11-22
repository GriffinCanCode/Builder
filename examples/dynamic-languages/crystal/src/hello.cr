#!/usr/bin/env crystal

# Crystal "Hello, World!" example
# Demonstrates spec-based language support in Builder

def greet(name : String = "World") : String
  "Hello, #{name}!"
end

puts greet
puts greet("Builder")
puts "Language: Crystal (spec-based)"
puts "Handler: SpecBasedHandler (automatic)"

