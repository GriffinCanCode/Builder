// Java project demonstrating common patterns
import java.util.*;
import java.util.stream.*;

// Class example
class Rectangle {
    private int width;
    private int height;
    
    public Rectangle(int width, int height) {
        this.width = width;
        this.height = height;
    }
    
    public int area() {
        return width * height;
    }
    
    public int perimeter() {
        return 2 * (width + height);
    }
    
    public int getWidth() { return width; }
    public int getHeight() { return height; }
}

public class Main {
    // Fibonacci function
    public static int fibonacci(int n) {
        if (n <= 1) return n;
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
    
    public static void main(String[] args) {
        System.out.println("=== Builder Java Example ===\n");
        
        // String operations
        String message = "Hello from Java!";
        System.out.println("String Operations:");
        System.out.println("  Original: " + message);
        System.out.println("  Uppercase: " + message.toUpperCase());
        System.out.println("  Length: " + message.length());
        
        // List operations (Collections)
        List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5);
        List<Integer> doubled = numbers.stream()
            .map(x -> x * 2)
            .collect(Collectors.toList());
        
        System.out.println("\nList Operations:");
        System.out.println("  Original: " + numbers);
        System.out.println("  Doubled: " + doubled);
        System.out.println("  Sum: " + numbers.stream().mapToInt(Integer::intValue).sum());
        
        // Map example
        Map<String, Integer> scores = new HashMap<>();
        scores.put("Alice", 95);
        scores.put("Bob", 87);
        scores.put("Charlie", 92);
        
        System.out.println("\nMap Example:");
        scores.forEach((name, score) -> 
            System.out.println("  " + name + ": " + score));
        
        // Class instance
        Rectangle rect = new Rectangle(10, 5);
        System.out.println("\nRectangle:");
        System.out.println("  Dimensions: " + rect.getWidth() + " x " + rect.getHeight());
        System.out.println("  Area: " + rect.area());
        System.out.println("  Perimeter: " + rect.perimeter());
        
        // Fibonacci
        System.out.println("\nFibonacci(10): " + fibonacci(10));
        
        // Stream API (Java 8+)
        System.out.println("\nStream API - Squares:");
        IntStream.rangeClosed(1, 5)
            .map(x -> x * x)
            .forEach(x -> System.out.print(x + " "));
        System.out.println();
    }
}

