// Node.js script - no bundling needed
target("utils") {
    type: library;
    language: javascript;
    sources: ["utils.js"];
}

target("app") {
    type: executable;
    language: javascript;
    sources: ["app.js"];
    deps: [":utils"];
    
    jsConfig: {
        "mode": "node",
        "bundler": "none"
    };
}

