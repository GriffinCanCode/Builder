module infrastructure.config.scripting;

/// Tier 1 Programmability System
/// 
/// This package provides the complete Tier 1 scripting system for Builder:
/// - Variable declarations (let, const)
/// - Function definitions
/// - Control flow (if, for)
/// - Expressions with operators
/// - Built-in functions
/// - Macro expansion

public import infrastructure.config.scripting.types;
public import infrastructure.config.scripting.evaluator;
public import infrastructure.config.scripting.builtins;
public import infrastructure.config.scripting.scopemanager;
public import infrastructure.config.scripting.expander;
public import infrastructure.config.scripting.interpreter;
