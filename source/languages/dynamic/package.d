module languages.dynamic;

/// Dynamic Language Support System
/// 
/// Enables zero-code language addition through declarative specifications.
/// Instead of writing 150 lines of D code per language, users define
/// languages via JSON/TOML files with command templates.
/// 
/// Benefits:
/// - User-extensible without recompiling Builder
/// - Portable specifications (share across projects)  
/// - Auto-generation of handlers from spec
/// - Community contributions without D knowledge
/// 
/// Usage:
///   auto registry = new SpecRegistry();
///   registry.loadAll();
///   
///   auto spec = registry.get("crystal");
///   if (spec !is null) {
///       auto handler = new SpecBasedHandler(*spec);
///       // Use handler like any other LanguageHandler
///   }
/// 
/// Spec Format Example:
///   {
///     "language": {
///       "name": "crystal",
///       "display": "Crystal",
///       "category": "compiled",
///       "extensions": [".cr"],
///       "aliases": ["cr"]
///     },
///     "build": {
///       "compiler": "crystal",
///       "compile_cmd": "crystal build {{sources}} -o {{output}} {{flags}}",
///       "test_cmd": "crystal spec {{sources}}"
///     },
///     "dependencies": {
///       "pattern": "require \"([^\"]+)\"",
///       "manifest": "shard.yml",
///       "install_cmd": "shards install"
///     }
///   }

public import languages.dynamic.spec;
public import languages.dynamic.handler;

