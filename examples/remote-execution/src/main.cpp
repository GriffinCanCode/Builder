#include <iostream>
#include "math.h"

int main() {
    std::cout << "Remote Execution Example\n";
    std::cout << "========================\n\n";
    
    // Test factorial
    std::cout << "Factorial(5) = " << factorial(5) << "\n";
    std::cout << "Factorial(10) = " << factorial(10) << "\n";
    
    // Test fibonacci
    std::cout << "Fibonacci(10) = " << fibonacci(10) << "\n";
    std::cout << "Fibonacci(20) = " << fibonacci(20) << "\n";
    
    // Test prime check
    std::cout << "Is 17 prime? " << (is_prime(17) ? "Yes" : "No") << "\n";
    std::cout << "Is 20 prime? " << (is_prime(20) ? "Yes" : "No") << "\n";
    
    std::cout << "\nBuild completed successfully!\n";
    std::cout << "This was built using Builder's remote execution system.\n";
    
    return 0;
}

