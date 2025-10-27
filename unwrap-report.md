# Unwrap Refactoring Report

## Summary
- Total unwrap() calls: 64
- Need improvement: 24
- Already good: 40

## [1] source/core/graph/graph.d:270
**Strategy**: UseAndThen
**Rationale**: Inside loop - use andThen for early exit

**Original**:
```d
/// foreach (dep; deps) graph.addDependency(from, to).unwrap();
```

**Suggested**:
```d
// Use andThen to propagate errors
/// foreach (dep; deps) graph.addDependency(from, to).andThen((value) {
    // Use value here
    return Ok!(...)(result);
})
```

## [2] source/core/graph/graph.d:282
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
///   auto id = TargetId.parse("//path:target").unwrap();
```

**Suggested**:
```d
if (TargetId.parse("//path:target").isErr)
    Logger.error("Unwrap failed at source/core/graph/graph.d:282: " ~ format(TargetId.parse("//path:target").unwrapErr()));
auto id = TargetId.parse("//path:target").unwrap();
```

## [3] source/core/graph/graph.d:593
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto sorted = sortResult.unwrap();
```

**Suggested**:
```d
if (sortResult.isErr)
    Logger.error("Unwrap failed at source/core/graph/graph.d:593: " ~ format(sortResult.unwrapErr()));
auto sorted = sortResult.unwrap();
```

## [4] source/core/execution/executor.d:243
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto sorted = sortResult.unwrap();
```

**Suggested**:
```d
if (sortResult.isErr)
    Logger.error("Unwrap failed at source/core/execution/executor.d:243: " ~ format(sortResult.unwrapErr()));
auto sorted = sortResult.unwrap();
```

## [5] source/core/telemetry/tracing.d:366
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
ctx.traceId = traceResult.unwrap();
```

**Suggested**:
```d
if (traceResult.isErr)
    Logger.error("Unwrap failed at source/core/telemetry/tracing.d:366: " ~ format(traceResult.unwrapErr()));
auto traceId = traceResult.unwrap();
```

## [6] source/core/telemetry/tracing.d:367
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
ctx.spanId = spanResult.unwrap();
```

**Suggested**:
```d
if (spanResult.isErr)
    Logger.error("Unwrap failed at source/core/telemetry/tracing.d:367: " ~ format(spanResult.unwrapErr()));
auto spanId = spanResult.unwrap();
```

## [7] source/analysis/inference/analyzer.d:81
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto analysis = analysisResult.unwrap();
```

**Suggested**:
```d
if (analysisResult.isErr)
    Logger.error("Unwrap failed at source/analysis/inference/analyzer.d:81: " ~ format(analysisResult.unwrapErr()));
auto analysis = analysisResult.unwrap();
```

## [8] source/config/interpretation/dsl.d:676
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto targets = result.unwrap();
```

**Suggested**:
```d
if (result.isErr)
    Logger.error("Unwrap failed at source/config/interpretation/dsl.d:676: " ~ format(result.unwrapErr()));
auto targets = result.unwrap();
```

## [9] source/config/parsing/lexer.d:479
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto tokens = result.unwrap();
```

**Suggested**:
```d
if (result.isErr)
    Logger.error("Unwrap failed at source/config/parsing/lexer.d:479: " ~ format(result.unwrapErr()));
auto tokens = result.unwrap();
```

## [10] source/config/parsing/lexer.d:495
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto tokens1 = result1.unwrap();
```

**Suggested**:
```d
if (result1.isErr)
    Logger.error("Unwrap failed at source/config/parsing/lexer.d:495: " ~ format(result1.unwrapErr()));
auto tokens1 = result1.unwrap();
```

## [11] source/config/parsing/lexer.d:503
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto tokens2 = result2.unwrap();
```

**Suggested**:
```d
if (result2.isErr)
    Logger.error("Unwrap failed at source/config/parsing/lexer.d:503: " ~ format(result2.unwrapErr()));
auto tokens2 = result2.unwrap();
```

