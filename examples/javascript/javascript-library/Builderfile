// Library with multiple output formats
target("lib-esm") {
    type: library;
    language: javascript;
    sources: ["src/**/*.js"];
    output: "math-utils.esm.js";
    
    jsConfig: {
        "mode": "library",
        "bundler": "rollup",
        "entry": "src/index.js",
        "platform": "neutral",
        "format": "esm",
        "minify": false,
        "sourcemap": true
    };
}

target("lib-cjs") {
    type: library;
    language: javascript;
    sources: ["src/**/*.js"];
    output: "math-utils.cjs.js";
    
    jsConfig: {
        "mode": "library",
        "bundler": "rollup",
        "entry": "src/index.js",
        "platform": "neutral",
        "format": "cjs",
        "minify": false,
        "sourcemap": true
    };
}

target("lib-umd") {
    type: library;
    language: javascript;
    sources: ["src/**/*.js"];
    output: "math-utils.umd.js";
    
    jsConfig: {
        "mode": "library",
        "bundler": "rollup",
        "entry": "src/index.js",
        "platform": "neutral",
        "format": "umd",
        "minify": true,
        "sourcemap": false
    };
}

