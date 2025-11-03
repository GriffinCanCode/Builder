#include <fmt/core.h>
#include <fmt/color.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

int main() {
    // Create configuration with JSON
    json config = {
        {"app", "multi-dependency-example"},
        {"dependencies", {
            {"fmt", "10.2.1"},
            {"json", "3.11.3"}
        }}
    };
    
    // Print with fmt (colored)
    fmt::print(fg(fmt::color::cyan), "=== Multi-Dependency Example ===\n");
    fmt::print("Using both {} and {} together\n", 
               config["dependencies"]["fmt"].get<std::string>(),
               config["dependencies"]["json"].get<std::string>());
    
    // Demonstrate formatting with JSON data
    fmt::print(fg(fmt::color::yellow), "\nConfiguration:\n");
    fmt::print("{}\n", config.dump(2));
    
    // Show repository rules benefit
    fmt::print(fg(fmt::color::green), "\n✓ All dependencies fetched via repository rules\n");
    fmt::print(fg(fmt::color::green), "✓ Hermetic build with integrity verification\n");
    fmt::print(fg(fmt::color::green), "✓ Cached locally for fast rebuilds\n");
    
    return 0;
}

