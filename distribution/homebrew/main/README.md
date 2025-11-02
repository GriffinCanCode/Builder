# Builder - Main Homebrew Formula

This directory contains the official Homebrew formula for installing Builder.

## Formula: builder.rb

The main formula for installing the Builder build system.

### Dependencies

- **Build dependencies**:
  - `ldc` - LLVM-based D compiler
  - `dub` - D package manager

### Installation Process

The formula:
1. Compiles C dependencies (BLAKE3, SIMD operations)
2. Builds the D source with `dub build --build=release`
3. Installs the binary to Homebrew's bin directory

### Usage

#### For Users

If this formula is published in a tap:
```bash
brew tap builder/builder
brew install builder
```

Or if submitted to Homebrew core:
```bash
brew install builder
```

#### For Development/Testing

Test the formula locally:
```bash
brew install --build-from-source ./builder.rb
brew test builder
```

Audit the formula:
```bash
brew audit --strict --online ./builder.rb
```

### Updating the Formula

When releasing a new version:

1. Update the version tag in the `url` field:
   ```ruby
   url "https://github.com/GriffinCanCode/Builder/archive/refs/tags/vX.Y.Z.tar.gz"
   ```

2. Calculate the new SHA256:
   ```bash
   curl -L https://github.com/GriffinCanCode/Builder/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```

3. Update the `sha256` field with the new hash

4. Test the formula locally before publishing

### Testing

The formula includes a test that verifies:
- The `builder` binary is installed correctly
- It can execute and display help information

### Notes

- The formula uses `ldc2` (LLVM D compiler) for better optimization
- All C dependencies are compiled with `-O3` optimization
- The binary is installed to the standard Homebrew bin location

## Publishing to Homebrew

### Option 1: Custom Tap (Recommended)

Create a tap repository:
```bash
# Create repository: homebrew-builder
# Add this formula to Formula/builder.rb
# Users can then:
brew tap builder/builder
brew install builder
```

### Option 2: Homebrew Core

To submit to Homebrew core:
1. Ensure the formula passes all audits
2. Verify the project meets Homebrew's acceptance criteria
3. Submit a PR to [Homebrew/homebrew-core](https://github.com/Homebrew/homebrew-core)

## Support

For issues with the Homebrew formula:
- [Builder Issues](https://github.com/GriffinCanCode/Builder/issues)
- [Builder Documentation](https://github.com/GriffinCanCode/Builder/tree/master/docs)

