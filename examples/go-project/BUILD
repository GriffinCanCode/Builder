// Go project BUILD file with DSL syntax

target("go-app") {
    type: executable;
    language: go;
    sources: ["main.go", "greeter.go"];
    flags: ["-ldflags", "-s -w"];
    env: {
        "CGO_ENABLED": "0"
    };
}

