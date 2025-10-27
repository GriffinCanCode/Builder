module tests.unit.core.graph;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import core.graph.graph;
import config.schema.schema;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Node creation and basic properties");
    
    auto target = TargetBuilder.create("test-target")
        .withType(TargetType.Executable)
        .withSources(["main.d"])
        .build();
    
    auto node = new BuildNode("test-target", target);
    
    Assert.equal(node.id, "test-target");
    Assert.equal(node.status, BuildStatus.Pending);
    Assert.isEmpty(node.dependencies);
    Assert.equal(node.depth(), 0);
    
    writeln("\x1b[32m  ✓ Node creation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Dependency relationships");
    
    auto graph = new BuildGraph();
    
    auto target1 = TargetBuilder.create("lib").withType(TargetType.Library).build();
    auto target2 = TargetBuilder.create("app").withType(TargetType.Executable).build();
    
    graph.addTarget(target1);
    graph.addTarget(target2);
    graph.addDependency("app", "lib");
    
    auto appNode = graph.nodes["app"];
    auto libNode = graph.nodes["lib"];
    
    Assert.equal(appNode.dependencies.length, 1);
    Assert.equal(appNode.dependencies[0].id, "lib");
    Assert.equal(libNode.dependents.length, 1);
    Assert.equal(libNode.dependents[0].id, "app");
    
    writeln("\x1b[32m  ✓ Dependencies link correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Topological sort");
    
    auto graph = new BuildGraph();
    
    // Create: lib1 <- app <- exe
    auto lib1 = TargetBuilder.create("lib1").build();
    auto app = TargetBuilder.create("app").build();
    auto exe = TargetBuilder.create("exe").build();
    
    graph.addTarget(lib1);
    graph.addTarget(app);
    graph.addTarget(exe);
    graph.addDependency("app", "lib1");
    graph.addDependency("exe", "app");
    
    auto sorted = graph.topologicalSort();
    
    Assert.equal(sorted.length, 3);
    
    // lib1 should come before app, app before exe
    auto lib1Idx = sorted.countUntil!(n => n.id == "lib1");
    auto appIdx = sorted.countUntil!(n => n.id == "app");
    auto exeIdx = sorted.countUntil!(n => n.id == "exe");
    
    Assert.isTrue(lib1Idx < appIdx);
    Assert.isTrue(appIdx < exeIdx);
    
    writeln("\x1b[32m  ✓ Topological sort produces correct order\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Cycle detection");
    
    auto graph = new BuildGraph();
    
    auto target1 = TargetBuilder.create("a").build();
    auto target2 = TargetBuilder.create("b").build();
    
    graph.addTarget(target1);
    graph.addTarget(target2);
    
    // Create cycle: a -> b -> a
    graph.addDependency("a", "b");
    
    void addCycle() { graph.addDependency("b", "a"); }
    Assert.throws!Exception(addCycle());
    
    writeln("\x1b[32m  ✓ Cycle detection prevents circular dependencies\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Node depth calculation");
    
    auto graph = new BuildGraph();
    
    // Create chain: a -> b -> c
    auto a = TargetBuilder.create("a").build();
    auto b = TargetBuilder.create("b").build();
    auto c = TargetBuilder.create("c").build();
    
    graph.addTarget(a);
    graph.addTarget(b);
    graph.addTarget(c);
    graph.addDependency("b", "a");
    graph.addDependency("c", "b");
    
    Assert.equal(graph.nodes["a"].depth(), 0);
    Assert.equal(graph.nodes["b"].depth(), 1);
    Assert.equal(graph.nodes["c"].depth(), 2);
    
    writeln("\x1b[32m  ✓ Node depth calculated correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Ready nodes detection");
    
    auto graph = new BuildGraph();
    
    auto lib = TargetBuilder.create("lib").build();
    auto app = TargetBuilder.create("app").build();
    
    graph.addTarget(lib);
    graph.addTarget(app);
    graph.addDependency("app", "lib");
    
    // Initially only lib is ready
    auto ready1 = graph.getReadyNodes();
    Assert.equal(ready1.length, 1);
    Assert.equal(ready1[0].id, "lib");
    
    // After lib succeeds, app becomes ready
    graph.nodes["lib"].status = BuildStatus.Success;
    auto ready2 = graph.getReadyNodes();
    Assert.equal(ready2.length, 1);
    Assert.equal(ready2[0].id, "app");
    
    writeln("\x1b[32m  ✓ Ready nodes detected correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Graph statistics");
    
    auto graph = new BuildGraph();
    
    auto a = TargetBuilder.create("a").build();
    auto b = TargetBuilder.create("b").build();
    auto c = TargetBuilder.create("c").build();
    
    graph.addTarget(a);
    graph.addTarget(b);
    graph.addTarget(c);
    graph.addDependency("b", "a");
    graph.addDependency("c", "a");
    
    auto stats = graph.getStats();
    
    Assert.equal(stats.totalNodes, 3);
    Assert.equal(stats.totalEdges, 2);
    Assert.equal(stats.maxDepth, 1);
    Assert.equal(stats.parallelism, 2); // b and c can build in parallel
    
    writeln("\x1b[32m  ✓ Graph statistics calculated correctly\x1b[0m");
}

