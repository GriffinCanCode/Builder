module languages.jvm.scala;

/// Modular Scala Language Support
/// 
/// Comprehensive, production-ready Scala support with:
/// - Multiple build tools: sbt, Mill, Scala CLI, Maven, Gradle, Bloop
/// - Multiple output modes: JAR, Assembly, Native Image, Scala.js, Scala Native
/// - Scala 2.x and 3.x support
/// - Testing frameworks: ScalaTest, Specs2, MUnit, uTest, ScalaCheck, ZIO Test
/// - Code formatting: Scalafmt
/// - Linting: Scalafix, WartRemover, Scapegoat
/// - Dependency analysis and management

public import languages.jvm.scala.core;
public import languages.jvm.scala.managers;
public import languages.jvm.scala.tooling;
public import languages.jvm.scala.analysis;

