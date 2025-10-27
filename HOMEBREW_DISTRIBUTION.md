# Homebrew Distribution Guide

## ✅ Completed Steps

- [x] Added version 1.0.0 to `dub.json`
- [x] Added `--version` flag and `version` command to CLI
- [x] Created Homebrew formula at `Formula/builder.rb`
- [x] Committed changes and pushed to GitHub
- [x] Created and pushed git tag `v1.0.0`
- [x] Updated formula with correct SHA256 hash

## 🎉 Your Release is Live!

Your v1.0.0 tag is now on GitHub: https://github.com/GriffinCanCode/Builder/releases/tag/v1.0.0

## 📦 Next Steps for Homebrew Distribution

### Option 1: Personal Tap (Easiest - Recommended to Start)

Create a personal Homebrew tap that users can easily install from:

1. **Create a new GitHub repository** named `homebrew-builder`:
   ```bash
   # On GitHub, create a new repo: GriffinCanCode/homebrew-builder
   ```

2. **Push your formula to the tap**:
   ```bash
   # Clone the new tap repo
   git clone https://github.com/GriffinCanCode/homebrew-builder.git
   cd homebrew-builder
   
   # Copy your formula
   cp /Users/griffinstrier/projects/Builder/Formula/builder.rb Formula/builder.rb
   
   # Commit and push
   git add Formula/builder.rb
   git commit -m "Add Builder formula v1.0.0"
   git push origin main
   ```

3. **Users can now install via**:
   ```bash
   brew tap griffincancode/builder
   brew install builder
   ```

### Option 2: Submit to Official Homebrew (More Visibility)

To get into the official Homebrew repository:

1. **Test your formula locally first**:
   ```bash
   # Install from your local formula
   brew install --build-from-source /Users/griffinstrier/projects/Builder/Formula/builder.rb
   
   # Test it works
   builder --version
   builder --help
   
   # Audit the formula
   brew audit --strict --online builder
   ```

2. **Submit to homebrew-core**:
   ```bash
   # Fork homebrew-core on GitHub first
   cd $(brew --repo homebrew/core)
   git checkout -b builder
   
   # Copy your formula
   cp /Users/griffinstrier/projects/Builder/Formula/builder.rb Formula/builder.rb
   
   # Commit
   git add Formula/builder.rb
   git commit -m "builder 1.0.0 (new formula)
   
   High-performance build system for mixed-language monorepos with BLAKE3 hashing and SIMD acceleration."
   
   # Push to your fork and create PR
   git push YOUR_FORK builder
   ```

3. **Create a Pull Request** to `homebrew-core` with:
   - Clear description of what Builder does
   - Why it should be in Homebrew
   - Link to your GitHub repo
   - Mention that all tests pass

### Option 3: Quick Test (Testing Only)

Test installation directly from your repo:

```bash
# Install directly from GitHub
brew install https://raw.githubusercontent.com/GriffinCanCode/Builder/master/Formula/builder.rb
```

## 📋 Pre-submission Checklist for Official Homebrew

Before submitting to homebrew-core, ensure:

- [ ] Formula passes `brew audit --strict --online`
- [ ] Formula builds from source: `brew install --build-from-source builder`
- [ ] Binary works: `builder --version` and `builder --help`
- [ ] Tests pass: `brew test builder`
- [ ] License is clear and compatible (your GRIFFIN license is similar to MIT/BSD)
- [ ] Project has good documentation (✅ you have this)
- [ ] Project is stable and maintained (✅ you have this)
- [ ] Formula follows Homebrew naming conventions (✅ lowercase, no .rb in name)

## 🔧 Maintaining Your Formula

When releasing new versions:

1. **Create a new release**:
   ```bash
   git tag -a v1.0.1 -m "Release v1.0.1"
   git push origin v1.0.1
   ```

2. **Update the formula**:
   ```bash
   # Download the new tarball
   curl -L https://github.com/GriffinCanCode/Builder/archive/refs/tags/v1.0.1.tar.gz -o /tmp/builder.tar.gz
   
   # Get new SHA256
   shasum -a 256 /tmp/builder.tar.gz
   
   # Update Formula/builder.rb with new URL and SHA256
   # Update version if using bottle
   ```

3. **Push the update**:
   ```bash
   git add Formula/builder.rb
   git commit -m "builder 1.0.1"
   git push
   ```

## 📝 Current Formula Contents

Your formula is located at: `Formula/builder.rb`

```ruby
class Builder < Formula
  desc "High-performance build system for mixed-language monorepos"
  homepage "https://github.com/GriffinCanCode/Builder"
  url "https://github.com/GriffinCanCode/Builder/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "af2b22cb21964dc884d4e69e3b34d34aa7526abc83c7dd4bfbdd3175dbb14866"
  license "GRIFFIN"
  head "https://github.com/GriffinCanCode/Builder.git", branch: "master"

  depends_on "ldc" => :build
  depends_on "dub" => :build

  def install
    # Compile C dependencies
    system "mkdir", "-p", "bin/obj"
    system ENV.cc, "-c", "-O3", "-fPIC", "source/utils/crypto/c/blake3.c", "-o", "bin/obj/blake3.o"
    system ENV.cc, "-c", "-O3", "-fPIC", "source/utils/simd/c/cpu_detect.c", "-o", "bin/obj/cpu_detect.o"
    system ENV.cc, "-c", "-O3", "-fPIC", "source/utils/simd/c/blake3_dispatch.c", "-o", "bin/obj/blake3_dispatch.o"
    system ENV.cc, "-c", "-O3", "-fPIC", "source/utils/simd/c/simd_ops.c", "-o", "bin/obj/simd_ops.o"

    # Build with dub
    system "dub", "build", "--build=release", "--compiler=ldc2"

    # Install binary
    bin.install "bin/builder"
  end

  test do
    # Test that the binary runs and shows version/help
    system "#{bin}/builder", "--help"
  end
end
```

## 🚀 Recommended Next Steps

1. **Start with a personal tap** - This gives you full control and lets users install easily
2. **Gather feedback** - Let some users try it from your tap
3. **Polish based on feedback** - Fix any installation issues
4. **Submit to official Homebrew** - Once stable and tested

## 📚 Additional Resources

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae)
- [Creating Taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew Ruby API](https://rubydoc.brew.sh/Formula)

## ✨ You're Ready!

Your project is now ready for Homebrew distribution. Choose the option that works best for you:

- **Quick Start**: Personal tap (recommended)
- **Maximum Reach**: Official homebrew-core submission
- **Quick Test**: Direct installation from GitHub

Good luck with your distribution! 🎉

