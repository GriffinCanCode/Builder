#!/usr/bin/env node
/**
 * Main JavaScript application
 */

const { formatDate, sum, fibonacci } = require('./utils');

console.log('=== Builder JavaScript Example ===\n');

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

