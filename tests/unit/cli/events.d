module tests.unit.cli.events;

import tests.harness;
import frontend.cli.events.events;
import std.datetime : dur;

/// Test build started event
void testBuildStartedEvent()
{
    auto event = new BuildStartedEvent(10, 4, dur!"seconds"(0));
    
    Assert.equal(event.type, EventType.BuildStarted);
    Assert.equal(event.totalTargets, 10);
    Assert.equal(event.maxParallelism, 4);
}

/// Test build completed event
void testBuildCompletedEvent()
{
    auto event = new BuildCompletedEvent(8, 2, 0, dur!"seconds"(30), dur!"seconds"(30));
    
    Assert.equal(event.type, EventType.BuildCompleted);
    Assert.equal(event.built, 8);
    Assert.equal(event.cached, 2);
    Assert.equal(event.failed, 0);
}

/// Test build failed event
void testBuildFailedEvent()
{
    auto event = new BuildFailedEvent("compilation error", 2, dur!"seconds"(10), dur!"seconds"(10));
    
    Assert.equal(event.type, EventType.BuildFailed);
    Assert.equal(event.failedCount, 2);
    Assert.equal(event.reason, "compilation error");
}

/// Test target started event
void testTargetStartedEvent()
{
    auto event = new TargetStartedEvent("//src:lib", 5, 10, dur!"seconds"(0));
    
    Assert.equal(event.type, EventType.TargetStarted);
    Assert.equal(event.targetId, "//src:lib");
    Assert.equal(event.index, 5);
    Assert.equal(event.total, 10);
}

/// Test target completed event
void testTargetCompletedEvent()
{
    auto event = new TargetCompletedEvent("//src:lib", dur!"msecs"(123), 1024, dur!"msecs"(123));
    
    Assert.equal(event.type, EventType.TargetCompleted);
    Assert.equal(event.targetId, "//src:lib");
    Assert.equal(event.outputSize, 1024);
}

/// Test target failed event
void testTargetFailedEvent()
{
    auto event = new TargetFailedEvent("//src:lib", "syntax error", dur!"msecs"(50), dur!"msecs"(50));
    
    Assert.equal(event.type, EventType.TargetFailed);
    Assert.equal(event.targetId, "//src:lib");
    Assert.equal(event.error, "syntax error");
}

/// Test target cached event
void testTargetCachedEvent()
{
    auto event = new TargetCachedEvent("//src:lib", dur!"msecs"(5));
    
    Assert.equal(event.type, EventType.TargetCached);
    Assert.equal(event.targetId, "//src:lib");
}

/// Test message event with different severities
void testMessageEvent()
{
    auto info = new MessageEvent("Info msg", Severity.Info, "", dur!"seconds"(0));
    Assert.equal(info.type, EventType.Message);
    Assert.equal(info.severity, Severity.Info);
    
    auto warning = new MessageEvent("Warn msg", Severity.Warning, "", dur!"seconds"(0));
    Assert.equal(warning.severity, Severity.Warning);
    
    auto error = new MessageEvent("Error msg", Severity.Error, "target1", dur!"seconds"(0));
    Assert.equal(error.severity, Severity.Error);
    Assert.equal(error.targetId, "target1");
}

/// Test statistics event
void testStatisticsEvent()
{
    CacheStats cacheStats;
    cacheStats.hits = 50;
    cacheStats.misses = 10;
    cacheStats.hitRate = 83.3;
    
    BuildStats buildStats;
    buildStats.totalTargets = 100;
    buildStats.completedTargets = 90;
    
    auto event = new StatisticsEvent(cacheStats, buildStats, dur!"seconds"(0));
    
    Assert.equal(event.type, EventType.Statistics);
    Assert.equal(event.cacheStats.hits, 50);
    Assert.equal(event.buildStats.totalTargets, 100);
}

/// Test target progress event
void testTargetProgressEvent()
{
    auto event = new TargetProgressEvent("//src:lib", "compiling", 0.5, dur!"seconds"(5));
    
    Assert.equal(event.type, EventType.TargetProgress);
    Assert.equal(event.targetId, "//src:lib");
    Assert.equal(event.phase, "compiling");
    Assert.isTrue(event.progress > 0.49 && event.progress < 0.51);
}

/// Test simple event publisher
void testSimpleEventPublisher()
{
    auto publisher = new SimpleEventPublisher();
    
    bool receivedEvent = false;
    
    class TestSubscriber : EventSubscriber
    {
        bool* flag;
        
        this(bool* flag)
        {
            this.flag = flag;
        }
        
        void onEvent(BuildEvent event)
        {
            *flag = true;
        }
    }
    
    auto subscriber = new TestSubscriber(&receivedEvent);
    publisher.subscribe(subscriber);
    
    auto event = new BuildStartedEvent(1, 1, dur!"seconds"(0));
    publisher.publish(event);
    
    Assert.isTrue(receivedEvent, "Subscriber should receive event");
}

/// Test publisher unsubscribe
void testPublisherUnsubscribe()
{
    auto publisher = new SimpleEventPublisher();
    
    int eventCount = 0;
    
    class CountingSubscriber : EventSubscriber
    {
        int* counter;
        
        this(int* counter)
        {
            this.counter = counter;
        }
        
        void onEvent(BuildEvent event)
        {
            (*counter)++;
        }
    }
    
    auto subscriber = new CountingSubscriber(&eventCount);
    publisher.subscribe(subscriber);
    
    auto event1 = new BuildStartedEvent(1, 1, dur!"seconds"(0));
    publisher.publish(event1);
    Assert.equal(eventCount, 1);
    
    publisher.unsubscribe(subscriber);
    
    auto event2 = new BuildStartedEvent(1, 1, dur!"seconds"(0));
    publisher.publish(event2);
    Assert.equal(eventCount, 1, "Should not receive event after unsubscribe");
}