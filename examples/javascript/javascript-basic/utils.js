/**
 * Utility functions for JavaScript example
 */

function formatDate(date) {
    return date.toISOString().split('T')[0];
}

function sum(arr) {
    return arr.reduce((a, b) => a + b, 0);
}

function fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// JSON processing (common use case)
function processJSON(data) {
    return {
        ...data,
        processed: true,
        timestamp: new Date().toISOString()
    };
}

// Async operations (important pattern)
async function asyncOperation(input) {
    return new Promise((resolve) => {
        setTimeout(() => {
            resolve(`Async result for: ${input}`);
        }, 10);
    });
}

// Object manipulation (80/20 rule)
function transformObject(obj) {
    const transformed = {};
    for (const [key, value] of Object.entries(obj)) {
        transformed[key.toUpperCase()] = value;
    }
    return transformed;
}

// Array utilities
const arrayUtils = {
    unique: (arr) => [...new Set(arr)],
    flatten: (arr) => arr.flat(),
    chunk: (arr, size) => {
        const chunks = [];
        for (let i = 0; i < arr.length; i += size) {
            chunks.push(arr.slice(i, i + size));
        }
        return chunks;
    }
};

module.exports = { 
    formatDate, 
    sum, 
    fibonacci,
    processJSON,
    asyncOperation,
    transformObject,
    arrayUtils
};

