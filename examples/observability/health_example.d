#!/usr/bin/env dub
/+ dub.sdl:
    name "health_example"
    dependency "builder" path="../../"
+/

/**
 * Health Monitoring Example
 * 
 * Demonstrates real-time health checkpoint system for build monitoring.
 * Shows velocity tracking, time estimation, and resource monitoring.
 * 
 * Usage:
 *   cd examples/observability
 *   dub run --single health_example.d
 */

import std.stdio;
import std.datetime : dur;
import core.thread : Thread;
import core.telemetry.health;

void main()
{
    writeln("=== Health Checkpoint Example ===\n");
    
    // Example 1: Basic health monitoring
    basicHealthExample();
    
    // Example 2: Build simulation with health tracking
    buildSimulationExample();
    
    // Example 3: Health trends
    healthTrendsExample();
    
    writeln("\n=== Examples Complete ===");
}

void basicHealthExample()
{
    writeln("Example 1: Basic Health Checkpoint\n");
    
    // Create a single checkpoint
    auto checkpoint = HealthCheckpoint.create(
        dur!"seconds"(30),  // 30 seconds uptime
        120,  // completed tasks
        5,    // failed tasks
        8,    // active tasks
        35,   // pending tasks
        16,   // total workers
        8,    // active workers
        0.25  // avg task time (seconds)
    );
    
    writeln(checkpoint);
    writeln();
}

void buildSimulationExample()
{
    writeln("Example 2: Simulated Build with Health Monitoring\n");
    
    // Create health monitor with 2-second checkpoints
    auto monitor = new HealthMonitor(2000);
    monitor.start();
    
    // Simulate a build with 100 tasks
    size_t completed = 0;
    size_t failed = 0;
    size_t totalTasks = 100;
    size_t workers = 8;
    
    writeln("Starting simulated build with ", totalTasks, " tasks...\n");
    
    foreach (batch; 0 .. 10)
    {
        // Simulate building a batch
        immutable tasksInBatch = 10;
        immutable activeTasks = tasksInBatch < workers ? tasksInBatch : workers;
        
        // Take checkpoint if interval elapsed
        if (monitor.shouldCheckpoint())
        {
            monitor.checkpoint(
                completed,
                failed,
                activeTasks,
                totalTasks - completed - failed,
                workers,
                activeTasks,
                0.1 + (batch * 0.01)  // Increasing task time
            );
            
            // Display latest health
            auto latestResult = monitor.getLatest();
            if (latestResult.isOk)
            {
                auto cp = latestResult.unwrap();
                writefln("Checkpoint %d: Status=%s, Progress=%d/%d, ETA=%s",
                        batch + 1,
                        cp.status,
                        completed,
                        totalTasks,
                        cp.estimateTimeRemaining());
            }
        }
        
        // Simulate work
        Thread.sleep(dur!"msecs"(500));
        
        // Update progress
        completed += tasksInBatch - 1;  // 9 succeed
        failed += 1;  // 1 fails
    }
    
    // Final checkpoint
    auto final = monitor.stop();
    writeln("\nFinal Health:");
    writeln(final);
    
    // Show summary
    writeln("\n", monitor.report());
    writeln();
}

void healthTrendsExample()
{
    writeln("Example 3: Health Trends\n");
    
    auto monitor = new HealthMonitor(1000);
    monitor.start();
    
    // Simulate improving performance
    writeln("Phase 1: Build starting (low velocity)");
    monitor.checkpoint(5, 0, 4, 95, 8, 4, 0.5);
    Thread.sleep(dur!"msecs"(100));
    
    writeln("Phase 2: Build ramping up");
    monitor.checkpoint(25, 0, 6, 75, 8, 6, 0.3);
    Thread.sleep(dur!"msecs"(100));
    
    writeln("Phase 3: Build at full speed");
    monitor.checkpoint(60, 0, 8, 40, 8, 8, 0.2);
    auto trend = monitor.getTrend();
    writeln("Trend: ", trend);
    Thread.sleep(dur!"msecs"(100));
    
    // Simulate degradation
    writeln("\nPhase 4: Performance degrading (failures appearing)");
    monitor.checkpoint(75, 5, 4, 20, 8, 4, 0.4);
    trend = monitor.getTrend();
    writeln("Trend: ", trend);
    Thread.sleep(dur!"msecs"(100));
    
    auto summary = monitor.getSummary();
    writeln("\nSummary:");
    writefln("  Total checkpoints: %d", summary.totalCheckpoints);
    writefln("  Final status: %s", summary.finalStatus);
    writefln("  Trend: %s", summary.trend);
    writefln("  Avg velocity: %.2f tasks/sec", summary.avgVelocity);
    writefln("  Peak utilization: %.1f%%", summary.peakUtilization);
    
    monitor.stop();
    writeln();
}

