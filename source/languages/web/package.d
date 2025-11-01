module languages.web;

/// Web Languages Package
/// 
/// Unified support for web development languages and technologies including:
///   - JavaScript (Node.js, browser bundling, npm/yarn/pnpm/bun)
///   - TypeScript (type-first, multiple compilers, declaration generation)
///   - CSS (pure CSS, SCSS, PostCSS, Tailwind, minification)
///   - Elm (functional programming, compiles to JavaScript)
///
/// All web languages share common infrastructure for:
///   - Package managers (npm, yarn, pnpm, bun)
///   - Module resolution
///   - Build orchestration
///   - Framework detection (React, Vue, Angular, etc.)

public import languages.web.javascript;
public import languages.web.typescript;
public import languages.web.css;
public import languages.web.elm;
public import languages.web.shared_;

