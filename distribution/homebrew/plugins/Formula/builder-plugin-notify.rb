class BuilderPluginNotify < Formula
  desc "Smart build notifications for Builder (Slack, Discord, Email)"
  homepage "https://github.com/GriffinCanCode/Builder"
  url "https://github.com/GriffinCanCode/Builder/archive/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/GriffinCanCode/Builder.git", branch: "master"

  depends_on "builder"
  depends_on "python@3.11"

  def install
    # Install the plugin
    bin.install "examples/plugins/builder-plugin-notify"
  end

  test do
    # Test that plugin responds to info request
    output = pipe_output("#{bin}/builder-plugin-notify", 
      '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}')
    
    assert_match "notify", output
    assert_match "version", output
    assert_match "notification", output
  end
end

