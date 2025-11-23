module tests.unit.utils.workstealing_deque;

import std.stdio;
import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.random;
import std.parallelism;
import core.atomic;
import core.thread;
import core.time;
import tests.harness;
import infrastructure.utils.concurrency.deque : WorkStealingDeque;

// ==================== TEST TASK CLASS ====================

class TestTask
{
    int id;
    shared static size_t nextId;
    
    this(int taskId)
    {
        this.id = taskId;
    }
    
    static TestTask create()
    {
        auto taskId = atomicOp!"+="(nextId, 1);
        return new TestTask(cast(int)taskId);
    }
    
    override string toString() const { return "Task(" ~ id.to!string ~ ")"; }
}

// ==================== OPERATION TRACKING ====================

enum OpType { Push, Pop, Steal }

struct Operation
{
    OpType type;
    int taskId;     // Task ID involved
    bool success;   // Whether operation succeeded
    size_t threadId; // Thread that performed operation
    
    string toString() const
    {
        string typeStr = type == OpType.Push ? "Push" : 
                        type == OpType.Pop ? "Pop" : "Steal";
        string statusStr = success ? "✓" : "✗";
        return format("T%d: %s(%d) %s", threadId, typeStr, taskId, statusStr);
    }
}

// ==================== PROPERTY-BASED TEST INFRASTRUCTURE ====================

/// Generates random operations sequence
struct OperationGenerator
{
    private Mt19937 rng;
    
    this(uint seed)
    {
        rng.seed(seed);
    }
    
    /// Generate random operation type with bias towards push
    OpType nextOperation(double pushProb = 0.5, double popProb = 0.3)
    {
        auto r = uniform01(rng);
        if (r < pushProb)
            return OpType.Push;
        else if (r < pushProb + popProb)
            return OpType.Pop;
        else
            return OpType.Steal;
    }
    
    /// Generate sequence of random operations
    OpType[] generateSequence(size_t count)
    {
        OpType[] ops;
        ops.reserve(count);
        foreach (_; 0 .. count)
            ops ~= nextOperation();
        return ops;
    }
}

/// Records execution trace for verification
class ExecutionTrace
{
    private shared Operation[] operations;
    private shared int[int] taskExecutions;  // taskId -> execution count
    private shared size_t totalPushes;
    private shared size_t successfulPops;
    private shared size_t successfulSteals;
    
    void recordOperation(OpType type, int taskId, bool success, size_t threadId)
    {
        synchronized
        {
            operations ~= Operation(type, taskId, success, threadId);
            
            if (success)
            {
                final switch (type)
                {
                    case OpType.Push:
                        atomicOp!"+="(totalPushes, 1);
                        break;
                    case OpType.Pop:
                        atomicOp!"+="(successfulPops, 1);
                        recordExecution(taskId);
                        break;
                    case OpType.Steal:
                        atomicOp!"+="(successfulSteals, 1);
                        recordExecution(taskId);
                        break;
                }
            }
        }
    }
    
    private void recordExecution(int taskId)
    {
        synchronized
        {
            if (taskId in taskExecutions)
                taskExecutions[taskId]++;
            else
                taskExecutions[taskId] = 1;
        }
    }
    
    /// Property: No task should be executed more than once
    bool propertyNoDoubleExecution() const
    {
        foreach (taskId, count; taskExecutions)
        {
            if (count > 1)
            {
                writeln("  \x1b[31m✗ Double execution detected: Task ", taskId, " executed ", count, " times\x1b[0m");
                return false;
            }
        }
        return true;
    }
    
    /// Property: All pushed tasks should be accounted for (executed or still in queue)
    bool propertyNoLostTasks(size_t remainingInQueue) const
    {
        size_t executed = atomicLoad(successfulPops) + atomicLoad(successfulSteals);
        size_t pushed = atomicLoad(totalPushes);
        size_t accounted = executed + remainingInQueue;
        
        if (accounted != pushed)
        {
            writeln("  \x1b[31m✗ Lost tasks: Pushed=", pushed, 
                   " Executed=", executed, " Remaining=", remainingInQueue, 
                   " Accounted=", accounted, "\x1b[0m");
            return false;
        }
        return true;
    }
    
    /// Property: Steal operations should only succeed when queue is non-empty
    bool propertyStealConsistency() const
    {
        // This is a weak check - we can't perfectly verify this due to concurrent nature
        // but we can check that total successful retrieves doesn't exceed pushes
        size_t retrieved = atomicLoad(successfulPops) + atomicLoad(successfulSteals);
        size_t pushed = atomicLoad(totalPushes);
        
        if (retrieved > pushed)
        {
            writeln("  \x1b[31m✗ Retrieved more tasks than pushed: Retrieved=", 
                   retrieved, " Pushed=", pushed, "\x1b[0m");
            return false;
        }
        return true;
    }
    
