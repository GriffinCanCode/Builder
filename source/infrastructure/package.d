/**
 * Infrastructure Package - Core Infrastructure & Support Systems
 * 
 * This package contains the foundational infrastructure and support systems
 * that enable the build system to function.
 * 
 * Modules:
 * - config: Configuration parsing, DSL, scripting, workspace management
 * - analysis: Dependency resolution, scanning, detection, inference
 * - repository: Repository management and artifact fetching
 * - toolchain: Unified toolchain detection and management
 * - errors: Type-safe error handling with Result types
 * - telemetry: Build telemetry, tracing, and observability
 * - utils: Common utilities (files, crypto, concurrency, SIMD)
 * - plugins: Plugin system and SDK
 * - migration: Build system migration tools
 * - tools: Miscellaneous development tools
 */
module infrastructure;

public import infrastructure.config;
public import infrastructure.analysis;
public import infrastructure.repository;
public import infrastructure.toolchain;
public import infrastructure.errors;
public import infrastructure.telemetry;
public import infrastructure.utils;
public import infrastructure.plugins;
public import infrastructure.migration;
public import infrastructure.tools;

