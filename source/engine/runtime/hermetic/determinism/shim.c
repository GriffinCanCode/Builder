/**
 * Determinism Shim Library
 * 
 * Intercepts non-deterministic syscalls and provides deterministic replacements.
 * Used via LD_PRELOAD (Linux) or DYLD_INSERT_LIBRARIES (macOS).
 * 
 * Intercepted functions:
 * - time(), gettimeofday(), clock_gettime() -> fixed timestamp
 * - random(), rand(), arc4random() -> seeded PRNG
 * - getpid() -> fixed PID (for deterministic output)
 * - uuid_generate() -> deterministic UUID generation
 */

#define _GNU_SOURCE
#include <time.h>
#include <sys/time.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

/* Configuration from environment variables */
static time_t fixed_timestamp = 0;
static unsigned int prng_seed = 0;
static int initialized = 0;

/* Function pointers to real implementations */
static time_t (*real_time)(time_t *) = NULL;
static int (*real_gettimeofday)(struct timeval *, struct timezone *) = NULL;
static int (*real_clock_gettime)(clockid_t, struct timespec *) = NULL;
static long (*real_random)(void) = NULL;
static int (*real_rand)(void) = NULL;

/* Simple PRNG state */
static unsigned long prng_state = 0;

/**
 * Initialize shim library
 * Reads configuration from environment variables
 */
static void initialize_shim(void) {
    if (initialized)
        return;
    
    /* Load configuration from environment */
    const char *timestamp_env = getenv("BUILD_TIMESTAMP");
    if (timestamp_env) {
        fixed_timestamp = (time_t)atoll(timestamp_env);
    } else {
        fixed_timestamp = 1640995200; /* Default: 2022-01-01 00:00:00 UTC */
    }
    
    const char *seed_env = getenv("RANDOM_SEED");
    if (seed_env) {
        prng_seed = (unsigned int)atoi(seed_env);
    } else {
        prng_seed = 42; /* Default seed */
    }
    
    /* Initialize PRNG */
    prng_state = prng_seed;
    
    /* Locate real functions */
    real_time = (time_t (*)(time_t *))dlsym(RTLD_NEXT, "time");
    real_gettimeofday = (int (*)(struct timeval *, struct timezone *))
        dlsym(RTLD_NEXT, "gettimeofday");
    real_clock_gettime = (int (*)(clockid_t, struct timespec *))
        dlsym(RTLD_NEXT, "clock_gettime");
    real_random = (long (*)(void))dlsym(RTLD_NEXT, "random");
    real_rand = (int (*)(void))dlsym(RTLD_NEXT, "rand");
    
    initialized = 1;
    
    /* Optional: Log initialization (can be disabled for production) */
    #ifdef DETSHIM_DEBUG
    fprintf(stderr, "[detshim] Initialized: timestamp=%ld, seed=%u\n",
            (long)fixed_timestamp, prng_seed);
    #endif
}

/**
 * Simple deterministic PRNG (Linear Congruential Generator)
 * Not cryptographically secure, but good enough for determinism
 */
static unsigned long detshim_prng(void) {
    prng_state = (prng_state * 1103515245 + 12345) & 0x7fffffff;
    return prng_state;
}

/* ========================================================================
 * Intercepted Functions
 * ======================================================================== */

/**
 * Override time() with fixed timestamp
 */
time_t time(time_t *tloc) {
    if (!initialized)
        initialize_shim();
    
    if (tloc)
        *tloc = fixed_timestamp;
    
    return fixed_timestamp;
}

/**
 * Override gettimeofday() with fixed timestamp
 */
int gettimeofday(struct timeval *tv, void *tzp) {
    if (!initialized)
        initialize_shim();
    
    if (tv) {
        tv->tv_sec = fixed_timestamp;
        tv->tv_usec = 0;
    }
    
    /* Timezone parameter is void* on modern systems (deprecated) */
    (void)tzp;  /* Unused */
    
    return 0;
}

/**
 * Override clock_gettime() with fixed timestamp
 */
int clock_gettime(clockid_t clk_id, struct timespec *tp) {
    if (!initialized)
        initialize_shim();
    
    (void)clk_id;  /* Unused - return fixed time for all clocks */
    
    /* For most clocks, return fixed timestamp */
    if (tp) {
        tp->tv_sec = fixed_timestamp;
        tp->tv_nsec = 0;
    }
    
    return 0;
}

/**
 * Override random() with deterministic PRNG
 */
long random(void) {
    if (!initialized)
        initialize_shim();
    
    return (long)detshim_prng();
}

/**
 * Override rand() with deterministic PRNG
 */
int rand(void) {
    if (!initialized)
        initialize_shim();
    
    return (int)(detshim_prng() % RAND_MAX);
}

/**
 * Override arc4random() with deterministic PRNG (macOS/BSD)
 */
#if defined(__APPLE__) || defined(__FreeBSD__)
uint32_t arc4random(void) {
    if (!initialized)
        initialize_shim();
    
    return (uint32_t)detshim_prng();
}
#endif

/**
 * Override getpid() with fixed PID for deterministic output
 * Some tools embed PID in temporary file names or debug info
 */
pid_t getpid(void) {
    return 12345; /* Fixed deterministic PID */
}

/**
 * Override srand() to prevent re-seeding
 */
void srand(unsigned int seed) {
    /* Ignore attempts to re-seed */
    (void)seed;
    
    #ifdef DETSHIM_DEBUG
    fprintf(stderr, "[detshim] Ignored srand(%u) call\n", seed);
    #endif
}

/**
 * Override srandom() to prevent re-seeding
 */
void srandom(unsigned int seed) {
    /* Ignore attempts to re-seed */
    (void)seed;
    
    #ifdef DETSHIM_DEBUG
    fprintf(stderr, "[detshim] Ignored srandom(%u) call\n", seed);
    #endif
}

/* ========================================================================
 * Library Constructor/Destructor
 * ======================================================================== */

/**
 * Constructor: Called when library is loaded
 */
__attribute__((constructor))
static void detshim_init(void) {
    initialize_shim();
}

/**
 * Destructor: Called when library is unloaded
 */
__attribute__((destructor))
static void detshim_fini(void) {
    #ifdef DETSHIM_DEBUG
    fprintf(stderr, "[detshim] Finalizing determinism shim\n");
    #endif
}