// ==================== ADVANCED GRAPH TESTS ====================

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Complex cycle detection (indirect)");
    
    auto graph = new BuildGraph();
    
    // Create chain: a -> b -> c -> a (indirect cycle)
    auto a = TargetBuilder.create("a").build();
    auto b = TargetBuilder.create("b").build();
    auto c = TargetBuilder.create("c").build();
    
    graph.addTarget(a);
    graph.addTarget(b);
    graph.addTarget(c);
    
    graph.addDependency("a", "b");
    graph.addDependency("b", "c");
    
    // This should detect the cycle through the chain
    void createCycle() { graph.addDependency("c", "a"); }
    Assert.throws!Exception(createCycle());
    
    writeln("\x1b[32m  ✓ Indirect cycle detection works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Self-dependency detection");
    
    auto graph = new BuildGraph();
    auto target = TargetBuilder.create("self").build();
    graph.addTarget(target);
    
    // Self-dependency should be detected
    void addSelfDep() { graph.addDependency("self", "self"); }
    Assert.throws!Exception(addSelfDep());
    
    writeln("\x1b[32m  ✓ Self-dependency prevented\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Diamond dependency pattern");
    
    auto graph = new BuildGraph();
    
    //     top
    //    /   \
    //   left right
    //    \   /
    //    bottom
    auto top = TargetBuilder.create("top").build();
    auto left = TargetBuilder.create("left").build();
    auto right = TargetBuilder.create("right").build();
    auto bottom = TargetBuilder.create("bottom").build();
    
    graph.addTarget(top);
    graph.addTarget(left);
    graph.addTarget(right);
    graph.addTarget(bottom);
    
    graph.addDependency("top", "left");
    graph.addDependency("top", "right");
    graph.addDependency("left", "bottom");
    graph.addDependency("right", "bottom");
    
    auto sorted = graph.topologicalSort();
    
    // bottom must come before both left and right
    // left and right must come before top
    auto bottomIdx = sorted.countUntil!(n => n.id == "bottom");
    auto leftIdx = sorted.countUntil!(n => n.id == "left");
    auto rightIdx = sorted.countUntil!(n => n.id == "right");
    auto topIdx = sorted.countUntil!(n => n.id == "top");
    
    Assert.isTrue(bottomIdx < leftIdx);
    Assert.isTrue(bottomIdx < rightIdx);
    Assert.isTrue(leftIdx < topIdx);
    Assert.isTrue(rightIdx < topIdx);
    
    writeln("\x1b[32m  ✓ Diamond dependency pattern handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Disconnected components");
    
    auto graph = new BuildGraph();
    
    // Create two disconnected chains
    auto a1 = TargetBuilder.create("a1").build();
    auto a2 = TargetBuilder.create("a2").build();
    auto b1 = TargetBuilder.create("b1").build();
    auto b2 = TargetBuilder.create("b2").build();
    
    graph.addTarget(a1);
    graph.addTarget(a2);
    graph.addTarget(b1);
    graph.addTarget(b2);
    
    graph.addDependency("a2", "a1");
    graph.addDependency("b2", "b1");
    
    auto sorted = graph.topologicalSort();
    Assert.equal(sorted.length, 4);
    
    // Within each chain, order must be preserved
    auto a1Idx = sorted.countUntil!(n => n.id == "a1");
    auto a2Idx = sorted.countUntil!(n => n.id == "a2");
    auto b1Idx = sorted.countUntil!(n => n.id == "b1");
    auto b2Idx = sorted.countUntil!(n => n.id == "b2");
    
    Assert.isTrue(a1Idx < a2Idx);
    Assert.isTrue(b1Idx < b2Idx);
    
    writeln("\x1b[32m  ✓ Disconnected components sorted correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Deep dependency chain");
    
    auto graph = new BuildGraph();
    
    // Create chain of depth 10
    enum depth = 10;
    foreach (i; 0 .. depth)
    {
        auto target = TargetBuilder.create("level" ~ i.to!string).build();
        graph.addTarget(target);
        
        if (i > 0)
        {
            graph.addDependency("level" ~ i.to!string, "level" ~ (i-1).to!string);
        }
    }
    
    auto sorted = graph.topologicalSort();
    Assert.equal(sorted.length, depth);
    
    // Verify each level comes after the previous
    foreach (i; 1 .. depth)
    {
        auto prevIdx = sorted.countUntil!(n => n.id == "level" ~ (i-1).to!string);
        auto currIdx = sorted.countUntil!(n => n.id == "level" ~ i.to!string);
        Assert.isTrue(prevIdx < currIdx);
    }
    
    // Verify depth calculation
    Assert.equal(graph.nodes["level0"].depth(), 0);
    Assert.equal(graph.nodes["level9"].depth(), 9);
    
    writeln("\x1b[32m  ✓ Deep dependency chain handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Wide parallelism detection");
    
    auto graph = new BuildGraph();
    
    // Create 10 independent targets (max parallelism = 10)
    foreach (i; 0 .. 10)
    {
        auto target = TargetBuilder.create("parallel" ~ i.to!string).build();
        graph.addTarget(target);
    }
    
    auto stats = graph.getStats();
    Assert.equal(stats.totalNodes, 10);
    Assert.equal(stats.totalEdges, 0);
    Assert.equal(stats.maxDepth, 0);
    Assert.equal(stats.parallelism, 10); // All can build in parallel
    
    writeln("\x1b[32m  ✓ Wide parallelism detected correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Multiple dependency paths");
    
    auto graph = new BuildGraph();
    
    // Create: a -> b -> c
    //         a -----> c (direct dependency too)
    auto a = TargetBuilder.create("a").build();
    auto b = TargetBuilder.create("b").build();
    auto c = TargetBuilder.create("c").build();
    
    graph.addTarget(a);
    graph.addTarget(b);
    graph.addTarget(c);
    
    graph.addDependency("a", "b");
    graph.addDependency("b", "c");
    graph.addDependency("a", "c"); // Redundant but valid
    
    auto sorted = graph.topologicalSort();
    
    // Should still produce valid order
    auto cIdx = sorted.countUntil!(n => n.id == "c");
    auto bIdx = sorted.countUntil!(n => n.id == "b");
    auto aIdx = sorted.countUntil!(n => n.id == "a");
    
    Assert.isTrue(cIdx < bIdx);
    Assert.isTrue(bIdx < aIdx);
    
    writeln("\x1b[32m  ✓ Multiple dependency paths handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Get roots with dependencies");
    
    auto graph = new BuildGraph();
    
    auto lib1 = TargetBuilder.create("lib1").build();
    auto lib2 = TargetBuilder.create("lib2").build();
    auto app = TargetBuilder.create("app").build();
    
    graph.addTarget(lib1);
    graph.addTarget(lib2);
    graph.addTarget(app);
    
    graph.addDependency("app", "lib1");
    graph.addDependency("app", "lib2");
    
    auto roots = graph.getRoots();
    Assert.equal(roots.length, 2);
    
    auto rootIds = roots.map!(n => n.id).array.sort.array;
    Assert.equal(rootIds, ["lib1", "lib2"]);
    
    writeln("\x1b[32m  ✓ Root node identification works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Ready nodes after partial build");
    
    auto graph = new BuildGraph();
    
    // Create: lib1 -> app -> exe
    //         lib2 /
    auto lib1 = TargetBuilder.create("lib1").build();
    auto lib2 = TargetBuilder.create("lib2").build();
    auto app = TargetBuilder.create("app").build();
    auto exe = TargetBuilder.create("exe").build();
    
    graph.addTarget(lib1);
    graph.addTarget(lib2);
    graph.addTarget(app);
    graph.addTarget(exe);
    
    graph.addDependency("app", "lib1");
    graph.addDependency("app", "lib2");
    graph.addDependency("exe", "app");
    
    // Initially, both libs are ready
    auto ready1 = graph.getReadyNodes();
    Assert.equal(ready1.length, 2);
    
    // After lib1 succeeds, app still not ready (needs lib2)
    graph.nodes["lib1"].status = BuildStatus.Success;
    auto ready2 = graph.getReadyNodes();
    Assert.equal(ready2.length, 1);
    Assert.equal(ready2[0].id, "lib2");
    
    // After lib2 succeeds, app becomes ready
    graph.nodes["lib2"].status = BuildStatus.Success;
    auto ready3 = graph.getReadyNodes();
    Assert.equal(ready3.length, 1);
    Assert.equal(ready3[0].id, "app");
    
    // After app succeeds, exe becomes ready
    graph.nodes["app"].status = BuildStatus.Success;
    auto ready4 = graph.getReadyNodes();
    Assert.equal(ready4.length, 1);
    Assert.equal(ready4[0].id, "exe");
    
    writeln("\x1b[32m  ✓ Ready nodes tracking through build process works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.graph - Cached status satisfies dependencies");
    
    auto graph = new BuildGraph();
    
    auto lib = TargetBuilder.create("lib").build();
    auto app = TargetBuilder.create("app").build();
    
    graph.addTarget(lib);
    graph.addTarget(app);
    graph.addDependency("app", "lib");
    
    // Set lib as cached (not built, but valid)
    graph.nodes["lib"].status = BuildStatus.Cached;
    
    // App should be ready since cached satisfies dependencies
    auto ready = graph.getReadyNodes();
    Assert.equal(ready.length, 1);
    Assert.equal(ready[0].id, "app");
    
    writeln("\x1b[32m  ✓ Cached status correctly satisfies dependencies\x1b[0m");
}

