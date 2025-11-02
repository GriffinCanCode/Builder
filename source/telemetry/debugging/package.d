module telemetry.debugging;

/// Build debugging subsystem
/// 
/// This module provides build recording and replay capabilities for deterministic
/// debugging and time-travel debugging of build failures.
/// 
/// Components:
/// - BuildRecorder: Record complete build state
/// - ReplayEngine: Replay recorded builds
/// - DiffAnalyzer: Compare build recordings

public import telemetry.debugging.replay;

