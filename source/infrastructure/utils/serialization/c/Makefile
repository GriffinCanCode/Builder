# Builder Serialization Library Makefile
# High-performance serialization with SIMD acceleration

CC = gcc
CFLAGS = -O3 -Wall -Wextra -std=c11 -fPIC -DNDEBUG
AR = ar
ARFLAGS = rcs

# Detect platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Platform-specific settings
ifeq ($(UNAME_S),Darwin)
    LIB_NAME = libserialization.a
else ifeq ($(UNAME_S),Linux)
    LIB_NAME = libserialization.a
else
    LIB_NAME = serialization.lib
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
SOURCES = varint.c memops.c

# x86/x64 SIMD optimizations
ifeq ($(ARCH_X86),1)
    CFLAGS += -msse4.1 -mavx2
endif

# ARM SIMD optimizations
ifeq ($(ARCH_ARM),1)
    CFLAGS += -march=armv8-a+simd
endif

OBJECTS = $(SOURCES:.c=.o)

# Build targets
all: $(LIB_NAME)

$(LIB_NAME): $(OBJECTS)
	$(AR) $(ARFLAGS) $@ $^
	@echo "Built $@ successfully for $(UNAME_S) $(UNAME_M)"

varint.o: varint.c varint.h
	$(CC) $(CFLAGS) -I../simd/c -c $< -o $@

memops.o: memops.c memops.h
	$(CC) $(CFLAGS) -I../simd/c -c $< -o $@

# Optimized build with -march=native
optimized:
	$(MAKE) clean
	$(MAKE) CFLAGS="$(CFLAGS) -march=native -mtune=native" all

# Debug build
debug:
	$(MAKE) clean
	$(MAKE) CFLAGS="-g -O0 -Wall -Wextra -std=c11 -fPIC -I../simd/c" all

# Clean
clean:
	rm -f $(OBJECTS) $(LIB_NAME)
	@echo "Cleaned build artifacts"

# Test
test:
	@echo "Architecture: $(UNAME_M)"
	@echo "X86: $(ARCH_X86)"
	@echo "ARM: $(ARCH_ARM)"
	@echo "Sources: $(SOURCES)"

.PHONY: all optimized debug clean test

