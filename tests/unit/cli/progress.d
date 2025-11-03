module tests.unit.cli.progress;

import tests.harness;
import frontend.cli.output.progress;
import std.datetime : dur;
import core.thread : Thread;

/// Test progress tracker initialization
void testProgressTrackerInit()
{
    auto tracker = ProgressTracker(10);
    auto snap = tracker.snapshot();
    
    Assert.equal(snap.total, 10);
    Assert.equal(snap.completed, 0);
    Assert.equal(snap.failed, 0);
    Assert.equal(snap.cached, 0);
}

/// Test progress increment operations
void testProgressIncrement()
{
    auto tracker = ProgressTracker(10);
    
    tracker.incrementCompleted();
    tracker.incrementCompleted();
    tracker.incrementFailed();
    tracker.incrementCached();
    
    auto snap = tracker.snapshot();
    Assert.equal(snap.completed, 2);
    Assert.equal(snap.failed, 1);
    Assert.equal(snap.cached, 1);
    Assert.equal(snap.finished, 4);
}

/// Test progress snapshot calculations
void testProgressSnapshotCalculations()
{
    auto tracker = ProgressTracker(100);
    
    // Add some progress
    foreach (i; 0 .. 25)
        tracker.incrementCompleted();
    
    foreach (i; 0 .. 15)
        tracker.incrementCached();
    
    auto snap = tracker.snapshot();
    
    Assert.equal(snap.finished, 40);
    Assert.equal(snap.remaining, 60);
    Assert.isTrue(snap.percentage > 0.39 && snap.percentage < 0.41, 
                 "Percentage should be ~40%");
}

/// Test progress completion check
void testProgressCompletion()
{
    auto tracker = ProgressTracker(5);
    
    auto snap1 = tracker.snapshot();
    Assert.isFalse(snap1.isComplete, "Should not be complete initially");
    
    foreach (i; 0 .. 5)
        tracker.incrementCompleted();
    
    auto snap2 = tracker.snapshot();
    Assert.isTrue(snap2.isComplete, "Should be complete after all targets");
}

/// Test concurrent updates (thread safety)
void testProgressConcurrentUpdates()
{
    auto tracker = ProgressTracker(1000);
    
    // Spawn multiple threads updating concurrently
    Thread[] threads;
    
    foreach (i; 0 .. 10)
    {
        auto t = new Thread({
            foreach (j; 0 .. 100)
                tracker.incrementCompleted();
        });
        threads ~= t;
        t.start();
    }
    
    // Wait for all threads
    foreach (t; threads)
        t.join();
    
    auto snap = tracker.snapshot();
    Assert.equal(snap.completed, 1000, "All updates should be counted");
}

/// Test progress bar rendering
void testProgressBarRender()
{
    auto bar = ProgressBar(20);
    
    auto bar0 = bar.render(0.0);
    Assert.isTrue(bar0.length > 0, "Should render 0% bar");
    
    auto bar50 = bar.render(0.5);
    Assert.isTrue(bar50.length > 0, "Should render 50% bar");
    
    auto bar100 = bar.render(1.0);
    Assert.isTrue(bar100.length > 0, "Should render 100% bar");
}

/// Test progress bar with percentage
void testProgressBarWithPercent()
{
    auto bar = ProgressBar(20);
    
    auto result = bar.renderWithPercent(0.75);
    Assert.isTrue(result.length > 0, "Should render bar with percent");
    Assert.isTrue(result.canFind("75%"), "Should contain percentage");
}

/// Test progress bar complete rendering
void testProgressBarComplete()
{
    auto bar = ProgressBar(20);
    auto tracker = ProgressTracker(10);
    
    tracker.incrementCompleted();
    tracker.incrementCompleted();
    tracker.incrementCached();
    
    auto snap = tracker.snapshot();
    auto result = bar.renderComplete(snap);
    
    Assert.isTrue(result.length > 0, "Should render complete bar");
    Assert.isTrue(result.canFind("["), "Should contain brackets");
}

/// Test progress aggregator
void testProgressAggregator()
{
    auto agg = ProgressAggregator(5);
    
    agg.updateTarget("target1", "building", 0.5);
    agg.updateTarget("target2", "building", 0.3);
    
    auto active = agg.activeTargets();
    Assert.equal(active.length, 2, "Should have 2 active targets");
    
    agg.completeTarget("target1");
    
    auto active2 = agg.activeTargets();
    Assert.equal(active2.length, 1, "Should have 1 active target");
    
    auto snap = agg.snapshot();
    Assert.equal(snap.completed, 1);
}

private import std.algorithm : canFind;