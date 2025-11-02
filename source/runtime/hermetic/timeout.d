module runtime.hermetic.timeout;

import std.datetime : Duration;
import core.time : MonoTime;
import core.thread : Thread;
import core.atomic : atomicStore, atomicLoad;
import errors;

/// Timeout enforcement for hermetic execution
/// 
/// Design: Platform-agnostic timeout using cooperative monitoring
/// - Spawns watchdog thread to monitor execution time
/// - Can forcefully terminate process on timeout
/// - Provides grace period for cleanup
/// 
/// This ensures builds don't hang indefinitely
interface TimeoutEnforcer
{
    /// Start timeout watchdog
    void start(Duration timeout) @safe;
    
    /// Stop timeout watchdog (execution completed)
    void stop() @safe;
    
    /// Check if timeout was exceeded
    bool isTimedOut() @safe;
    
    /// Get remaining time
    Duration remaining() @safe;
}

/// Base timeout enforcer with shared logic
abstract class BaseTimeoutEnforcer : TimeoutEnforcer
{
    protected Duration timeout;
    protected MonoTime startTime;
    protected bool started = false;
    protected bool timedOut = false;
    protected Thread watchdog;
    
    void start(Duration timeout_) @safe
    {
        this.timeout = timeout_;
        this.startTime = MonoTime.currTime;
        this.started = true;
        this.timedOut = false;
    }
    
    void stop() @safe
    {
        started = false;
        if (watchdog !is null)
        {
            // Watchdog will exit on next check
        }
    }
    
    bool isTimedOut() @safe
    {
        return timedOut;
    }
    
    Duration remaining() @safe
    {
        if (!started)
            return timeout;
        
        auto elapsed = MonoTime.currTime - startTime;
        auto remaining = timeout - elapsed;
        
        return remaining > Duration.zero ? remaining : Duration.zero;
    }
    
    /// Mark as timed out
    protected void markTimedOut() @safe
    {
        timedOut = true;
    }
}

/// Process-based timeout enforcer
/// Terminates the process when timeout is exceeded
final class ProcessTimeoutEnforcer : BaseTimeoutEnforcer
{
    private int pid;
    private shared bool running = false;
    
    this(int pid) @safe
    {
        this.pid = pid;
    }
    
    override void start(Duration timeout_) @trusted
    {
        super.start(timeout_);
        
        atomicStore(running, true);
        
        // Start watchdog thread
        watchdog = new Thread(&watchdogLoop);
        watchdog.start();
    }
    
    override void stop() @trusted
    {
        super.stop();
        atomicStore(running, false);
        
        if (watchdog !is null)
        {
            watchdog.join();
            watchdog = null;
        }
    }
    
    /// Watchdog loop - monitors timeout and kills process
    private void watchdogLoop() @trusted nothrow
    {
        import core.thread : Thread;
        import std.datetime : dur;
        
        try
        {
            while (atomicLoad(running) && !timedOut)
            {
                // Check if timeout exceeded
                auto elapsed = MonoTime.currTime - startTime;
                if (elapsed >= timeout)
                {
                    markTimedOut();
                    killProcess(pid);
                    break;
                }
                
                // Sleep for a short interval
                Thread.sleep(dur!"msecs"(100));
            }
        }
        catch (Exception) {}
    }
    
    /// Kill process by PID
    private static void killProcess(int pid) @trusted nothrow
    {
        version(Posix)
        {
            import core.sys.posix.signal : kill, SIGKILL;
            try
            {
                kill(pid, SIGKILL);
            }
            catch (Exception) {}
        }
        else version(Windows)
        {
            import core.sys.windows.windows : OpenProcess, TerminateProcess, CloseHandle;
            import core.sys.windows.windows : PROCESS_TERMINATE, STILL_ACTIVE;
            
            try
            {
                auto hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
                if (hProcess !is null)
                {
                    TerminateProcess(hProcess, STILL_ACTIVE);
                    CloseHandle(hProcess);
                }
            }
            catch (Exception) {}
        }
    }
}

/// No-op timeout enforcer (for testing)
final class NoOpTimeoutEnforcer : BaseTimeoutEnforcer
{
    override void start(Duration timeout_) @safe
    {
        super.start(timeout_);
    }
    
    override void stop() @safe
    {
        super.stop();
    }
}

/// Create appropriate timeout enforcer
TimeoutEnforcer createTimeoutEnforcer(int pid = 0) @safe
{
    if (pid > 0)
        return new ProcessTimeoutEnforcer(pid);
    else
        return new NoOpTimeoutEnforcer();
}

@safe unittest
{
    import std.datetime : seconds;
    
    // Test NoOpTimeoutEnforcer
    auto enforcer = new NoOpTimeoutEnforcer();
    enforcer.start(1.seconds);
    
    assert(!enforcer.isTimedOut());
    assert(enforcer.remaining() > Duration.zero);
    
    enforcer.stop();
}

