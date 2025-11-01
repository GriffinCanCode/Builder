module languages.web.elm;

/// Elm Language Support
/// 
/// Provides build support for Elm - a delightful language for reliable webapps
/// 
/// Features:
///   - elm make compilation
///   - Debug and optimized builds
///   - elm-test integration
///   - elm-format support
///   - elm-review integration
///   - Documentation generation
///   - JavaScript and HTML output
///
/// Usage:
///   target("my-app") {
///     type: executable;
///     language: elm;
///     sources: ["src/Main.elm"];
///     
///     elmConfig: {
///       optimize: true;
///       outputTarget: "html";
///     };
///   }

public import languages.web.elm.core;

