# Builder Release Checklist

Comprehensive checklist for releasing new versions of Builder and related artifacts.

## Pre-Release

### Version Planning

- [ ] Review changes since last release
- [ ] Determine version number (MAJOR.MINOR.PATCH)
  - [ ] MAJOR: Breaking changes
  - [ ] MINOR: New features (backward compatible)
  - [ ] PATCH: Bug fixes
- [ ] Update CHANGELOG.md with all changes
- [ ] Review and close related GitHub issues
- [ ] Update version in all package files

### Version Files to Update

- [ ] `dub.json` - Main version field
- [ ] `source/app.d` - Version constant
- [ ] `tools/vscode/builder-lang/package.json` - VSCode extension version
- [ ] `Formula/builder.rb` - Homebrew formula URL and SHA256
- [ ] `README.md` - Version badges/references
- [ ] Documentation - Version-specific references

### Code Quality

- [ ] All tests passing locally
  ```bash
  dub test
  ./tests/run-tests.sh
  ```
- [ ] Run integration tests
  ```bash
  ./tests/test-real-world.sh
  ```
- [ ] Run benchmarks to detect regressions
  ```bash
  cd tests/bench
  ./run-benchmarks.sh
  ```
- [ ] Lint and format code
- [ ] No compiler warnings
- [ ] Memory safety checks passing
  ```bash
  ./tools/audit-safety.sh
  ```
- [ ] Code coverage > 80%

### Documentation

- [ ] Update documentation for new features
- [ ] Update CLI help text if commands changed
- [ ] Add examples for new functionality
- [ ] Update API documentation
- [ ] Generate documentation
  ```bash
  ./tools/generate-docs.sh
  ```
- [ ] Review and fix broken links

## Build Artifacts

### Core Builder Binary

- [ ] Build release binary (macOS ARM64)
  ```bash
  dub build --build=release --compiler=ldc2
  ```
- [ ] Test binary works
  ```bash
  ./bin/builder --version
  ./bin/builder build
  ```
- [ ] Run examples with release binary
  ```bash
  cd examples
  ./run-all-examples.sh
  ```

### LSP Server Binaries

Build for all platforms:

- [ ] macOS ARM64 (Apple Silicon)
  ```bash
  dub build :lsp --build=release --compiler=ldc2 --arch=arm64-apple-macos
  cp bin/builder-lsp distribution/lsp/binaries/builder-lsp-darwin-arm64
  ```
- [ ] macOS x86_64 (Intel)
  ```bash
  dub build :lsp --build=release --compiler=ldc2 --arch=x86_64-apple-macos
  cp bin/builder-lsp distribution/lsp/binaries/builder-lsp-darwin-x86_64
  ```
- [ ] Linux x86_64
  ```bash
  dub build :lsp --build=release --compiler=ldc2 --arch=x86_64-linux-gnu
  cp bin/builder-lsp distribution/lsp/binaries/builder-lsp-linux-x86_64
  ```
- [ ] Linux ARM64
  ```bash
  dub build :lsp --build=release --compiler=ldc2 --arch=aarch64-linux-gnu
  cp bin/builder-lsp distribution/lsp/binaries/builder-lsp-linux-aarch64
  ```
- [ ] Windows x86_64
  ```bash
  dub build :lsp --build=release --compiler=ldc2 --arch=x86_64-windows-msvc
  cp bin/builder-lsp.exe distribution/lsp/binaries/builder-lsp-windows-x86_64.exe
  ```

Or use script:
```bash
./tools/build-lsp-binaries.sh
```

- [ ] Test each LSP binary
  ```bash
  ./distribution/lsp/binaries/builder-lsp-darwin-arm64 --version
  ```
- [ ] Generate SHA256 checksums
  ```bash
  cd distribution/lsp/binaries
  shasum -a 256 * > SHA256SUMS
  ```

### VSCode Extension

- [ ] Update extension version
  ```bash
  cd tools/vscode/builder-lang
  # Update version in package.json
  ```
