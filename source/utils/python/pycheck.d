module utils.python.pycheck;

import std.stdio;
import std.process : Config;
import utils.security : execute;  // SECURITY: Auto-migrated
import std.json;
import std.array;
import std.algorithm;
import std.file;
import std.path;
import std.exception;

/// Result of Python validation for a single file
struct PyFileResult
{
    string file;
    bool valid;
    string error;
    bool hasMain;
    bool hasMainGuard;
    bool isExecutable;
}

/// Result of batch Python validation
struct PyValidationResult
{
    bool success;
    size_t total;
    size_t valid;
    size_t invalid;
    PyFileResult[] files;
    
    /// Get first error message if any
    string firstError() const
    {
        foreach (file; files)
        {
            if (!file.valid && !file.error.empty)
                return file.file ~ ": " ~ file.error;
        }
        return "";
    }
}

/// Fast batch Python syntax validator using AST parsing
class PyValidator
{
    private static string validatorPath;
    
    static this()
    {
        // Get validator script path (in same directory as this module)
        validatorPath = buildNormalizedPath(thisExePath().dirName(), "..", "source", "utils", "python", "pyvalidator.py");
        
        // Fallback to relative path if not found
        if (!exists(validatorPath))
            validatorPath = buildNormalizedPath("source", "utils", "python", "pyvalidator.py");
    }
    
    /// Validate multiple Python files in a single batch
    static PyValidationResult validate(const string[] files)
    {
        enforce(!files.empty, "No files to validate");
        
        // Ensure validator exists
        enforce(exists(validatorPath), 
            "Python validator not found at: " ~ validatorPath);
        
        // Run validator with all files at once
        auto cmd = ["python3", validatorPath] ~ files;
        auto result = execute(cmd);
        
        // Parse JSON result
        return parseResult(result.output, result.status);
    }
    
    /// Validate a single Python file
    static PyFileResult validateSingle(string file)
    {
        auto result = validate([file]);
        enforce(!result.files.empty, "No validation result returned");
        return result.files[0];
    }
    
    private static PyValidationResult parseResult(string jsonOutput, int exitCode)
    {
        PyValidationResult result;
        
        try
        {
            auto json = parseJSON(jsonOutput);
            
            result.success = json["success"].boolean;
            result.total = cast(size_t)json["total"].integer;
            result.valid = cast(size_t)json["valid"].integer;
            result.invalid = cast(size_t)json["invalid"].integer;
            
            auto filesArray = json["files"].array;
            result.files.length = filesArray.length;
            
            foreach (i, fileJson; filesArray)
            {
                result.files[i].file = fileJson["file"].str;
                result.files[i].valid = fileJson["valid"].boolean;
                
                if ("error" in fileJson && fileJson["error"].type == JSONType.string)
                    result.files[i].error = fileJson["error"].str;
                    
                result.files[i].hasMain = fileJson["has_main"].boolean;
                result.files[i].hasMainGuard = fileJson["has_main_guard"].boolean;
                result.files[i].isExecutable = fileJson["is_executable"].boolean;
            }
        }
        catch (Exception e)
        {
            // If JSON parsing fails, create error result
            result.success = false;
            result.total = 1;
            result.invalid = 1;
            
            PyFileResult errFile;
            errFile.valid = false;
            errFile.error = "Validator error: " ~ e.msg ~ "\nOutput: " ~ jsonOutput;
            result.files = [errFile];
        }
        
        return result;
    }
}

