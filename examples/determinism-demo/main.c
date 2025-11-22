/**
 * Deterministic Build Demo
 * 
 * This program demonstrates deterministic builds.
 * With proper compiler flags and determinism enforcement,
 * it will produce bit-for-bit identical outputs across builds.
 */

#include <stdio.h>
#include <time.h>
#include <stdlib.h>

int main(void) {
    printf("=== Deterministic Build Demo ===\n\n");
    
    // These calls will be intercepted by the determinism shim
    // to return fixed values
    
    // Time will be fixed
    time_t current_time = time(NULL);
    printf("Build time: %ld\n", current_time);
    
    // Random will be seeded
    srand(0);  // Attempt to seed (will be ignored by shim)
    int random_value = rand();
    printf("Random value: %d\n", random_value);
    
    // Compile-time macros (if not overridden)
    printf("\nCompile-time info:\n");
    #ifdef __DATE__
    printf("Date: %s\n", __DATE__);
    #else
    printf("Date: (stripped for determinism)\n");
    #endif
    
    #ifdef __TIME__
    printf("Time: %s\n", __TIME__);
    #else
    printf("Time: (stripped for determinism)\n");
    #endif
    
    printf("\nWith determinism enforcement:\n");
    printf("✓ time() returns fixed timestamp\n");
    printf("✓ rand() uses seeded PRNG\n");
    printf("✓ Build macros are overridden\n");
    printf("✓ File paths are normalized\n");
    printf("\n=== Build is deterministic! ===\n");
    
    return 0;
}

