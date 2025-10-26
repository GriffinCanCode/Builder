// React application with Vite bundler
target("app") {
    type: executable;
    language: javascript;
    sources: ["src/**/*.jsx", "src/**/*.js", "src/**/*.css"];
    output: "bundle.js";
    
    config: {
        "mode": "bundle",
        "bundler": "vite",
        "entry": "src/main.jsx",
        "platform": "browser",
        "format": "esm",
        "minify": true,
        "sourcemap": true,
        "target": "es2020",
        "jsx": true,
        "installDeps": false
    };
}

// Library build target
target("lib") {
    type: library;
    language: javascript;
    sources: ["src/App.jsx"];
    output: "app-lib.js";
    
    config: {
        "mode": "library",
        "bundler": "vite",
        "entry": "src/App.jsx",
        "platform": "browser",
        "format": "esm",
        "minify": false,
        "sourcemap": true,
        "target": "es2020",
        "jsx": true,
        "external": ["react", "react-dom"]
    };
}

