module errors.formatting.suggestions;

import errors.types.types : BuildError, BuildFailureError, ParseError, FileNotFoundError;
import errors.handling.codes : ErrorCode;
import errors.types.context : ErrorSuggestion;

/// Suggestion generator - single responsibility: generate contextual suggestions
/// 
/// Separation of concerns:
/// - ErrorFormatter: formats error structures
/// - ColorFormatter: applies terminal colors
/// - SuggestionGenerator: generates helpful suggestions based on error context
struct SuggestionGenerator
{
    /// Generate suggestions for an error
    /// 
    /// Responsibility: Analyze error and return relevant suggestions
    static const(ErrorSuggestion)[] generate(const BuildError error) @safe
    {
        // Try to get typed suggestions from error first
        if (auto baseErr = cast(const BaseBuildError)error)
        {
            auto typedSuggestions = baseErr.suggestions();
            if (typedSuggestions.length > 0)
                return typedSuggestions;
        }
        
        // Fallback to code-based suggestions
        return generateFromCode(error.code());
    }
    
    /// Generate suggestions based on error code
    /// 
    /// Responsibility: Provide generic suggestions for common error codes
    private static const(ErrorSuggestion)[] generateFromCode(ErrorCode code) @safe
    {
        ErrorSuggestion[] suggestions;
        
        switch (code)
        {
            case ErrorCode.FileNotFound:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.FileCheck,
                    "Verify the file path is correct and the file exists",
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Check current directory contents",
                    "ls -la"
                );
                break;
                
            case ErrorCode.ParseError:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Documentation,
                    "Review Builderfile syntax documentation",
                    "https://docs.builder.dev/syntax"
                );
                break;
                
            case ErrorCode.DependencyCycle:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Visualize dependency graph to identify cycle",
                    "builder query --graph"
                );
                break;
                
            case ErrorCode.CommandFailed:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Run command directly to see full error output",
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.FileCheck,
                    "Check if required tools are installed and in PATH",
                    ""
                );
                break;
                
            case ErrorCode.PermissionDenied:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Check file permissions",
                    "ls -l <file>"
                );
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Try running with appropriate permissions",
                    "chmod +x <file>"
                );
                break;
                
            case ErrorCode.NetworkError:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.General,
                    "Check network connectivity",
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.General,
                    "Verify proxy settings if behind a firewall",
                    ""
                );
                break;
                
            case ErrorCode.CacheCorrupted:
                suggestions ~= ErrorSuggestion(
                    ErrorSuggestion.Type.Command,
                    "Clear the cache and rebuild",
                    "builder clean --cache"
                );
                break;
                
            default:
                // No specific suggestions for this error code
                break;
        }
        
        return cast(const(ErrorSuggestion)[])suggestions;
    }
}

