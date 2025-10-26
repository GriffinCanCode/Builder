module tests.unit.core.graph;

import std.stdio;
import std.algorithm;
import std.array;
import core.graph;
import config.schema;
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

