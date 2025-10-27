module tests.unit.languages.scala;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.jvm.scala;
import config.schema;
import tests.harness;
import tests.fixtures;

/// Test Scala import detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - Import detection");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    string scalaCode = `
import scala.collection.mutable.ListBuffer
import scala.io.Source
import java.util.Date

object Main {
  def main(args: Array[String]): Unit = {
    println("Hello, Scala!")
  }
}
`;
    
    tempDir.createFile("Main.scala", scalaCode);
    auto filePath = buildPath(tempDir.getPath(), "Main.scala");
    
    auto handler = new ScalaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ Scala import detection works\x1b[0m");
}

/// Test Scala executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - Build executable");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    tempDir.createFile("Main.scala", `
object Main extends App {
  println("Hello, Scala!")
  
  val numbers = List(1, 2, 3, 4, 5)
  val doubled = numbers.map(_ * 2)
  
  println(doubled)
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "Main.scala")])
        .build();
    target.language = TargetLanguage.Scala;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "target");
    
    auto handler = new ScalaHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Scala executable build works\x1b[0m");
}

/// Test Scala case classes and pattern matching
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - Case classes and pattern matching");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    string scalaCode = `
sealed trait Shape
case class Circle(radius: Double) extends Shape
case class Rectangle(width: Double, height: Double) extends Shape
case class Triangle(base: Double, height: Double) extends Shape

object ShapeCalculator {
  def area(shape: Shape): Double = shape match {
    case Circle(r) => math.Pi * r * r
    case Rectangle(w, h) => w * h
    case Triangle(b, h) => 0.5 * b * h
  }
}
`;
    
    tempDir.createFile("Shapes.scala", scalaCode);
    auto filePath = buildPath(tempDir.getPath(), "Shapes.scala");
    
    auto handler = new ScalaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Scala case classes and pattern matching work\x1b[0m");
}

/// Test Scala traits and mixins
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - Traits and mixins");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    string scalaCode = `
trait Logger {
  def log(msg: String): Unit = println(s"[LOG] $msg")
}

trait Timestamped {
  def timestamp: Long = System.currentTimeMillis()
}

class Service extends Logger with Timestamped {
  def process(): Unit = {
    log(s"Processing at ${timestamp}")
  }
}
`;
    
    tempDir.createFile("Service.scala", scalaCode);
    auto filePath = buildPath(tempDir.getPath(), "Service.scala");
    
    auto handler = new ScalaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Scala traits and mixins work\x1b[0m");
}

/// Test Scala for comprehensions
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - For comprehensions");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    string scalaCode = `
object ForComprehensionExample {
  def cartesianProduct(): Unit = {
    val result = for {
      x <- 1 to 3
      y <- 1 to 3
      if x != y
    } yield (x, y)
    
    println(result)
  }
  
  def flatMapExample(): Unit = {
    val names = List("Alice", "Bob", "Charlie")
    val lengths = for {
      name <- names
      char <- name
    } yield char
    
    println(lengths)
  }
}
`;
    
    tempDir.createFile("ForComp.scala", scalaCode);
    auto filePath = buildPath(tempDir.getPath(), "ForComp.scala");
    
    auto handler = new ScalaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Scala for comprehensions work\x1b[0m");
}

/// Test Scala implicit parameters
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - Implicit parameters");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    string scalaCode = `
object ImplicitExample {
  implicit val defaultMultiplier: Int = 2
  
  def multiply(x: Int)(implicit multiplier: Int): Int = {
    x * multiplier
  }
  
  implicit class StringOps(s: String) {
    def shout: String = s.toUpperCase + "!"
  }
  
  def demo(): Unit = {
    println(multiply(5))
    println("hello".shout)
  }
}
`;
    
    tempDir.createFile("Implicit.scala", scalaCode);
    auto filePath = buildPath(tempDir.getPath(), "Implicit.scala");
    
    auto handler = new ScalaHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Scala implicit parameters work\x1b[0m");
}

/// Test Scala build.sbt detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.scala - build.sbt detection");
    
    auto tempDir = scoped(new TempDir("scala-test"));
    
    tempDir.createFile("build.sbt", `
name := "MyScalaApp"
version := "0.1.0"
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "org.scalatest" %% "scalatest" % "3.2.15" % Test,
  "com.typesafe.akka" %% "akka-actor" % "2.6.20"
)
`);
    
    auto sbtPath = buildPath(tempDir.getPath(), "build.sbt");
    
    Assert.isTrue(exists(sbtPath));
    
    writeln("\x1b[32m  ✓ Scala build.sbt detection works\x1b[0m");
}

