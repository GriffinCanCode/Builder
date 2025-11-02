module config.scripting;

/// Tier 1 Programmability System
/// 
/// This package provides the complete Tier 1 scripting system for Builder:
/// - Variable declarations (let, const)
/// - Function definitions
/// - Control flow (if, for)
/// - Expressions with operators
/// - Built-in functions
/// - Macro expansion

public import config.scripting.types;
public import config.scripting.evaluator;
public import config.scripting.builtins;
public import config.scripting.scopemanager;
public import config.scripting.expander;
public import config.scripting.interpreter;
