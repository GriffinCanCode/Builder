module frontend.query.output;

/// Query Output Formatting Module
/// 
/// Formats query results into various output formats
/// for different use cases and consumption patterns.
/// 
/// Supported Formats:
/// - Pretty: Human-readable with colors and formatting
/// - List: Simple newline-separated target names
/// - JSON: Machine-readable structured data
/// - DOT: GraphViz visualization format
/// 
/// Example:
/// ```d
/// auto formatter = QueryFormatter(OutputFormat.Pretty);
/// string output = formatter.formatResults(results, query);
/// writeln(output);
/// ```

public import frontend.query.output.formatter;

