# Builder SIMD Library Makefile
# Compiles SIMD-accelerated code for multiple architectures

CC = gcc
CFLAGS = -O3 -Wall -Wextra -std=c11 -fPIC -DNDEBUG
AR = ar
ARFLAGS = rcs

# Detect platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Platform-specific settings
ifeq ($(UNAME_S),Darwin)
    LIB_NAME = libsimd.a
    INSTALL_DIR = /usr/local/lib
else ifeq ($(UNAME_S),Linux)
    LIB_NAME = libsimd.a
    INSTALL_DIR = /usr/local/lib
else
    LIB_NAME = simd.lib
    INSTALL_DIR = C:/lib
endif

# Architecture detection
ARCH_X86 = 0
ARCH_ARM = 0

ifeq ($(UNAME_M),x86_64)
    ARCH_X86 = 1
else ifeq ($(UNAME_M),amd64)
    ARCH_X86 = 1
else ifeq ($(UNAME_M),arm64)
    ARCH_ARM = 1
else ifeq ($(UNAME_M),aarch64)
    ARCH_ARM = 1
endif

# Source files
SOURCES = cpu_detect.c blake3_dispatch.c simd_ops.c

# x86/x64 SIMD sources
ifeq ($(ARCH_X86),1)
    SIMD_SOURCES = blake3_sse2.c blake3_sse41.c blake3_avx2.c blake3_avx512.c
    SIMD_FLAGS_SSE2 = -msse2
    SIMD_FLAGS_SSE41 = -msse4.1
    SIMD_FLAGS_AVX2 = -mavx2
    SIMD_FLAGS_AVX512 = -mavx512f -mavx512vl
endif

# ARM SIMD sources
ifeq ($(ARCH_ARM),1)
    SIMD_SOURCES = blake3_neon.c
    SIMD_FLAGS_NEON = -march=armv8-a+simd
endif

# All sources
ALL_SOURCES = $(SOURCES) $(SIMD_SOURCES)
OBJECTS = $(ALL_SOURCES:.c=.o)

# Build targets
all: $(LIB_NAME)

$(LIB_NAME): $(OBJECTS)
	$(AR) $(ARFLAGS) $@ $^
	@echo "Built $@ successfully for $(UNAME_S) $(UNAME_M)"

# Generic compilation
cpu_detect.o: cpu_detect.c cpu_detect.h
	$(CC) $(CFLAGS) -c $< -o $@

blake3_dispatch.o: blake3_dispatch.c blake3_simd.h cpu_detect.h
	$(CC) $(CFLAGS) -c $< -o $@

simd_ops.o: simd_ops.c simd_ops.h cpu_detect.h
	$(CC) $(CFLAGS) -c $< -o $@

# x86 SIMD-specific compilation
ifeq ($(ARCH_X86),1)
blake3_sse2.o: blake3_sse2.c blake3_simd.h
	$(CC) $(CFLAGS) $(SIMD_FLAGS_SSE2) -c $< -o $@

blake3_sse41.o: blake3_sse41.c blake3_simd.h
	$(CC) $(CFLAGS) $(SIMD_FLAGS_SSE41) -c $< -o $@

blake3_avx2.o: blake3_avx2.c blake3_simd.h
	$(CC) $(CFLAGS) $(SIMD_FLAGS_AVX2) -c $< -o $@

blake3_avx512.o: blake3_avx512.c blake3_simd.h
	$(CC) $(CFLAGS) $(SIMD_FLAGS_AVX512) -c $< -o $@
endif

# ARM SIMD-specific compilation
ifeq ($(ARCH_ARM),1)
blake3_neon.o: blake3_neon.c blake3_simd.h
	$(CC) $(CFLAGS) $(SIMD_FLAGS_NEON) -c $< -o $@
endif

# Optimized build with -march=native
optimized:
	$(MAKE) clean
	$(MAKE) CFLAGS="$(CFLAGS) -march=native -mtune=native" all

# Debug build
debug:
	$(MAKE) clean
	$(MAKE) CFLAGS="-g -O0 -Wall -Wextra -std=c11 -fPIC" all

# Clean
clean:
	rm -f $(OBJECTS) $(LIB_NAME)
	@echo "Cleaned build artifacts"

# Install
install: $(LIB_NAME)
	mkdir -p $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)/../include/builder
	cp $(LIB_NAME) $(INSTALL_DIR)/
	cp *.h $(INSTALL_DIR)/../include/builder/
	@echo "Installed $(LIB_NAME) to $(INSTALL_DIR)"

# Uninstall
uninstall:
	rm -f $(INSTALL_DIR)/$(LIB_NAME)
	rm -rf $(INSTALL_DIR)/../include/builder
	@echo "Uninstalled SIMD library"

# Test compilation
test:
	@echo "Architecture: $(UNAME_M)"
	@echo "X86: $(ARCH_X86)"
	@echo "ARM: $(ARCH_ARM)"
	@echo "SIMD Sources: $(SIMD_SOURCES)"

.PHONY: all optimized debug clean install uninstall test

