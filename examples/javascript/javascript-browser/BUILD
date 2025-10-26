// Browser application with bundling
target("bundle") {
    type: executable;
    language: javascript;
    sources: ["src/**/*.js"];
    output: "bundle.js";
    
    jsConfig: {
        "mode": "bundle",
        "bundler": "esbuild",
        "entry": "src/app.js",
        "platform": "browser",
        "format": "iife",
        "minify": true,
        "sourcemap": true,
        "target": "es2018"
    };
}

