# Builder Makefile

.PHONY: all build test clean install help tsan test-tsan

all: build

# Build the project
build:
	@echo "Building Builder..."
	@dub build --build=release

# Build debug version
debug:
	@echo "Building debug version..."
	@dub build --build=debug

# Run tests
test:
	@echo "Running tests..."
	@dub test

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@./run-tests.sh --coverage

# Run tests in parallel
test-parallel:
	@echo "Running tests in parallel..."
	@dub test -- --parallel

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@dub clean
	@rm -rf bin/
	@rm -rf .builder-cache/
	@rm -f *.lst
	@find . -name "*.o" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Install to system
install: build
	@echo "Installing to /usr/local/bin..."
	@cp bin/builder /usr/local/bin/
	@echo "Installed successfully!"

# Uninstall from system
uninstall:
	@echo "Uninstalling..."
	@rm -f /usr/local/bin/builder
	@echo "Uninstalled successfully!"

# Run benchmarks
bench:
	@echo "Running benchmarks..."
	@dub test -- --filter="bench"

# Build with Thread Sanitizer (requires LDC)
tsan:
	@echo "Building with Thread Sanitizer (TSan)..."
	@echo "Note: Requires LDC compiler (use: dub build --compiler=ldc2 --build=tsan)"
	@dub build --compiler=ldc2 --build=tsan

# Run tests with Thread Sanitizer
test-tsan:
	@echo "Running tests with Thread Sanitizer (TSan)..."
	@echo "Note: This will detect data races and threading issues"
	@./tools/run-tsan-tests.sh

# Format code
fmt:
	@echo "Formatting code..."
	@find source tests -name "*.d" -exec dfmt -i {} \;

# Generate documentation
docs:
	@./tools/generate-docs.sh

# Open documentation in browser
docs-open: docs
	@echo "Opening documentation in browser..."
	@open docs/api/index.html || xdg-open docs/api/index.html || sensible-browser docs/api/index.html

# Serve documentation on local web server
docs-serve:
	@echo "Starting documentation server on http://localhost:8000..."
	@echo "Press Ctrl+C to stop"
	@python3 -m http.server --directory docs/api 8000

# Clean documentation
docs-clean:
	@echo "Cleaning documentation..."
	@rm -rf docs/api
	@echo "Documentation cleaned"

# Show help
help:
	@echo "Builder Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build          - Build release version"
	@echo "  make debug          - Build debug version"
	@echo "  make test           - Run tests"
	@echo "  make test-coverage  - Run tests with coverage"
	@echo "  make test-parallel  - Run tests in parallel"
	@echo "  make test-tsan      - Run tests with Thread Sanitizer (requires LDC)"
	@echo "  make tsan           - Build with Thread Sanitizer"
	@echo "  make bench          - Run benchmarks"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make install        - Install to /usr/local/bin"
	@echo "  make uninstall      - Uninstall from system"
	@echo "  make fmt            - Format code"
	@echo "  make docs           - Generate DDoc documentation"
	@echo "  make docs-open      - Generate and open documentation"
	@echo "  make docs-serve     - Serve documentation on localhost:8000"
	@echo "  make docs-clean     - Clean documentation"
	@echo "  make help           - Show this help"

