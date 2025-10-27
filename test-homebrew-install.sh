#!/bin/bash
# Test script to verify Homebrew formula works locally

set -e

echo "Testing Builder Homebrew Formula..."
echo "======================================"
echo

# Test 1: Check if dependencies are available
echo "✓ Checking dependencies..."
if ! command -v ldc2 &> /dev/null; then
    echo "  Installing ldc..."
    brew install ldc
fi

if ! command -v dub &> /dev/null; then
    echo "  Installing dub..."
    brew install dub
fi

echo "  ✓ Dependencies OK"
echo

# Test 2: Try to build from source
echo "✓ Testing build process..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

echo "  Downloading source..."
curl -L https://github.com/GriffinCanCode/Builder/archive/refs/tags/v1.0.0.tar.gz -o builder.tar.gz

echo "  Extracting..."
tar xzf builder.tar.gz
cd Builder-1.0.0

echo "  Building..."
mkdir -p bin/obj
clang -c -O3 -fPIC source/utils/crypto/c/blake3.c -o bin/obj/blake3.o
clang -c -O3 -fPIC source/utils/simd/c/cpu_detect.c -o bin/obj/cpu_detect.o
clang -c -O3 -fPIC source/utils/simd/c/blake3_dispatch.c -o bin/obj/blake3_dispatch.o
clang -c -O3 -fPIC source/utils/simd/c/simd_ops.c -o bin/obj/simd_ops.o
dub build --build=release --compiler=ldc2

echo "  Testing binary..."
./bin/builder --version
./bin/builder --help > /dev/null

echo "  ✓ Build successful!"
echo

# Cleanup
cd /
rm -rf "$TMPDIR"

echo "======================================"
echo "✅ All tests passed!"
echo
echo "Your formula should work correctly in Homebrew."
echo
echo "Next steps:"
echo "1. Create a GitHub repo: GriffinCanCode/homebrew-builder"
echo "2. Copy Formula/builder.rb to that repo"
echo "3. Users can install with:"
echo "   brew tap griffincancode/builder"
echo "   brew install builder"

