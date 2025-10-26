module analysis.spec;

import analysis.types;
import config.schema;
import std.regex;
import std.algorithm;
import std.array;
import std.string;

/// Language-specific analysis configuration
struct LanguageSpec
{
    TargetLanguage language;
    string name;
    ImportPattern[] patterns;
    ImportKindDetector kindDetector;
    
    /// Scan a file for imports
    Import[] scanImports(string filePath, string content) const
    {
        Import[] imports;
        size_t lineNumber = 1;
        
        foreach (line; content.lineSplitter)
        {
            foreach (patternItem; patterns)
            {
                auto matches = matchAll(line, patternItem.pattern);
                
                foreach (match; matches)
                {
                    if (match.length > 1)
                    {
                        auto moduleName = match[1].strip();
                        if (!moduleName.empty && !shouldIgnore(moduleName))
                        {
                            imports ~= Import(
                                moduleName,
                                kindDetector(moduleName, filePath),
                                SourceLocation(filePath, lineNumber, 0)
                            );
                        }
                    }
                }
            }
            
            lineNumber++;
        }
        
        return imports;
    }
    
    private bool shouldIgnore(string moduleName) const pure
    {
        // Ignore common stdlib modules that don't need tracking
        static immutable string[] commonStdlib = [
            "std", "core", "system", "builtin"
        ];
        
        return commonStdlib.canFind(moduleName);
    }
}

/// Import pattern with regex
struct ImportPattern
{
    string description;
    Regex!char pattern;
    
    this(string desc, string regexPattern, string flags = "m")
    {
        description = desc;
        this.pattern = std.regex.regex(regexPattern, flags);
    }
}

/// Function type for detecting import kind
alias ImportKindDetector = ImportKind function(string moduleName, string fromFile) pure;

/// Standard import kind detectors

ImportKind detectRelativeImport(string moduleName, string fromFile) pure
{
    if (moduleName.startsWith(".") || moduleName.startsWith("/"))
        return ImportKind.Relative;
    return ImportKind.Absolute;
}

ImportKind detectPythonImportKind(string moduleName, string fromFile) pure
{
    // Relative if starts with "."
    if (moduleName.startsWith("."))
        return ImportKind.Relative;
    
    // External if single component without underscore (usually stdlib/packages)
    auto parts = moduleName.split(".");
    if (parts.length == 1 && !moduleName.canFind("_"))
        return ImportKind.External;
    
    return ImportKind.Absolute;
}

ImportKind detectJavaScriptImportKind(string moduleName, string fromFile) pure
{
    if (moduleName.startsWith("."))
        return ImportKind.Relative;
    if (moduleName.startsWith("/"))
        return ImportKind.Absolute;
    return ImportKind.External; // Node module
}

ImportKind detectGoImportKind(string moduleName, string fromFile) pure
{
    // Go uses URLs for external packages
    if (moduleName.canFind("/"))
        return ImportKind.External;
    return ImportKind.Absolute;
}

ImportKind detectRustImportKind(string moduleName, string fromFile) pure
{
    // Rust uses "crate::" for internal, otherwise external
    if (moduleName.startsWith("crate::") || moduleName.startsWith("super::") || moduleName == "self")
        return ImportKind.Relative;
    return ImportKind.External;
}

/// Compile-time registry of all language specifications
immutable LanguageSpec[TargetLanguage] LanguageSpecs;

/// Initialize language specs at module load
shared static this()
{
    LanguageSpec[TargetLanguage] specs;
    
    // D Language
    specs[TargetLanguage.D] = LanguageSpec(
        TargetLanguage.D,
        "D",
        [
            ImportPattern("import", `^\s*import\s+([\w.]+)`)
        ],
        &detectRelativeImport
    );
    
    // Python
    specs[TargetLanguage.Python] = LanguageSpec(
        TargetLanguage.Python,
        "Python",
        [
            ImportPattern("import", `^\s*import\s+([\w.]+)`),
            ImportPattern("from-import", `^\s*from\s+([\w.]+)\s+import`)
        ],
        &detectPythonImportKind
    );
    
    // JavaScript / TypeScript
    specs[TargetLanguage.JavaScript] = LanguageSpec(
        TargetLanguage.JavaScript,
        "JavaScript",
        [
            ImportPattern("es6-import", `^\s*import\s+.*from\s+['"]([^'"]+)['"]`),
            ImportPattern("require", `^\s*(?:const|let|var)\s+.*=\s*require\s*\(['"]([^'"]+)['"]\)`)
        ],
        &detectJavaScriptImportKind
    );
    
    specs[TargetLanguage.TypeScript] = specs[TargetLanguage.JavaScript];
    specs[TargetLanguage.TypeScript].language = TargetLanguage.TypeScript;
    specs[TargetLanguage.TypeScript].name = "TypeScript";
    
    // Go
    specs[TargetLanguage.Go] = LanguageSpec(
        TargetLanguage.Go,
        "Go",
        [
            ImportPattern("import", `^\s*import\s+"([^"]+)"`),
            ImportPattern("import-multi", `^\s+"([^"]+)"`)
        ],
        &detectGoImportKind
    );
    
    // Rust
    specs[TargetLanguage.Rust] = LanguageSpec(
        TargetLanguage.Rust,
        "Rust",
        [
            ImportPattern("use", `^\s*use\s+([\w:]+)`),
            ImportPattern("extern-crate", `^\s*extern\s+crate\s+([\w]+)`)
        ],
        &detectRustImportKind
    );
    
    // C/C++
    specs[TargetLanguage.Cpp] = LanguageSpec(
        TargetLanguage.Cpp,
        "C++",
        [
            ImportPattern("include", `^\s*#include\s+["<]([^">]+)[">]`)
        ],
        &detectRelativeImport
    );
    
    specs[TargetLanguage.C] = specs[TargetLanguage.Cpp];
    specs[TargetLanguage.C].language = TargetLanguage.C;
    specs[TargetLanguage.C].name = "C";
    
    // Java
    specs[TargetLanguage.Java] = LanguageSpec(
        TargetLanguage.Java,
        "Java",
        [
            ImportPattern("import", `^\s*import\s+([\w.]+)`)
        ],
        &detectRelativeImport
    );
    
    // Generic (no-op)
    specs[TargetLanguage.Generic] = LanguageSpec(
        TargetLanguage.Generic,
        "Generic",
        [],
        &detectRelativeImport
    );
    
    LanguageSpecs = cast(immutable) specs;
}

/// Get spec for a language
const(LanguageSpec)* getLanguageSpec(TargetLanguage lang)
{
    if (auto spec = lang in LanguageSpecs)
        return spec;
    return null;
}

