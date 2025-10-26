// React application with JSX support
target("app") {
    type: executable;
    language: javascript;
    sources: ["src/**/*.jsx", "src/**/*.js"];
    output: "bundle.js";
    
    config: {
        "mode": "bundle",
        "bundler": "esbuild",
        "entry": "src/index.jsx",
        "platform": "browser",
        "format": "iife",
        "minify": true,
        "sourcemap": true,
        "target": "es2018",
        "jsx": true,
        "jsxFactory": "React.createElement",
        "external": []
    };
}
