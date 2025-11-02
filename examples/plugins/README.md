# Builder Plugin Examples

This directory contains example plugins demonstrating various Builder plugin capabilities.

## Demo Plugin

The `builder-plugin-demo` is a simple Python plugin showing:

- JSON-RPC 2.0 protocol implementation
- Pre-build and post-build hooks
- Plugin metadata
- Logging and output

### Test the Demo Plugin

```bash
# Make executable
chmod +x builder-plugin-demo

# Test info request
echo '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}' | ./builder-plugin-demo

# Test pre-hook
echo '{"jsonrpc":"2.0","id":2,"method":"build.pre_hook","params":{"target":{"name":"//app:main","type":"executable","language":"python"}}}' | ./builder-plugin-demo

# Test post-hook
echo '{"jsonrpc":"2.0","id":3,"method":"build.post_hook","params":{"target":{"name":"//app:main"},"success":true,"duration_ms":1234,"outputs":["bin/app"]}}' | ./builder-plugin-demo
```

### Install Locally

```bash
# Copy to PATH
sudo cp builder-plugin-demo /usr/local/bin/
sudo chmod +x /usr/local/bin/builder-plugin-demo

# Verify installation
builder plugin list
builder plugin info demo
```

## Creating Your Own Plugin

### 1. Use the Template Generator

```bash
builder plugin create myplugin --language=python
cd builder-plugin-myplugin
```

### 2. Implement the Handlers

Edit the generated file and implement:

- `plugin.info` - Return plugin metadata
- `build.pre_hook` - Pre-build logic (optional)
- `build.post_hook` - Post-build logic (optional)

### 3. Test Your Plugin

```bash
chmod +x builder-plugin-myplugin

# Test info
echo '{"jsonrpc":"2.0","id":1,"method":"plugin.info"}' | ./builder-plugin-myplugin

# Validate
builder plugin validate myplugin
```

### 4. Create Homebrew Formula

See `homebrew-plugins/README.md` for formula guidelines.

## Plugin Ideas

- **Docker Integration**: Build and push Docker images
- **SonarQube**: Code quality and security scanning
- **Slack/Discord**: Build notifications
- **AWS S3**: Artifact upload
- **Grafana**: Metrics and monitoring
- **GitHub Actions**: CI/CD integration
- **Terraform**: Infrastructure deployment
- **Kubernetes**: Deploy to clusters
- **Code Signing**: Sign binaries
- **Documentation**: Generate docs from builds

## Resources

- [Plugin Architecture Documentation](../../docs/architecture/PLUGINS.md)
- [Homebrew Tap](../../homebrew-plugins/)
- [Builder Documentation](../../docs/)

## License

Example plugins are licensed under MIT.

