module infrastructure.plugins.sdk;

/// Plugin SDK Module
/// 
/// Provides templates and utilities for plugin authors.
/// 
/// Key Components:
///   - TemplateGenerator: Creates plugin templates in various languages
/// 
/// Example:
///   auto result = TemplateGenerator.create("myplugin", TemplateLanguage.D);
///   if (result.isOk) {
///       writeln("Plugin template created");
///   }

public import infrastructure.plugins.sdk.templates;

