# Example CMake project for migration testing
cmake_minimum_required(VERSION 3.10)
project(HelloWorld)

set(CMAKE_CXX_STANDARD 17)

# Main executable
add_executable(hello main.cpp greeter.cpp)

# Library
add_library(utils STATIC utils.cpp)

# Link library to executable
target_link_libraries(hello utils)

# Include directories
target_include_directories(hello PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Compiler options
target_compile_options(hello PRIVATE -Wall -Wextra)

