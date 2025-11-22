class Builder < Formula
  desc "High-performance build system for mixed-language monorepos"
  homepage "https://github.com/GriffinCanCode/Builder"
  url "https://github.com/GriffinCanCode/Builder/archive/refs/tags/v1.0.6.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/GriffinCanCode/Builder.git", branch: "master"

  depends_on "ldc" => :build
  depends_on "dub" => :build

  def install
    # Build using Makefile which handles C dependencies
    system "make", "build"

    # Install binaries
    bin.install "bin/builder"
    
    # Optionally install LSP server if built
    bin.install "bin/builder-lsp" if File.exist?("bin/builder-lsp")
  end

  test do
    # Test that the binary runs and shows correct version
    assert_match "Builder version 1.0.6", shell_output("#{bin}/builder --version")
    
    # Test help command
    system "#{bin}/builder", "--help"
  end
end

