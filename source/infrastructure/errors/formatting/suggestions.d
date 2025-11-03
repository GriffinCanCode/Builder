module infrastructure.errors.formatting.suggestions;

import infrastructure.errors.types.types : BuildError, BaseBuildError, BuildFailureError, ParseError;
import infrastructure.errors.handling.codes : ErrorCode;
import infrastructure.errors.types.context : ErrorSuggestion;

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
    static const(ErrorSuggestion)[] generate(const BuildError error) @trusted
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
    private static const(ErrorSuggestion)[] generateFromCode(ErrorCode code) @trusted
    {
        ErrorSuggestion[] suggestions;
        
        switch (code)
        {
            case ErrorCode.FileNotFound:
                suggestions ~= ErrorSuggestion(
                    "Verify the file path is correct and the file exists",
                    ErrorSuggestion.Type.FileCheck,
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    "Check current directory contents",
                    ErrorSuggestion.Type.Command,
                    "ls -la"
                );
                break;
                
            case ErrorCode.ParseFailed:
                suggestions ~= ErrorSuggestion(
                    "Review Builderfile syntax documentation",
                    ErrorSuggestion.Type.Documentation,
                    "https://docs.builder.dev/syntax"
                );
                break;
                
            case ErrorCode.CircularDependency:
                suggestions ~= ErrorSuggestion(
                    "Visualize dependency graph to identify cycle",
                    ErrorSuggestion.Type.Command,
                    "builder query --graph"
                );
                break;
                
            case ErrorCode.ProcessSpawnFailed:
                suggestions ~= ErrorSuggestion(
                    "Run command directly to see full error output",
                    ErrorSuggestion.Type.Command,
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    "Check if required tools are installed and in PATH",
                    ErrorSuggestion.Type.FileCheck,
                    ""
                );
                break;
                
            case ErrorCode.PermissionDenied:
                suggestions ~= ErrorSuggestion(
                    "Check file permissions",
                    ErrorSuggestion.Type.Command,
                    "ls -l <file>"
                );
                suggestions ~= ErrorSuggestion(
                    "Try running with appropriate permissions",
                    ErrorSuggestion.Type.Command,
                    "chmod +x <file>"
                );
                break;
                
            case ErrorCode.NetworkError:
                suggestions ~= ErrorSuggestion(
                    "Check network connectivity",
                    ErrorSuggestion.Type.General,
                    ""
                );
                suggestions ~= ErrorSuggestion(
                    "Verify proxy settings if behind a firewall",
                    ErrorSuggestion.Type.General,
                    ""
                );
                break;
                
            case ErrorCode.CacheCorrupted:
                suggestions ~= ErrorSuggestion(
                    "Clear the cache and rebuild",
                    ErrorSuggestion.Type.Command,
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