- [ ] Update CHANGELOG in extension
- [ ] Build extension
  ```bash
  cd tools/vscode/builder-lang
  npm install
  vsce package
  ```
- [ ] Test extension locally
  ```bash
  code --install-extension builder-lang-X.Y.Z.vsix
  # Test in VS Code with a Builder project
  ```
- [ ] Copy to distribution
  ```bash
  cp tools/vscode/builder-lang/builder-lang-X.Y.Z.vsix distribution/editors/vscode/
  ```

### Homebrew Formulas

- [ ] Update main formula version and SHA256
  ```bash
  # In distribution/homebrew/main/builder.rb
  # Update URL to new tag
  url "https://github.com/GriffinCanCode/Builder/archive/refs/tags/vX.Y.Z.tar.gz"
  # Calculate new SHA256
  curl -L https://github.com/GriffinCanCode/Builder/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
  # Update sha256 field
  ```
- [ ] Test Homebrew formula locally
  ```bash
  brew install --build-from-source distribution/homebrew/main/builder.rb
  brew test builder
  builder --version
  ```
- [ ] Update plugin formulas if needed

## Git and GitHub

### Git Operations

- [ ] Commit all changes
  ```bash
  git add .
  git commit -m "Release vX.Y.Z"
  ```
- [ ] Create and push tag
  ```bash
  git tag -a vX.Y.Z -m "Release vX.Y.Z"
  git push origin master
  git push origin vX.Y.Z
  ```

### GitHub Release

- [ ] Go to GitHub → Releases → Draft a new release
- [ ] Select the vX.Y.Z tag
- [ ] Title: "Builder vX.Y.Z"
- [ ] Copy CHANGELOG entries for this version
- [ ] Mark as pre-release if applicable
- [ ] Attach binaries:
  - [ ] `builder-darwin-arm64`
  - [ ] `builder-darwin-x86_64`
  - [ ] `builder-linux-x86_64`
  - [ ] `builder-linux-aarch64`
  - [ ] `builder-windows-x86_64.exe`
  - [ ] All LSP binaries
  - [ ] `builder-lang-X.Y.Z.vsix`
  - [ ] `SHA256SUMS`
- [ ] Publish release

## Distribution Platforms

### Homebrew Tap

- [ ] Update tap repository with new formula
  ```bash
  # In homebrew-builder repository
  cp distribution/homebrew/main/builder.rb Formula/
  git add Formula/builder.rb
  git commit -m "Update builder to vX.Y.Z"
  git push
  ```
- [ ] Test installation from tap
  ```bash
  brew update
  brew upgrade builder
  builder --version
  ```

### VSCode Marketplace

- [ ] Publish to VS Code Marketplace
  ```bash
  cd tools/vscode/builder-lang
  vsce publish
  ```
- [ ] Verify on marketplace: https://marketplace.visualstudio.com/
- [ ] Test installation from marketplace
  ```bash
  code --install-extension builder.builder-lang
  ```

### Open VSX Registry (for VSCodium)

- [ ] Publish to Open VSX
  ```bash
  npx ovsx publish distribution/editors/vscode/builder-lang-X.Y.Z.vsix -p YOUR_TOKEN
  ```
- [ ] Verify on Open VSX: https://open-vsx.org/

### NPM (when implemented)

- [ ] Publish CLI package
  ```bash
  cd distribution/npm/@builder-cli/builder
  npm publish --access public
  ```
- [ ] Publish LSP package
  ```bash
  cd distribution/npm/@builder-cli/lsp
  npm publish --access public
  ```
- [ ] Verify on npmjs.com

### Package Managers (when implemented)

- [ ] Update Debian package
- [ ] Update RPM package
- [ ] Update AUR (Arch User Repository)
- [ ] Update Chocolatey (Windows)
- [ ] Update Scoop (Windows)

## Post-Release

### Verification

- [ ] Test installation from each distribution method
  - [ ] GitHub release binaries
  - [ ] Homebrew
  - [ ] VSCode marketplace
  - [ ] Open VSX
  - [ ] NPM (when available)
