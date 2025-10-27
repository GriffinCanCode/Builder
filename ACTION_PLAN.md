# Builder Technical Debt - Action Plan

**Created**: October 27, 2025  
**Priority**: Systematic debt reduction  
**Target**: 9.0/10 code quality by Q1 2026

---

## 🎯 Vision

Transform Builder from **"excellent with gaps"** to **"industry-leading"** by addressing:
1. Test coverage (16% → 60%+)
2. Error handling consistency (60% → 95% Result-based)
3. Architecture refinements (DI, context pattern)

---

## Phase 1: Foundation (Weeks 1-2) - 10 days

### Week 1: Assessment & Planning

**Day 1-2: Test Infrastructure**
- [ ] Audit existing test coverage with coverage tools
- [ ] Identify critical untested paths
- [ ] Create test templates for each language handler
- [ ] Set up continuous coverage tracking

**Day 3-4: Error Handling Audit**
- [ ] Map all exception throw sites
- [ ] Identify exception catching patterns
- [ ] Document error propagation paths
- [ ] Create migration guide for Result types

**Day 5: Security Review**
- [ ] Review all @trusted blocks (347 instances)
- [ ] Document safety assumptions
- [ ] Identify candidates for @safe alternatives
- [ ] Create security checklist

### Week 2: Quick Wins

**Day 6-7: Magic Numbers Cleanup**
- [ ] Find all magic numbers in codebase
- [ ] Create constants module
- [ ] Replace with named constants:
  ```d
  // source/core/constants.d
  module core.constants;
  
  enum BuildDefaults {
      AverageDependencyCount = 8,
      AverageDependentCount = 4,
      TerminalBufferSize = 8192,
      DefaultTokenEstimate = 6,
      MaxParallelJobs = 16
  }
  ```

**Day 8-10: Documentation**
- [ ] Add DDoc comments to public APIs
- [ ] Create troubleshooting guide
- [ ] Write contributing guidelines
- [ ] Add architecture diagrams

**Deliverables Week 1-2**:
- ✅ Test coverage baseline
- ✅ Error handling migration plan
- ✅ Security documentation
- ✅ Named constants module

---

## Phase 2: Test Coverage (Weeks 3-6) - 20 days

### Week 3: Core Systems

**Day 11-13: Graph & Execution Tests**
- [ ] Test circular dependency detection
- [ ] Test topological sorting edge cases
- [ ] Test parallel execution scenarios
- [ ] Test build cancellation
- [ ] Test retry logic

**Day 14-15: Cache Tests**
- [ ] Test cache invalidation
- [ ] Test integrity validation
- [ ] Test concurrent cache access
- [ ] Test eviction policies

### Week 4: Language Handlers (Part 1)

**Day 16-17: Python Handler**
- [ ] Test virtual environment creation
- [ ] Test pip dependency resolution
- [ ] Test pytest/unittest integration
- [ ] Test various Python versions

**Day 18-19: JavaScript/TypeScript**
- [ ] Test bundler selection (esbuild, webpack, rollup)
- [ ] Test npm/yarn/pnpm
- [ ] Test type checking (tsc)
- [ ] Test JSX/TSX compilation

**Day 20: Go Handler**
- [ ] Test go modules
- [ ] Test CGO builds
- [ ] Test cross-compilation
- [ ] Test plugin builds

### Week 5: Language Handlers (Part 2)

**Day 21: Rust Handler**
- [ ] Test cargo integration
- [ ] Test workspace projects
- [ ] Test feature flags
- [ ] Test target specifications

**Day 22: JVM Handlers (Java/Kotlin/Scala)**
- [ ] Test Maven/Gradle integration
- [ ] Test multi-module projects
- [ ] Test JAR/WAR packaging
- [ ] Test native compilation (GraalVM)

