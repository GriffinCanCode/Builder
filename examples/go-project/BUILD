// Go project BUILD file with DSL syntax

target("greeter") {
    type: library;
    language: go;
    sources: ["greeter.go"];
}

target("go-app") {
    type: executable;
    language: go;
    sources: ["main.go"];
    deps: [":greeter"];
    flags: ["-ldflags", "-s -w"];
    env: {
        "CGO_ENABLED": "0"
    };
}

