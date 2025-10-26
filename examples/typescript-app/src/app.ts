/**
 * TypeScript Application Example
 */

import { greet, User } from './utils';
import { calculate, MathOperation } from './math';

function main(): void {
    console.log('=== Builder TypeScript Example ===\n');
    
    const user: User = {
        name: 'Builder',
        age: 1,
        email: 'builder@example.com'
    };
    
    console.log(greet(user));
    
    console.log('\nMath Operations:');
    console.log(`  2 + 3 = ${calculate(2, 3, MathOperation.Add)}`);
    console.log(`  10 - 4 = ${calculate(10, 4, MathOperation.Subtract)}`);
    console.log(`  5 * 6 = ${calculate(5, 6, MathOperation.Multiply)}`);
    console.log(`  20 / 4 = ${calculate(20, 4, MathOperation.Divide)}`);
}

main();

