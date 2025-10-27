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

