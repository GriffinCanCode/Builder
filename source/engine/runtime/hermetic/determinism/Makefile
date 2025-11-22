# Makefile for Determinism Shim Library

CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC -shared
LDFLAGS = -ldl

# Platform detection
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
    TARGET = libdetshim.so
    CFLAGS += -D_GNU_SOURCE
endif
ifeq ($(UNAME_S),Darwin)
    TARGET = libdetshim.dylib
    LDFLAGS += -undefined dynamic_lookup
endif

# Debug build
ifdef DEBUG
    CFLAGS += -g -DDETSHIM_DEBUG
endif

# Targets
all: $(TARGET)

$(TARGET): shim.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	@echo "Built determinism shim library: $(TARGET)"

install: $(TARGET)
	mkdir -p ../../../../bin
	cp $(TARGET) ../../../../bin/
	@echo "Installed $(TARGET) to bin/"

clean:
	rm -f $(TARGET) *.o

test: $(TARGET)
	@echo "Testing determinism shim..."
	@echo "int main() { return 0; }" > test.c
	gcc test.c -o test
	@echo "Running without shim:"
	./test
	@echo "Running with shim:"
	LD_PRELOAD=./$(TARGET) BUILD_TIMESTAMP=1640995200 RANDOM_SEED=42 ./test
	rm -f test test.c
	@echo "✓ Test passed"

.PHONY: all install clean test