- [ ] Verify downloads work
- [ ] Check GitHub release stats
- [ ] Monitor issue tracker for release-related bugs

### Documentation Updates

- [ ] Update main README with new version
- [ ] Update documentation site (if applicable)
- [ ] Update getting started guides
- [ ] Update example projects

### Communication

- [ ] Write release announcement
- [ ] Post to GitHub Discussions
- [ ] Tweet/social media announcement (if applicable)
- [ ] Update project website (if applicable)
- [ ] Notify major users (if breaking changes)
- [ ] Update Discord/Slack (if applicable)

### Monitoring

- [ ] Monitor GitHub issues for new bugs
- [ ] Watch download/install metrics
- [ ] Check error reporting services
- [ ] Review crash reports
- [ ] Monitor performance metrics

## Hotfix Process

If critical bug found after release:

1. [ ] Create hotfix branch from tag
   ```bash
   git checkout -b hotfix-vX.Y.Z+1 vX.Y.Z
   ```
2. [ ] Fix the bug
3. [ ] Test fix thoroughly
4. [ ] Update version to X.Y.Z+1 (patch increment)
5. [ ] Follow release checklist for patch release
6. [ ] Merge hotfix back to master
   ```bash
   git checkout master
   git merge hotfix-vX.Y.Z+1
   git push
   ```

## Rollback Process

If severe issues found:

1. [ ] Yank bad release from registries where possible
   - [ ] npm: `npm unpublish @builder-cli/builder@X.Y.Z`
   - [ ] GitHub: Mark release as pre-release or delete
2. [ ] Update Homebrew formula to previous version
3. [ ] Post announcement about issue
4. [ ] Fix issues and prepare new release

## Release Frequency

- **Major releases**: Every 6-12 months
- **Minor releases**: Every 1-2 months
- **Patch releases**: As needed for bug fixes
- **Pre-releases**: For testing breaking changes

## Automation Opportunities

Consider automating:
- [ ] Binary builds (GitHub Actions)
- [ ] Cross-platform testing (CI matrix)
- [ ] Changelog generation (from commits)
- [ ] Version bumping (automated script)
- [ ] GitHub release creation (via CLI)
- [ ] Binary checksums (post-build script)
- [ ] Distribution uploads (GitHub Actions)

## Tools and Scripts

Helpful scripts for release process:

```bash
# Build all LSP binaries
./tools/build-lsp-binaries.sh

# Run all tests
./tests/run-tests.sh

# Generate documentation
./tools/generate-docs.sh

# Create GitHub release (with gh CLI)
gh release create vX.Y.Z --title "vX.Y.Z" --notes-file CHANGELOG.md

# Publish VSCode extension
cd tools/vscode/builder-lang && vsce publish
```

## Release Template

Use this template for release notes:

```markdown
# Builder vX.Y.Z

## What's New

- Feature 1
- Feature 2
- Improvement 3

## Bug Fixes

- Fix 1
- Fix 2

## Breaking Changes

- Breaking change 1 (if any)

## Installation

### Homebrew
```bash
brew tap builder/builder
brew install builder
```

### Direct Download
Download for your platform:
- [macOS (Apple Silicon)](link)
- [macOS (Intel)](link)
- [Linux (x86_64)](link)
- [Windows](link)

### VSCode Extension
- [Install from Marketplace](link)
- Or: `code --install-extension builder.builder-lang`

## Full Changelog
See [CHANGELOG.md](link) for complete list of changes.

## Contributors
Thanks to all contributors for this release!
```

## Checklist Summary

Before publishing:
- ✅ All tests passing
- ✅ Documentation updated
- ✅ Binaries built and tested
- ✅ Version numbers updated
- ✅ CHANGELOG updated
- ✅ Git tagged
- ✅ GitHub release created

After publishing:
- ✅ All distribution platforms updated
- ✅ Installation verified
- ✅ Announcement posted
- ✅ Monitoring in place

