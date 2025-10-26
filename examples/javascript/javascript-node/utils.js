/**
 * Utility functions for Node.js example
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

module.exports = { formatDate, sum, fibonacci };