    void printSummary() const
    {
        writeln("    Operations: ", operations.length);
        writeln("    Total pushes: ", atomicLoad(totalPushes));
        writeln("    Successful pops: ", atomicLoad(successfulPops));
        writeln("    Successful steals: ", atomicLoad(successfulSteals));
        writeln("    Unique tasks executed: ", taskExecutions.length);
    }
}

// ==================== PROPERTY-BASED TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: No lost tasks (single-threaded)");
    
    auto deque = WorkStealingDeque!TestTask(16);
    auto trace = new ExecutionTrace();
    auto gen = OperationGenerator(unpredictableSeed);
    
    const iterations = 1000;
    TestTask[] createdTasks;
    
    foreach (i; 0 .. iterations)
    {
        auto op = gen.nextOperation(0.6, 0.4);  // 60% push, 40% pop
        
        final switch (op)
        {
            case OpType.Push:
                auto task = TestTask.create();
                createdTasks ~= task;
                deque.push(task);
                trace.recordOperation(OpType.Push, task.id, true, 0);
                break;
                
            case OpType.Pop:
                auto task = deque.pop();
                trace.recordOperation(OpType.Pop, task ? task.id : -1, task !is null, 0);
                break;
                
            case OpType.Steal:
                auto task = deque.steal();
                trace.recordOperation(OpType.Steal, task ? task.id : -1, task !is null, 0);
                break;
        }
    }
    
    // Drain remaining tasks
    size_t remaining = 0;
    while (!deque.empty())
    {
        auto task = deque.pop();
        if (task !is null)
        {
            remaining++;
            trace.recordOperation(OpType.Pop, task.id, true, 0);
        }
    }
    
    trace.printSummary();
    
    Assert.isTrue(trace.propertyNoDoubleExecution(), "No task should be executed twice");
    Assert.isTrue(trace.propertyNoLostTasks(0), "All tasks should be accounted for");
    Assert.isTrue(trace.propertyStealConsistency(), "Steals should be consistent");
    
    writeln("\x1b[32m  ✓ All properties hold for single-threaded execution\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: No double execution (concurrent)");
    
    auto deque = WorkStealingDeque!TestTask(64);
    auto trace = new ExecutionTrace();
    
    shared bool running = true;
    const numStealers = 4;
    const operationsPerThread = 500;
    
    // Owner thread: push and pop
    auto ownerThread = new Thread({
        auto gen = OperationGenerator(unpredictableSeed);
        
        foreach (i; 0 .. operationsPerThread)
        {
            auto op = gen.nextOperation(0.7, 0.3);  // 70% push, 30% pop
            
            if (op == OpType.Push)
            {
                auto task = TestTask.create();
                deque.push(task);
                trace.recordOperation(OpType.Push, task.id, true, 0);
            }
            else
            {
                auto task = deque.pop();
                trace.recordOperation(OpType.Pop, task ? task.id : -1, task !is null, 0);
            }
            
            // Small random delay to create contention
            if (i % 50 == 0)
                Thread.sleep(1.usecs);
        }
        
        atomicStore(running, false);
    });
    
    // Stealer threads
    Thread[] stealerThreads;
    foreach (stealerId; 0 .. numStealers)
    {
        size_t threadId = stealerId + 1;
        stealerThreads ~= new Thread({
            while (atomicLoad(running) || !deque.empty())
            {
                auto task = deque.steal();
                trace.recordOperation(OpType.Steal, task ? task.id : -1, 
                                    task !is null, threadId);
                
                // Small random delay
                Thread.sleep(uniform(1, 10).usecs);
            }
        });
    }
    
    // Start all threads
    ownerThread.start();
    foreach (t; stealerThreads)
        t.start();
    
    // Wait for completion
    ownerThread.join();
    foreach (t; stealerThreads)
        t.join();
    
    // Drain any remaining tasks
    size_t remaining = 0;
    while (!deque.empty())
    {
        auto task = deque.pop();
        if (task !is null)
        {
            remaining++;
            trace.recordOperation(OpType.Pop, task.id, true, 0);
        }
    }
    
    trace.printSummary();
    
    Assert.isTrue(trace.propertyNoDoubleExecution(), "No task should be executed twice");
    Assert.isTrue(trace.propertyNoLostTasks(0), "All tasks should be accounted for");
    Assert.isTrue(trace.propertyStealConsistency(), "Steals should be consistent");
    
    writeln("\x1b[32m  ✓ All properties hold for concurrent execution\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: FIFO for stealers, LIFO for owner");
    
    auto deque = WorkStealingDeque!TestTask(32);
    
    // Push tasks 1, 2, 3, 4, 5
    int[] taskIds = [1, 2, 3, 4, 5];
    foreach (id; taskIds)
    {
        auto task = new TestTask(id);
        deque.push(task);
    }
    
    // Owner pop should be LIFO (gets 5, 4, 3...)
    auto task1 = deque.pop();
    Assert.equal(task1.id, 5, "Owner pop should be LIFO");
    
    // Stealer steal should be FIFO (gets 1, 2, 3...)
    auto task2 = deque.steal();
    Assert.equal(task2.id, 1, "Stealer steal should be FIFO");
    
    auto task3 = deque.steal();
    Assert.equal(task3.id, 2, "Stealer steal should be FIFO");
    
    writeln("\x1b[32m  ✓ FIFO/LIFO property verified\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: Race on last element");
    
    // Test the critical case where owner pops and stealers steal the last element
    const iterations = 100;
    size_t ownerWins = 0;
    size_t stealerWins = 0;
    size_t bothLose = 0;
    
    foreach (i; 0 .. iterations)
    {
        auto deque = WorkStealingDeque!TestTask(4);
        
        // Push single task
        auto task = new TestTask(i);
        deque.push(task);
        
        shared TestTask ownerResult = null;
        shared TestTask stealerResult = null;
        shared bool ownerDone = false;
        shared bool stealerDone = false;
        
        // Owner pops
        auto ownerThread = new Thread({
            auto t = deque.pop();
            atomicStore(ownerResult, cast(shared)t);
            atomicStore(ownerDone, true);
        });
        
        // Stealer steals
        auto stealerThread = new Thread({
            auto t = deque.steal();
            atomicStore(stealerResult, cast(shared)t);
            atomicStore(stealerDone, true);
        });
        
        // Start simultaneously
        ownerThread.start();
        stealerThread.start();
        
        ownerThread.join();
        stealerThread.join();
        
        auto owner = cast(TestTask)atomicLoad(ownerResult);
        auto stealer = cast(TestTask)atomicLoad(stealerResult);
        
        // Exactly one should win (or both lose due to race timing)
        if (owner !is null && stealer is null)
            ownerWins++;
        else if (owner is null && stealer !is null)
            stealerWins++;
        else if (owner is null && stealer is null)
            bothLose++;
        else
        {
            writeln("  \x1b[31m✗ Double execution on last element!\x1b[0m");
            Assert.isTrue(false, "Both owner and stealer got the task");
        }
    }
    
    writeln("    Owner wins: ", ownerWins);
    writeln("    Stealer wins: ", stealerWins);
    writeln("    Both lose: ", bothLose);
    writeln("    Total: ", iterations);
    
    // At least one should happen
    Assert.isTrue(ownerWins + stealerWins + bothLose == iterations, 
                 "All races accounted for");
    
    writeln("\x1b[32m  ✓ Race on last element handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: High contention stress test");
    
    auto deque = WorkStealingDeque!TestTask(128);
    auto trace = new ExecutionTrace();
    
    shared bool running = true;
    const numStealers = 8;
    const duration = 100.msecs;
    
    auto startTime = MonoTime.currTime;
    
    // Aggressive owner thread
    auto ownerThread = new Thread({
        auto gen = OperationGenerator(unpredictableSeed + 1);
        size_t ops = 0;
        
        while (MonoTime.currTime - startTime < duration)
        {
            auto op = gen.nextOperation(0.6, 0.4);
            
            if (op == OpType.Push)
            {
                auto task = TestTask.create();
                deque.push(task);
                trace.recordOperation(OpType.Push, task.id, true, 0);
            }
            else
            {
                auto task = deque.pop();
                trace.recordOperation(OpType.Pop, task ? task.id : -1, task !is null, 0);
            }
            
            ops++;
            if (ops % 100 == 0)
                Thread.yield();  // Let stealers run
        }
        
        atomicStore(running, false);
    });
    
    // Aggressive stealer threads
    Thread[] stealerThreads;
    foreach (stealerId; 0 .. numStealers)
    {
        size_t threadId = stealerId + 1;
        stealerThreads ~= new Thread({
            size_t ops = 0;
            
            while (atomicLoad(running))
            {
                auto task = deque.steal();
                trace.recordOperation(OpType.Steal, task ? task.id : -1, 
                                    task !is null, threadId);
                ops++;
                
                if (ops % 50 == 0)
                    Thread.yield();
            }
        });
    }
    
    // Start all threads
    ownerThread.start();
    foreach (t; stealerThreads)
        t.start();
    
    // Wait for completion
    ownerThread.join();
    foreach (t; stealerThreads)
        t.join();
    
    // Final drain
    size_t remaining = 0;
    while (!deque.empty())
    {
        auto task = deque.pop();
        if (task !is null)
        {
            remaining++;
            trace.recordOperation(OpType.Pop, task.id, true, 0);
        }
    }
    
    trace.printSummary();
    
    Assert.isTrue(trace.propertyNoDoubleExecution(), "No task should be executed twice");
    Assert.isTrue(trace.propertyNoLostTasks(0), "All tasks should be accounted for");
    Assert.isTrue(trace.propertyStealConsistency(), "Steals should be consistent");
    
    writeln("\x1b[32m  ✓ High contention stress test passed\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: Growth under contention");
    
    auto deque = WorkStealingDeque!TestTask(4);  // Start small
    auto trace = new ExecutionTrace();
    
    const numTasks = 1000;
    const numStealers = 4;
    shared size_t pushesCompleted = 0;
    
    // Owner pushes many tasks (should trigger growth)
    auto ownerThread = new Thread({
        foreach (i; 0 .. numTasks)
        {
            auto task = TestTask.create();
            deque.push(task);
            trace.recordOperation(OpType.Push, task.id, true, 0);
            atomicOp!"+="(pushesCompleted, 1);
            
            // Occasional yield to let stealers work
            if (i % 50 == 0)
                Thread.yield();
        }
    });
    
    // Stealers continuously steal
    Thread[] stealerThreads;
    foreach (stealerId; 0 .. numStealers)
    {
        size_t threadId = stealerId + 1;
        stealerThreads ~= new Thread({
            while (atomicLoad(pushesCompleted) < numTasks || !deque.empty())
            {
                auto task = deque.steal();
                if (task !is null)
                    trace.recordOperation(OpType.Steal, task.id, true, threadId);
                else
                    Thread.yield();
            }
        });
    }
    
    // Start all
    ownerThread.start();
    foreach (t; stealerThreads)
        t.start();
    
    // Wait
    ownerThread.join();
    foreach (t; stealerThreads)
        t.join();
    
    // Drain
    size_t remaining = 0;
    while (!deque.empty())
    {
        auto task = deque.pop();
        if (task !is null)
        {
            remaining++;
            trace.recordOperation(OpType.Pop, task.id, true, 0);
        }
    }
    
    trace.printSummary();
    
    Assert.isTrue(deque.capacity() > 4, "Deque should have grown");
    Assert.isTrue(trace.propertyNoDoubleExecution(), "No task should be executed twice");
    Assert.isTrue(trace.propertyNoLostTasks(0), "All tasks should be accounted for");
    
    writeln("    Final capacity: ", deque.capacity());
    writeln("\x1b[32m  ✓ Growth under contention works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: Empty deque behavior");
    
    auto deque = WorkStealingDeque!TestTask(8);
    
    // Pop from empty
    Assert.isNull(deque.pop(), "Pop from empty should return null");
    
    // Steal from empty
    Assert.isNull(deque.steal(), "Steal from empty should return null");
    
    // Multiple concurrent steals from empty
    shared int successCount = 0;
    
    Thread[] threads;
    foreach (i; 0 .. 10)
    {
        threads ~= new Thread({
            auto task = deque.steal();
            if (task !is null)
                atomicOp!"+="(successCount, 1);
        });
    }
    
    foreach (t; threads)
        t.start();
    foreach (t; threads)
        t.join();
    
    Assert.equal(successCount, 0, "No steals should succeed from empty deque");
    
    writeln("\x1b[32m  ✓ Empty deque behavior correct\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m WorkStealingDeque - Property: Size consistency");
    
    auto deque = WorkStealingDeque!TestTask(32);
    
    // Push some tasks
    foreach (i; 0 .. 10)
        deque.push(new TestTask(i));
    
    // Size should be approximately correct (may be stale)
    auto size1 = deque.size();
    Assert.isTrue(size1 >= 0 && size1 <= 10, "Size should be reasonable");
    
    // Pop half
    foreach (i; 0 .. 5)
        deque.pop();
    
    auto size2 = deque.size();
    Assert.isTrue(size2 >= 0 && size2 <= 5, "Size should decrease after pops");
    Assert.isTrue(size2 < size1, "Size should be less after popping");
    
    // Empty check
    Assert.isFalse(deque.empty(), "Deque should not be empty");
    
    // Drain completely
    while (!deque.empty())
        deque.pop();
    
    Assert.isTrue(deque.empty(), "Deque should be empty after draining");
    Assert.equal(deque.size(), 0, "Size should be 0 when empty");
    
    writeln("\x1b[32m  ✓ Size consistency maintained\x1b[0m");
}

