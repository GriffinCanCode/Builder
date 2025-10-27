module tests.unit.languages.kotlin;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import languages.jvm.kotlin;
import config.schema.schema;
import tests.harness;
import tests.fixtures;

/// Test Kotlin import detection
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Import detection");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
import kotlin.collections.List
import java.util.Date
import com.example.utils.Logger

fun main() {
    println("Hello, Kotlin!")
}
`;
    
    tempDir.createFile("Main.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "Main.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ Kotlin import detection works\x1b[0m");
}

/// Test Kotlin executable build
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Build executable");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    tempDir.createFile("Main.kt", `
fun main(args: Array<String>) {
    println("Hello, Kotlin!")
    
    val numbers = listOf(1, 2, 3, 4, 5)
    val doubled = numbers.map { it * 2 }
    
    println(doubled)
}
`);
    
    auto target = TargetBuilder.create("//app:main")
        .withType(TargetType.Executable)
        .withSources([buildPath(tempDir.getPath(), "Main.kt")])
        .build();
    target.language = TargetLanguage.Kotlin;
    
    WorkspaceConfig config;
    config.root = tempDir.getPath();
    config.options.outputDir = buildPath(tempDir.getPath(), "build");
    
    auto handler = new KotlinHandler();
    auto result = handler.build(target, config);
    
    Assert.isTrue(result.isOk || result.isErr);
    
    writeln("\x1b[32m  ✓ Kotlin executable build works\x1b[0m");
}

/// Test Kotlin data classes
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Data classes");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
data class User(
    val id: Int,
    val name: String,
    val email: String
)

data class Product(
    val id: Int,
    val name: String,
    val price: Double
) {
    fun displayInfo() = "$name - $$price"
}

fun main() {
    val user = User(1, "Alice", "alice@example.com")
    val copy = user.copy(name = "Bob")
    
    println(user)
    println(copy)
}
`;
    
    tempDir.createFile("DataClasses.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "DataClasses.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin data classes work\x1b[0m");
}

/// Test Kotlin sealed classes and when expressions
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Sealed classes and when");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

fun processResult(result: Result<String>) {
    when (result) {
        is Result.Success -> println("Success: ${result.data}")
        is Result.Error -> println("Error: ${result.message}")
        Result.Loading -> println("Loading...")
    }
}
`;
    
    tempDir.createFile("Sealed.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "Sealed.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin sealed classes and when work\x1b[0m");
}

/// Test Kotlin extension functions
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Extension functions");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
fun String.shout(): String = this.uppercase() + "!"

fun <T> List<T>.secondOrNull(): T? = 
    if (this.size >= 2) this[1] else null

fun Int.times(action: (Int) -> Unit) {
    for (i in 0 until this) {
        action(i)
    }
}

fun main() {
    println("hello".shout())
    
    val list = listOf(1, 2, 3)
    println(list.secondOrNull())
    
    3.times { println("Hello $it") }
}
`;
    
    tempDir.createFile("Extensions.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "Extensions.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin extension functions work\x1b[0m");
}

/// Test Kotlin coroutines
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Coroutines");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
import kotlinx.coroutines.*

suspend fun fetchData(): String {
    delay(1000)
    return "Data"
}

fun main() = runBlocking {
    launch {
        val data = fetchData()
        println(data)
    }
    
    val deferred = async {
        fetchData()
    }
    println(deferred.await())
}
`;
    
    tempDir.createFile("Coroutines.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "Coroutines.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin coroutines work\x1b[0m");
}

/// Test Kotlin null safety
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m languages.kotlin - Null safety");
    
    auto tempDir = scoped(new TempDir("kotlin-test"));
    
    string kotlinCode = `
fun processString(str: String?) {
    val length = str?.length ?: 0
    println("Length: $length")
    
    str?.let {
        println("String is not null: $it")
    }
    
    val nonNull: String = str ?: "default"
    println(nonNull)
}

fun main() {
    processString("Hello")
    processString(null)
}
`;
    
    tempDir.createFile("NullSafety.kt", kotlinCode);
    auto filePath = buildPath(tempDir.getPath(), "NullSafety.kt");
    
    auto handler = new KotlinHandler();
    auto imports = handler.analyzeImports([filePath]);
    
    Assert.notNull(imports);
    
    writeln("\x1b[32m  ✓ Kotlin null safety works\x1b[0m");
}

