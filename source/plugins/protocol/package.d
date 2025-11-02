module plugins.protocol;

/// JSON-RPC 2.0 Protocol for Plugin Communication
/// 
/// This module provides types and encoding/decoding for JSON-RPC 2.0
/// protocol used for Builder plugin communication. Plugins communicate
/// with Builder via stdin/stdout using JSON-RPC messages.
/// 
/// Key Components:
///   - RPCRequest/RPCResponse: Core message types
///   - RPCError: Standard error codes and messages
///   - RPCCodec: Encoding/decoding utilities
///   - PluginInfo: Plugin metadata structure
///   - PluginTarget: Build target information
///   - HookResult: Build hook results
/// 
/// Example:
///   // Create info request
///   auto req = RPCCodec.infoRequest(1);
///   auto json = RPCCodec.encodeRequest(req);
///   
///   // Decode response
///   auto result = RPCCodec.decodeResponse(responseJson);
///   if (result.isOk) {
///       auto resp = result.unwrap();
///       if (resp.isSuccess) {
///           auto info = PluginInfo.fromJSON(resp.result);
///       }
///   }

public import plugins.protocol.types;
public import plugins.protocol.codec;

