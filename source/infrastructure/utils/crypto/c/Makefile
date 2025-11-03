# BLAKE3 C Library Makefile
# Compiles BLAKE3 as a static library for linking with D code

CC = gcc
CFLAGS = -O3 -Wall -Wextra -std=c11 -fPIC
AR = ar
ARFLAGS = rcs

# Detect platform
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    # macOS
    LIB_NAME = libblake3.a
    INSTALL_DIR = /usr/local/lib
else ifeq ($(UNAME_S),Linux)
    # Linux
    LIB_NAME = libblake3.a
    INSTALL_DIR = /usr/local/lib
else
    # Windows (MinGW/MSYS)
    LIB_NAME = blake3.lib
    INSTALL_DIR = C:/lib
endif

# Source files
SOURCES = blake3.c
OBJECTS = $(SOURCES:.c=.o)

# Build targets
all: $(LIB_NAME)

$(LIB_NAME): $(OBJECTS)
	$(AR) $(ARFLAGS) $@ $^
	@echo "Built $@ successfully"

%.o: %.c blake3.h blake3_impl.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(LIB_NAME)
	@echo "Cleaned build artifacts"

install: $(LIB_NAME)
	mkdir -p $(INSTALL_DIR)
	cp $(LIB_NAME) $(INSTALL_DIR)/
	cp blake3.h $(INSTALL_DIR)/../include/ || mkdir -p $(INSTALL_DIR)/../include/ && cp blake3.h $(INSTALL_DIR)/../include/
	@echo "Installed $(LIB_NAME) to $(INSTALL_DIR)"

uninstall:
	rm -f $(INSTALL_DIR)/$(LIB_NAME)
	rm -f $(INSTALL_DIR)/../include/blake3.h
	@echo "Uninstalled BLAKE3 library"

# Build optimized version with native CPU features
optimized:
	$(MAKE) CFLAGS="$(CFLAGS) -march=native -mtune=native"

.PHONY: all clean install uninstall optimized

