// Python multi-module project with DSL syntax

target("math-utils") {
    type: library;
    language: python;
    sources: ["lib/math_utils.py"];
}

target("string-utils") {
    type: library;
    language: python;
    sources: ["lib/string_utils.py"];
}

target("calculator") {
    type: executable;
    language: python;
    sources: ["calculator.py"];
    deps: [
        ":math-utils",
        ":string-utils"
    ];
}

