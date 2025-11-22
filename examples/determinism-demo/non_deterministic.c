/**
 * Non-Deterministic Build Demo
 * 
 * This program demonstrates sources of non-determinism.
 * Without determinism enforcement, it produces different outputs.
 */

#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(void) {
    printf("=== Non-Deterministic Build Demo ===\n\n");
    
    // System time (different each build)
    time_t current_time = time(NULL);
    printf("Current time: %ld (%s)\n", current_time, ctime(&current_time));
    
    // Process ID (may vary)
    pid_t pid = getpid();
    printf("Process ID: %d\n", pid);
    
    // Random values (truly random)
    srand((unsigned)time(NULL));
    printf("Random values: ");
    for (int i = 0; i < 5; i++) {
        printf("%d ", rand());
    }
    printf("\n");
    
    // Compile-time information
    printf("\nBuild information:\n");
    printf("Date: %s\n", __DATE__);
    printf("Time: %s\n", __TIME__);
    printf("File: %s\n", __FILE__);
    
    printf("\nSources of non-determinism:\n");
    printf("✗ System time varies between builds\n");
    printf("✗ Random numbers are truly random\n");
    printf("✗ Process IDs may differ\n");
    printf("✗ Build timestamps embedded\n");
    printf("✗ File paths may be absolute\n");
    
    printf("\n=== Build is non-deterministic! ===\n");
    
    return 0;
}

