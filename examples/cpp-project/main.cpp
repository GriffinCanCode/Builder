// C++ project demonstrating common patterns
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <numeric>
#include <map>

// Class example
class Rectangle {
private:
    int width;
    int height;

public:
    Rectangle(int w, int h) : width(w), height(h) {}
    
    int area() const {
        return width * height;
    }
    
    int perimeter() const {
        return 2 * (width + height);
    }
    
    int getWidth() const { return width; }
    int getHeight() const { return height; }
};

// Template function
template<typename T>
T fibonacci(T n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main() {
    std::cout << "=== Builder C++ Example ===\n\n";
    
    // String operations
    std::string message = "Hello from C++!";
    std::cout << "String Operations:\n";
    std::cout << "  Original: " << message << "\n";
    std::transform(message.begin(), message.end(), message.begin(), ::toupper);
    std::cout << "  Uppercase: " << message << "\n";
    
    // Vector operations (STL)
    std::vector<int> numbers = {1, 2, 3, 4, 5};
    std::vector<int> doubled;
    std::transform(numbers.begin(), numbers.end(), std::back_inserter(doubled),
                   [](int x) { return x * 2; });
    
    std::cout << "\nVector Operations:\n";
    std::cout << "  Original: [";
    for (size_t i = 0; i < numbers.size(); i++) {
        if (i > 0) std::cout << ", ";
        std::cout << numbers[i];
    }
    std::cout << "]\n";
    
    std::cout << "  Doubled: [";
    for (size_t i = 0; i < doubled.size(); i++) {
        if (i > 0) std::cout << ", ";
        std::cout << doubled[i];
    }
    std::cout << "]\n";
    
    int sum = std::accumulate(numbers.begin(), numbers.end(), 0);
    std::cout << "  Sum: " << sum << "\n";
    
    // Map example
    std::map<std::string, int> scores;
    scores["Alice"] = 95;
    scores["Bob"] = 87;
    scores["Charlie"] = 92;
    
    std::cout << "\nMap Example:\n";
    for (const auto& [name, score] : scores) {
        std::cout << "  " << name << ": " << score << "\n";
    }
    
    // Class instance
    Rectangle rect(10, 5);
    std::cout << "\nRectangle:\n";
    std::cout << "  Dimensions: " << rect.getWidth() << " x " << rect.getHeight() << "\n";
    std::cout << "  Area: " << rect.area() << "\n";
    std::cout << "  Perimeter: " << rect.perimeter() << "\n";
    
    // Template function usage
    std::cout << "\nFibonacci(10): " << fibonacci(10) << "\n";
    
    return 0;
}

