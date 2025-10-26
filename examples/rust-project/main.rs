// Rust project demonstrating common patterns
use std::collections::HashMap;

fn main() {
    println!("=== Builder Rust Example ===\n");

    // String operations
    let message = "Hello from Rust!";
    println!("String Operations:");
    println!("  Original: {}", message);
    println!("  Uppercase: {}", message.to_uppercase());
    println!("  Length: {}", message.len());

    // Vector operations
    let numbers = vec![1, 2, 3, 4, 5];
    let doubled: Vec<i32> = numbers.iter().map(|x| x * 2).collect();
    println!("\nVector Operations:");
    println!("  Original: {:?}", numbers);
    println!("  Doubled: {:?}", doubled);
    println!("  Sum: {}", numbers.iter().sum::<i32>());

    // HashMap example
    let mut scores = HashMap::new();
    scores.insert("Alice", 95);
    scores.insert("Bob", 87);
    scores.insert("Charlie", 92);
    
    println!("\nHashMap Example:");
    for (name, score) in &scores {
        println!("  {}: {}", name, score);
    }

    // Custom struct
    let rect = Rectangle { width: 10, height: 5 };
    println!("\nRectangle:");
    println!("  Dimensions: {} x {}", rect.width, rect.height);
    println!("  Area: {}", rect.area());
    println!("  Perimeter: {}", rect.perimeter());

    // Result handling
    match divide(10.0, 2.0) {
        Ok(result) => println!("\nDivision: 10 / 2 = {}", result),
        Err(e) => println!("Error: {}", e),
    }
}

// Custom struct
struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    fn area(&self) -> u32 {
        self.width * self.height
    }

    fn perimeter(&self) -> u32 {
        2 * (self.width + self.height)
    }
}

// Error handling example
fn divide(a: f64, b: f64) -> Result<f64, String> {
    if b == 0.0 {
        Err(String::from("Division by zero"))
    } else {
        Ok(a / b)
    }
}

