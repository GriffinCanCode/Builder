module languages.compiled.protobuf;

/// Protocol Buffer Support
/// Provides compilation support for .proto files using protoc or buf
/// 
/// Features:
/// - Generate code for multiple target languages (C++, Java, Python, Go, etc.)
/// - Support for protoc compiler and Buf CLI
/// - Import path management
/// - Plugin support for language-specific code generation
/// - Descriptor set generation
/// - Optional linting and formatting with buf
/// 
/// Usage:
///   import languages.compiled.protobuf;
///   
///   auto handler = new ProtobufHandler();
///   handler.build(target, config);

public import languages.compiled.protobuf.core;
public import languages.compiled.protobuf.tooling;
public import languages.compiled.protobuf.analysis;

