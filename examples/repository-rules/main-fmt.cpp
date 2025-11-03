#include <fmt/core.h>
#include <fmt/color.h>

int main() {
    // Basic formatting
    fmt::print("Hello, {}!\n", "World");
    
    // Colored output
    fmt::print(fg(fmt::color::green), "Success: ");
    fmt::print("External dependency loaded from repository rule\n");
    
    // Formatted numbers
    fmt::print("Pi = {:.10f}\n", 3.14159265358979323846);
    
    return 0;
}

