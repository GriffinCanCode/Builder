module engine.distributed.worker.worker;

import std.datetime : Duration, Clock, seconds, msecs;
import core.time : MonoTime;
import std.algorithm : remove;
import std.random : uniform;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.protocol : NetworkError;
import engine.distributed.protocol.transport;
import engine.distributed.protocol.messages;
import infrastructure.utils.concurrency.deque : WorkStealingDeque;
import engine.distributed.worker.peers;
import engine.distributed.worker.steal;
import engine.distributed.memory;
import engine.distributed.metrics.steal : StealTelemetry;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

// Import split modules
public import engine.distributed.worker.lifecycle;
public import engine.distributed.worker.execution;
public import engine.distributed.worker.communication;

/// Build worker (executes actions)
final class Worker
{
    private WorkerLifecycle lifecycle;
    private WorkerExecutor executor;
    private WorkerCommunication communication;
    
    private Thread mainThread;
    private Thread heartbeatThread;
    private Thread peerAnnounceThread;
    
    this(WorkerConfig config) @trusted
    {
        lifecycle.initialize(config);
    }
    
    /// Start worker
    Result!DistributedError start() @trusted
    {
        auto startResult = lifecycle.start();
        if (startResult.isErr)
            return startResult;
        
        // Start main loop
        mainThread = new Thread(&mainLoop);
        mainThread.start();
        lifecycle.setMainThread(mainThread);
        
        // Start heartbeat
        heartbeatThread = new Thread(&heartbeatLoop);
        heartbeatThread.start();
        lifecycle.setHeartbeatThread(heartbeatThread);
        
        // Start peer announce (if work-stealing enabled)
        if (lifecycle.getConfig().enableWorkStealing)
        {
            peerAnnounceThread = new Thread(&peerAnnounceLoop);
            peerAnnounceThread.start();
            lifecycle.setPeerAnnounceThread(peerAnnounceThread);
        }
        
        return Ok!DistributedError();
    }
    
    /// Stop worker
    void stop() @trusted
    {
        lifecycle.stop();
    }
    
    /// Main worker loop
    private void mainLoop() @trusted
    {
        size_t consecutiveIdle = 0;
        auto config = lifecycle.getConfig();
        
        while (lifecycle.isRunning())
        {
            // 1. Try local work first
            auto ref localQueue = lifecycle.getLocalQueue();
            auto localAction = localQueue.pop();
            if (localAction !is null)
            {
                executeAction(localAction);
                consecutiveIdle = 0;
                continue;
            }
            
            // 2. Request work from coordinator
            auto coordinatorAction = communication.requestWork(
                lifecycle.getId(),
                lifecycle.getCoordinatorTransport()
            );
            if (coordinatorAction !is null)
            {
                executeAction(coordinatorAction);
                consecutiveIdle = 0;
                continue;
            }
            
            // 3. Try stealing from peers (if enabled)
            if (config.enableWorkStealing)
            {
                auto stealEngine = lifecycle.getStealEngine();
                auto stealTelemetry = lifecycle.getStealTelemetry();
                
                if (stealEngine !is null)
                {
                    auto startTime = MonoTime.currTime;
                    auto stolenAction = stealEngine.steal(lifecycle.getCoordinatorTransport());
                    auto latency = MonoTime.currTime - startTime;
                    
                    if (stolenAction !is null)
                    {
                        if (stealTelemetry !is null)
                            stealTelemetry.recordAttempt(WorkerId(0), latency, true);
                        executeAction(stolenAction);
                        consecutiveIdle = 0;
                        continue;
                    }
                    else
                    {
                        if (stealTelemetry !is null)
                            stealTelemetry.recordAttempt(WorkerId(0), latency, false);
                    }
                }
            }
            
            // 4. No work available, backoff
            consecutiveIdle++;
            lifecycle.backoff(consecutiveIdle);
        }
    }
    
    /// Execute build action (delegates to executor)
    private void executeAction(ActionRequest request) @trusted
    {
        lifecycle.setState(WorkerState.Executing);
        
        auto config = lifecycle.getConfig();
        executor.executeAction(
            request,
            config.enableSandboxing,
            config.defaultCapabilities,
            (ActionResult result) @trusted {
                communication.sendResult(
                    lifecycle.getId(),
                    result,
                    lifecycle.getCoordinatorTransport()
                );
            }
        );
        
        lifecycle.setState(WorkerState.Idle);
    }
    
    /// Heartbeat loop
    private void heartbeatLoop() @trusted
    {
        auto config = lifecycle.getConfig();
        auto runningPtr = lifecycle.getRunningPtr();
        
        communication.heartbeatLoop(
            lifecycle.getId(),
            runningPtr,
            () @trusted => lifecycle.getState(),
            () @trusted => lifecycle.getMetrics(),
            lifecycle.getCoordinatorTransport(),
            config.heartbeatInterval
        );
    }
    
    /// Peer announce loop
    private void peerAnnounceLoop() @trusted
    {
        auto config = lifecycle.getConfig();
        auto runningPtr = lifecycle.getRunningPtr();
        auto ref localQueue = lifecycle.getLocalQueue();
        
        communication.peerAnnounceLoop(
            lifecycle.getId(),
            runningPtr,
            config.listenAddress,
            localQueue,
            () @trusted => communication.calculateLoadFactor(
                localQueue.size(),
                config.localQueueSize,
                lifecycle.getState(),
                config.maxConcurrentActions
            ),
            lifecycle.getPeerRegistry(),
            lifecycle.getCoordinatorTransport(),
            config.peerAnnounceInterval
        );
    }
}
