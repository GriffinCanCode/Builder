// Mixed language project demonstrating cross-language dependencies

target("core") {
    type: library;
    language: python;
    sources: ["core.py"];
}

target("data-processor") {
    type: executable;
    language: python;
    sources: ["processor.py"];
    deps: [":core"];
}

target("web-ui") {
    type: library;
    language: javascript;
    sources: ["ui.js"];
}