**Day 23: .NET Handlers (C#/F#)**
- [ ] Test dotnet restore/build
- [ ] Test NuGet packages
- [ ] Test multi-target frameworks
- [ ] Test AOT compilation

**Day 24-25: Other Handlers**
- [ ] Test remaining handlers (Ruby, PHP, Lua, R, etc.)
- [ ] Integration tests between languages
- [ ] Cross-language dependency tests

### Week 6: Integration & Edge Cases

**Day 26-27: Integration Tests**
- [ ] Test full monorepo scenarios
- [ ] Test incremental builds
- [ ] Test clean builds
- [ ] Test workspace switching

**Day 28-30: Edge Cases**
- [ ] Test error recovery
- [ ] Test file system errors
- [ ] Test network failures
- [ ] Test missing tools
- [ ] Test malformed configs

**Deliverables Week 3-6**:
- ✅ Test coverage at 40%+
- ✅ All core systems tested
- ✅ All language handlers tested
- ✅ Integration test suite

**Milestone**: Code coverage ≥ 40%

---

## Phase 3: Error Handling (Weeks 7-9) - 15 days

### Week 7: Exception Migration

**Day 31-33: Core Modules**
- [ ] Migrate `source/core/graph/graph.d`
  ```d
  // Before
  void addDependency(string from, string to) {
      throw new Exception(...);
  }
  
  // After
  Result!(void, BuildError) addDependency(string from, string to) {
      if (from !in nodes)
          return Err!BuildError(new GraphError(...));
      return Ok!BuildError();
  }
  ```

**Day 34-35: Config & Parsing**
- [ ] Migrate `source/config/parsing/parser.d`
- [ ] Migrate `source/config/workspace/workspace.d`
- [ ] Update error propagation

### Week 8: Analysis & Execution

**Day 36-38: Analysis Modules**
- [ ] Migrate `source/analysis/inference/analyzer.d`
  - Replace 9 `catch (Exception)` blocks
  - Add proper error context
- [ ] Migrate `source/analysis/detection/detector.d`
- [ ] Migrate `source/analysis/resolution/resolver.d`

**Day 39-40: Execution**
- [ ] Review `source/core/execution/executor.d`
- [ ] Ensure all errors are Result-based
- [ ] Add retry logic for transient failures

### Week 9: Language Handlers

**Day 41-45: Handler Error Migration**
- [ ] Migrate language handler error paths
- [ ] Remove bare `catch (Exception)` blocks
- [ ] Add context to all errors
- [ ] Test error propagation

**Deliverables Week 7-9**:
- ✅ 95% Result-based error handling
- ✅ All exceptions documented
- ✅ Error context everywhere
- ✅ Predictable error paths

**Milestone**: Error handling consistency ≥ 95%

---

## Phase 4: Architecture (Weeks 10-12) - 15 days

### Week 10: Build Context Pattern

**Day 46-47: Context Design**
- [ ] Design BuildContext interface
  ```d
  // source/core/context/context.d
  final class BuildContext {
      private WorkspaceConfig _config;
      private ICacheManager _cache;
      private IEventPublisher _events;
      private SIMDCapabilities _simd;
      private ILogger _logger;
      
      // Factory methods
      IAnalyzer createAnalyzer();
      IExecutor createExecutor(BuildGraph graph);
  }
  ```

**Day 48-50: Implement Context**
- [ ] Create BuildContext class
- [ ] Add dependency factories
- [ ] Thread context through main
- [ ] Update all component constructors

### Week 11: Dependency Injection

**Day 51-52: Interface Extraction**
- [ ] Extract interfaces from concrete classes
  - IAnalyzer
  - IExecutor
  - ICacheManager
  - IEventPublisher
- [ ] Update implementations

**Day 53-55: Context Integration**
- [ ] Replace global state with context
- [ ] Update app.d to use context
- [ ] Update tests to use context
- [ ] Remove global SIMD initialization

### Week 12: Type Safety

**Day 56-57: TargetId Type**
- [ ] Create TargetId struct
  ```d
  struct TargetId {
      string workspace;
      string path;
      string name;
      
      static TargetId parse(string id);
      string toString() const;
  }
  ```

**Day 58-60: Migrate to TargetId**
- [ ] Replace string IDs with TargetId
- [ ] Update BuildGraph to use TargetId
- [ ] Update all ID comparisons
- [ ] Add validation

**Deliverables Week 10-12**:
- ✅ BuildContext pattern implemented
- ✅ Dependency injection working
- ✅ Type-safe identifiers
- ✅ No global state

**Milestone**: Clean architecture with DI

---

## Phase 5: Polish (Weeks 13-16) - 20 days

### Week 13: Large File Refactoring

**Day 61-63: Split Large Files**
- [ ] `source/utils/files/ignore.d` (922 lines)
  - Extract pattern matching
  - Extract file operations
  - Extract gitignore logic
- [ ] `source/config/workspace/workspace.d` (645 lines)
  - Extract parser
  - Extract analyzer
  - Extract workspace management

**Day 64-65: Code Organization**
- [ ] Review module structure
- [ ] Consolidate related functionality
- [ ] Improve package.d exports

### Week 14: Security Hardening

**Day 66-67: Supply Chain**
- [ ] Add tool verification
  ```d
  struct ToolVerifier {
      Result!(void, SecurityError) verifyTool(string path) {
          // Check signature/checksum
          // Verify against known-good hashes
      }
  }
  ```

**Day 68-70: Security Testing**
- [ ] Test path traversal prevention
- [ ] Test command injection prevention
- [ ] Test cache tampering detection
- [ ] Penetration testing

### Week 15: Performance Optimization

**Day 71-72: Build Graph Caching**
- [ ] Implement graph serialization
  ```d
  void saveBuildGraph(BuildGraph graph, string path);
  BuildGraph loadBuildGraph(string path);
  ```
- [ ] Add cache invalidation logic

**Day 73-74: Cache Warming**
- [ ] Implement preemptive cache loading
- [ ] Add intelligent prefetching
- [ ] Benchmark improvements

**Day 75: Parallel Analysis**
- [ ] Parallelize independent subgraph analysis
- [ ] Measure speedup

### Week 16: Documentation & Release

**Day 76-77: API Documentation**
- [ ] Generate DDoc for all public APIs
- [ ] Create API reference guide
- [ ] Add usage examples

**Day 78-79: User Guides**
- [ ] Write troubleshooting guide
- [ ] Create performance tuning guide
- [ ] Add migration guides

**Day 80: Release Preparation**
- [ ] Final code review
- [ ] Update changelog
- [ ] Create release notes
- [ ] Tag version

**Deliverables Week 13-16**:
- ✅ Refactored large files
- ✅ Enhanced security
- ✅ Performance optimizations
- ✅ Complete documentation

**Milestone**: Production-ready release

---

## Success Metrics

### Phase Completion Criteria

| Phase | Metric | Target | Current | Success |
|-------|--------|--------|---------|---------|
| Phase 1 | Planning | 100% | 0% | Documentation complete |
| Phase 2 | Test Coverage | 40%+ | 16% | Coverage tool reports |
| Phase 3 | Result-based | 95%+ | 60% | Exception audit |
| Phase 4 | DI Pattern | 100% | 0% | Context threaded |
| Phase 5 | Quality | 9.0/10 | 7.8/10 | Final review |

### Continuous Metrics

Track weekly:
- [ ] Test coverage percentage
- [ ] Number of `catch (Exception)` blocks
- [ ] Number of `@trusted` without docs
- [ ] Number of magic numbers
- [ ] Build performance benchmarks

---

## Risk Mitigation

### Risk 1: Breaking Changes
**Mitigation**: 
- Keep old APIs during migration
- Add deprecation warnings
- Comprehensive testing before removal

### Risk 2: Performance Regression
**Mitigation**:
- Benchmark before/after changes
- Performance tests in CI
- Rollback plan ready

### Risk 3: Scope Creep
**Mitigation**:
- Strict phase boundaries
- No new features during debt reduction
- Weekly progress reviews

---

## Resource Requirements

### Time Commitment
- **Full-time**: 16 weeks (4 months)
- **Part-time** (50%): 32 weeks (8 months)
- **Maintenance** (20%): 80 weeks (18 months)

### Skills Needed
- D language expertise (required)
- Testing best practices (required)
- Security knowledge (helpful)
- Architecture patterns (helpful)

---

## Checkpoints & Reviews

### Weekly (Every Friday)
- Review metrics dashboard
- Assess progress vs. plan
- Adjust priorities if needed

### Phase End (Every 4 weeks)
- Milestone review
- Stakeholder demo
- Go/no-go decision for next phase

### Final Review (Week 16)
- Code quality assessment
- Performance benchmarks
- Security audit
- Release decision

---

## Post-Completion Maintenance

### Ongoing (After Week 16)
- **Daily**: Run tests, check coverage
- **Weekly**: Review new PRs for quality
- **Monthly**: Update dependencies
- **Quarterly**: Full code audit
- **Yearly**: Architecture review

### Continuous Improvement
- [ ] Keep test coverage > 60%
- [ ] Maintain error handling standards
- [ ] Document all @trusted blocks
- [ ] No magic numbers in new code
- [ ] Performance regression monitoring

---

## Next Steps

### This Week (Week 1)
1. ✅ Complete tech debt evaluation (DONE)
2. ⏳ Set up coverage tracking
3. ⏳ Audit @trusted blocks
4. ⏳ Create constants module

### This Month (Weeks 1-4)
1. ⏳ Complete Phase 1 (Foundation)
2. ⏳ Start Phase 2 (Test Coverage)
3. ⏳ Reach 25% test coverage
4. ⏳ Document 50% of @trusted blocks

### This Quarter (Weeks 1-12)
1. ⏳ Complete Phases 1-4
2. ⏳ Reach 40% test coverage
3. ⏳ Achieve 95% Result-based errors
4. ⏳ Implement BuildContext pattern

---

**Owner**: Development Team  
**Sponsor**: Project Lead  
**Start Date**: November 1, 2025  
**Target Completion**: February 28, 2026  
**Status**: 📋 Planned