## [12] source/utils/security/executor.d:450
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
assert(result.unwrap().success);
```

**Suggested**:
```d
if (assert(result.isErr)
    Logger.error("Unwrap failed at source/utils/security/executor.d:450: " ~ format(assert(result.unwrapErr()));
auto  = assert(result.unwrap();
```

## [13] source/cli/commands/telemetry.d:47
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto sessions = sessionsResult.unwrap();
```

**Suggested**:
```d
if (sessionsResult.isErr)
    Logger.error("Unwrap failed at source/cli/commands/telemetry.d:47: " ~ format(sessionsResult.unwrapErr()));
auto sessions = sessionsResult.unwrap();
```

## [14] source/cli/commands/telemetry.d:63
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto report = reportResult.unwrap();
```

**Suggested**:
```d
if (reportResult.isErr)
    Logger.error("Unwrap failed at source/cli/commands/telemetry.d:63: " ~ format(reportResult.unwrapErr()));
auto report = reportResult.unwrap();
```

## [15] source/cli/commands/telemetry.d:72
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
writeln(summaryResult.unwrap());
```

**Suggested**:
```d
if (writeln(summaryResult.isErr)
    Logger.error("Unwrap failed at source/cli/commands/telemetry.d:72: " ~ format(writeln(summaryResult.unwrapErr()));
auto  = writeln(summaryResult.unwrap();
```

## [16] source/cli/commands/telemetry.d:104
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto sessions = recentResult.unwrap();
```

**Suggested**:
```d
if (recentResult.isErr)
    Logger.error("Unwrap failed at source/cli/commands/telemetry.d:104: " ~ format(recentResult.unwrapErr()));
auto sessions = recentResult.unwrap();
```

## [17] source/cli/commands/telemetry.d:156
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto sessions = sessionsResult.unwrap();
```

**Suggested**:
```d
if (sessionsResult.isErr)
    Logger.error("Unwrap failed at source/cli/commands/telemetry.d:156: " ~ format(sessionsResult.unwrapErr()));
auto sessions = sessionsResult.unwrap();
```

## [18] source/errors/handling/aggregate.d:96
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
successes ~= result.unwrap();
```

**Suggested**:
```d
if (successes ~= result.isErr)
    Logger.error("Unwrap failed at source/errors/handling/aggregate.d:96: " ~ format(successes ~= result.unwrapErr()));
auto  = successes ~= result.unwrap();
```

## [19] source/errors/handling/aggregate.d:128
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
foreach (item; result.unwrap())
```

**Suggested**:
```d
if (foreach (item; result.isErr)
    Logger.error("Unwrap failed at source/errors/handling/aggregate.d:128: " ~ format(foreach (item; result.unwrapErr()));
auto  = foreach (item; result.unwrap();
```

## [20] source/errors/adaptation/adapt.d:49
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
buildResult.outputHash = result.unwrap();
```

**Suggested**:
```d
if (result.isErr)
    Logger.error("Unwrap failed at source/errors/adaptation/adapt.d:49: " ~ format(result.unwrapErr()));
auto outputHash = result.unwrap();
```

## [21] source/app.d:111
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto config = configResult.unwrap();
```

**Suggested**:
```d
if (configResult.isErr)
    Logger.error("Unwrap failed at source/app.d:111: " ~ format(configResult.unwrapErr()));
auto config = configResult.unwrap();
```

## [22] source/app.d:209
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto config = configResult.unwrap();
```

**Suggested**:
```d
if (configResult.isErr)
    Logger.error("Unwrap failed at source/app.d:209: " ~ format(configResult.unwrapErr()));
auto config = configResult.unwrap();
```

## [23] source/app.d:243
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto checkpoint = checkpointResult.unwrap();
```

**Suggested**:
```d
if (checkpointResult.isErr)
    Logger.error("Unwrap failed at source/app.d:243: " ~ format(checkpointResult.unwrapErr()));
auto checkpoint = checkpointResult.unwrap();
```

## [24] source/app.d:269
**Strategy**: LogBeforeUnwrap
**Rationale**: Add logging for better error context

**Original**:
```d
auto config = configResult.unwrap();
```

**Suggested**:
```d
if (configResult.isErr)
    Logger.error("Unwrap failed at source/app.d:269: " ~ format(configResult.unwrapErr()));
auto config = configResult.unwrap();
```

