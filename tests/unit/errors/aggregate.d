module tests.unit.errors.aggregate;

import std.stdio;
import std.conv;
import errors.handling.aggregate;
import errors.handling.result;
import errors.types.types;
import errors.handling.codes;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - Successful aggregation (all Ok)");
    
    auto r1 = Ok!(int, BuildError)(1);
    auto r2 = Ok!(int, BuildError)(2);
    auto r3 = Ok!(int, BuildError)(3);
    
    auto result = aggregate([r1, r2, r3]);
    
    Assert.isTrue(result.isOk);
    Assert.isFalse(result.hasErrors);
    Assert.isTrue(result.hasSuccesses);
    Assert.isFalse(result.isPartial);
    Assert.isFalse(result.isFailed);
    Assert.equal(result.successes.length, 3);
    Assert.equal(result.errors.length, 0);
    Assert.equal(result.successes, [1, 2, 3]);
    
    writeln("\x1b[32m  ✓ Successful aggregation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - Complete failure (all Err)");
    
    auto r1 = Err!(int, BuildError)(parseError("f1", "error 1"));
    auto r2 = Err!(int, BuildError)(parseError("f2", "error 2"));
    auto r3 = Err!(int, BuildError)(parseError("f3", "error 3"));
    
    auto result = aggregate([r1, r2, r3], AggregationPolicy.CollectAll);
    
    Assert.isFalse(result.isOk);
    Assert.isTrue(result.hasErrors);
    Assert.isFalse(result.hasSuccesses);
    Assert.isFalse(result.isPartial);
    Assert.isTrue(result.isFailed);
    Assert.equal(result.successes.length, 0);
    Assert.equal(result.errors.length, 3);
    
    writeln("\x1b[32m  ✓ Complete failure aggregation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - Partial success with CollectAll policy");
    
    auto r1 = Ok!(int, BuildError)(1);
    auto r2 = Err!(int, BuildError)(parseError("f2", "error"));
    auto r3 = Ok!(int, BuildError)(3);
    auto r4 = Err!(int, BuildError)(parseError("f4", "another error"));
    auto r5 = Ok!(int, BuildError)(5);
    
    auto result = aggregate([r1, r2, r3, r4, r5], AggregationPolicy.CollectAll);
    
    Assert.isFalse(result.isOk);
    Assert.isTrue(result.hasErrors);
    Assert.isTrue(result.hasSuccesses);
    Assert.isTrue(result.isPartial);
    Assert.isFalse(result.isFailed);
    Assert.equal(result.successes, [1, 3, 5]);
    Assert.equal(result.errors.length, 2);
    
    writeln("\x1b[32m  ✓ Partial success with CollectAll policy works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - FailFast policy stops at first error");
    
    auto r1 = Ok!(int, BuildError)(1);
    auto r2 = Err!(int, BuildError)(parseError("f2", "error"));
    auto r3 = Ok!(int, BuildError)(3);  // Should not be processed
    
    auto result = aggregate([r1, r2, r3], AggregationPolicy.FailFast);
    
    Assert.isTrue(result.isPartial);
    Assert.equal(result.successes, [1]);  // Only first success
    Assert.equal(result.errors.length, 1);  // Only first error
    
    writeln("\x1b[32m  ✓ FailFast policy stops at first error\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - ErrorAggregator incremental adding");
    
    auto agg = ErrorAggregator!int(AggregationPolicy.CollectAll);
    
    agg.add(Ok!(int, BuildError)(1));
    Assert.equal(agg.successCount, 1);
    Assert.equal(agg.errorCount, 0);
    Assert.isFalse(agg.shouldStop);
    
    agg.add(Err!(int, BuildError)(parseError("f2", "error")));
    Assert.equal(agg.successCount, 1);
    Assert.equal(agg.errorCount, 1);
    Assert.isFalse(agg.shouldStop);  // CollectAll never stops
    
    agg.add(Ok!(int, BuildError)(3));
    Assert.equal(agg.successCount, 2);
    Assert.equal(agg.errorCount, 1);
    
    auto result = agg.finish();
    Assert.isTrue(result.isPartial);
    Assert.equal(result.successes, [1, 3]);
    Assert.equal(result.errors.length, 1);
    
    writeln("\x1b[32m  ✓ ErrorAggregator incremental adding works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - ErrorAggregator with FailFast stops correctly");
    
    auto agg = ErrorAggregator!int(AggregationPolicy.FailFast);
    
    agg.add(Ok!(int, BuildError)(1));
    Assert.isFalse(agg.shouldStop);
    
    agg.add(Err!(int, BuildError)(parseError("f2", "error")));
    Assert.isTrue(agg.shouldStop);  // Should stop after first error
    
    agg.add(Ok!(int, BuildError)(3));  // Should be ignored
    Assert.equal(agg.successCount, 1);  // Still 1
    
    writeln("\x1b[32m  ✓ ErrorAggregator with FailFast stops correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - aggregateMap with transformation");
    
    auto items = ["1", "2", "not-a-number", "4", "5"];
    
    auto result = aggregateMap(items, (string s) {
        try {
            return Ok!(int, BuildError)(s.to!int);
        } catch (Exception e) {
            return Err!(int, BuildError)(parseError(s, e.msg));
        }
    }, AggregationPolicy.CollectAll);
    
    Assert.isTrue(result.isPartial);
    Assert.equal(result.successes, [1, 2, 4, 5]);
    Assert.equal(result.errors.length, 1);
    
    writeln("\x1b[32m  ✓ aggregateMap with transformation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - aggregateMap with FailFast");
    
    auto items = ["1", "bad", "3"];
    
    auto result = aggregateMap(items, (string s) {
        try {
            return Ok!(int, BuildError)(s.to!int);
        } catch (Exception e) {
            return Err!(int, BuildError)(parseError(s, e.msg));
        }
    }, AggregationPolicy.FailFast);
    
    // Should stop after "1" succeeds and "bad" fails
    Assert.equal(result.successes, [1]);
    Assert.equal(result.errors.length, 1);
    
    writeln("\x1b[32m  ✓ aggregateMap with FailFast works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - Empty results array");
    
    Result!(int, BuildError)[] emptyResults;
    auto result = aggregate(emptyResults);
    
    Assert.isTrue(result.isOk);
    Assert.isFalse(result.hasErrors);
    Assert.isFalse(result.hasSuccesses);
    Assert.equal(result.successes.length, 0);
    Assert.equal(result.errors.length, 0);
    
    writeln("\x1b[32m  ✓ Empty results array is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - toResult conversion");
    
    // All successful -> Ok result
    {
        auto agg = ErrorAggregator!int(AggregationPolicy.CollectAll);
        agg.add(Ok!(int, BuildError)(1));
        agg.add(Ok!(int, BuildError)(2));
        
        auto result = agg.toResult();
        Assert.isTrue(result.isOk);
        Assert.equal(result.unwrap(), [1, 2]);
    }
    
    // With errors -> Err result
    {
        auto agg = ErrorAggregator!int(AggregationPolicy.CollectAll);
        agg.add(Ok!(int, BuildError)(1));
        agg.add(Err!(int, BuildError)(parseError("f2", "error")));
        
        auto result = agg.toResult();
        Assert.isTrue(result.isErr);
    }
    
    writeln("\x1b[32m  ✓ toResult conversion works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - StopAtFatal policy with recoverable errors");
    
    // Create recoverable error (CacheError is recoverable)
    auto r1 = Ok!(int, BuildError)(1);
    auto r2 = Err!(int, BuildError)(new CacheError("temp issue", ErrorCode.CacheLoadFailed));
    auto r3 = Ok!(int, BuildError)(3);
    
    auto result = aggregate([r1, r2, r3], AggregationPolicy.StopAtFatal);
    
    // Should continue through recoverable error
    Assert.isTrue(result.isPartial);
    Assert.equal(result.successes, [1, 3]);
    Assert.equal(result.errors.length, 1);
    
    writeln("\x1b[32m  ✓ StopAtFatal policy continues through recoverable errors\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.aggregate - StopAtFatal policy with fatal errors");
    
    // Create fatal error (ParseError is not recoverable)
    auto r1 = Ok!(int, BuildError)(1);
    auto r2 = Err!(int, BuildError)(new ParseError("file", "fatal", ErrorCode.ParseFailed));
    auto r3 = Ok!(int, BuildError)(3);  // Should not be processed
    
    auto result = aggregate([r1, r2, r3], AggregationPolicy.StopAtFatal);
    
    // Should stop at fatal error
    Assert.isTrue(result.isPartial);
    Assert.equal(result.successes, [1]);
    Assert.equal(result.errors.length, 1);
    
    writeln("\x1b[32m  ✓ StopAtFatal policy stops at fatal errors\x1b[0m");
}

