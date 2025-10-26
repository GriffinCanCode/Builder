#!/usr/bin/env node
/**
 * Node.js Script Example
 * No bundling needed - direct Node.js execution
 */

const { formatDate, sum, fibonacci } = require('./utils');

function main() {
    console.log('=== Builder Node.js Example ===\n');

    console.log('Date Operations:');
    console.log('  Today:', formatDate(new Date()));

    console.log('\nArray Operations:');
    const numbers = [1, 2, 3, 4, 5];
    console.log('  Numbers:', numbers);
    console.log('  Sum:', sum(numbers));

    console.log('\nFibonacci Sequence:');
    for (let i = 0; i < 10; i++) {
        console.log(`  fib(${i}) = ${fibonacci(i)}`);
    }
}

main();

