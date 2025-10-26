/**
 * Browser Application Entry Point
 */

import { fibonacci, formatDate } from './utils.js';
import { renderResults } from './ui.js';

document.addEventListener('DOMContentLoaded', () => {
    const button = document.getElementById('calculate');
    const output = document.getElementById('output');
    
    button.addEventListener('click', () => {
        const results = [];
        
        results.push(`<strong>Date:</strong> ${formatDate(new Date())}`);
        results.push(`<strong>Fibonacci Sequence:</strong>`);
        
        for (let i = 0; i < 10; i++) {
            results.push(`fib(${i}) = ${fibonacci(i)}`);
        }
        
        renderResults(output, results);
    });
});

