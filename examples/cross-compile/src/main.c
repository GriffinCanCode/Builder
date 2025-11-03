#include <stdio.h>

#ifdef __x86_64__
    #define ARCH "x86_64"
#elif defined(__aarch64__)
    #define ARCH "aarch64"
#elif defined(__arm__)
    #define ARCH "arm"
#elif defined(__riscv) && (__riscv_xlen == 64)
    #define ARCH "riscv64"
#elif defined(__wasm32__)
    #define ARCH "wasm32"
#else
    #define ARCH "unknown"
#endif

#ifdef __linux__
    #define OS "Linux"
#elif defined(__APPLE__)
    #define OS "macOS"
#elif defined(_WIN32)
    #define OS "Windows"
#elif defined(__wasm__)
    #define OS "WebAssembly"
#else
    #define OS "unknown"
#endif

int main() {
    printf("Hello from Builder!\n");
    printf("Architecture: %s\n", ARCH);
    printf("Operating System: %s\n", OS);
    printf("Compiler: ");
    
#ifdef __clang__
    printf("Clang %d.%d.%d\n", __clang_major__, __clang_minor__, __clang_patchlevel__);
#elif defined(__GNUC__)
    printf("GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
#elif defined(_MSC_VER)
    printf("MSVC %d\n", _MSC_VER);
#else
    printf("Unknown\n");
#endif
    
    return 0;
}

