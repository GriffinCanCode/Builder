module languages.compiled.ocaml;

/// OCaml Language Support
/// Provides compilation support for OCaml with multiple build systems
/// 
/// Features:
/// - dune build system support (modern OCaml builds)
/// - ocamlopt (native code compiler)
/// - ocamlc (bytecode compiler)
/// - ocamlbuild support
/// - opam integration for dependencies
/// - ocamlformat integration
/// 
/// Usage:
///   import languages.compiled.ocaml;
///   
///   auto handler = new OCamlHandler();
///   handler.build(target, config);

public import languages.compiled.ocaml.core;
public import languages.compiled.ocaml.tooling;
public import languages.compiled.ocaml.analysis;


