#!/usr/bin/env node
/**
 * Main JavaScript application
 */

const { formatDate, sum, fibonacci, processJSON, asyncOperation } = require('./utils');
const fs = require('fs');
const path = require('path');

async function main() {
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

    // JSON processing (common real-world use case)
    console.log('\nJSON Processing:');
    const data = { name: "Builder", version: "1.0.0", features: ["fast", "flexible"] };
    console.log('  Original:', data);
    console.log('  Processed:', processJSON(data));

    // File operations (80/20 rule)
    console.log('\nFile System:');
    console.log('  Current directory:', process.cwd());
    console.log('  Script path:', __filename);
    
    // Environment variables
    console.log('\nEnvironment:');
    console.log('  NODE_ENV:', process.env.NODE_ENV || 'development');
    console.log('  Args:', process.argv.slice(2));

    // Async/await pattern (important JS feature)
    console.log('\nAsync Operations:');
    const result = await asyncOperation('Builder');
    console.log('  Result:', result);

    // ES6+ features
    const [first, ...rest] = numbers;
    console.log('\nES6+ Features:');
    console.log('  Destructuring - First:', first, 'Rest:', rest);
    console.log('  Arrow functions:', numbers.map(n => n * 2));
    console.log('  Template literals work!');
}

main().catch(console.error);

