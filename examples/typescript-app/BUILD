// TypeScript application with bundling
target("app") {
    type: executable;
    language: typescript;
    sources: ["src/**/*.ts"];
    output: "app.js";
    
    config: {
        "mode": "bundle",
        "bundler": "esbuild",
        "entry": "src/app.ts",
        "platform": "node",
        "format": "cjs",
        "minify": false,
        "sourcemap": true,
        "target": "es2020"
    };
}
