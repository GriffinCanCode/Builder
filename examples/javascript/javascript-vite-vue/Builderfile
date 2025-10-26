// Vue 3 application with Vite bundler
target("app") {
    type: executable;
    language: javascript;
    sources: ["src/**/*.vue", "src/**/*.js"];
    output: "bundle.js";
    
    config: {
        "mode": "bundle",
        "bundler": "vite",
        "entry": "src/main.js",
        "platform": "browser",
        "format": "esm",
        "minify": true,
        "sourcemap": true,
        "target": "es2020",
        "installDeps": false
    };
}

// Library build target
target("lib") {
    type: library;
    language: javascript;
    sources: ["src/App.vue"];
    output: "app-lib.js";
    
    config: {
        "mode": "library",
        "bundler": "vite",
        "entry": "src/App.vue",
        "platform": "browser",
        "format": "esm",
        "minify": false,
        "sourcemap": true,
        "target": "es2020",
        "external": ["vue"]
    };
}

