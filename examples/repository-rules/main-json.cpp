#include <nlohmann/json.hpp>
#include <iostream>

using json = nlohmann::json;

int main() {
    // Create JSON object
    json config = {
        {"name", "Builder"},
        {"version", "1.0.0"},
        {"features", {"repository-rules", "hermetic-builds", "caching"}},
        {"stats", {
            {"languages", 26},
            {"lines", 45000}
        }}
    };
    
    // Pretty print
    std::cout << "Configuration:\n" << config.dump(2) << std::endl;
    
    // Access values
    std::cout << "\nProject: " << config["name"] << std::endl;
    std::cout << "Features: " << config["features"].size() << std::endl;
    
    return 0;
}

