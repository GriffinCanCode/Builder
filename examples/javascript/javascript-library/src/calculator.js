/**
 * Calculator class
 */

import { add, subtract, multiply, divide } from './math.js';

export default class Calculator {
    constructor() {
        this.value = 0;
    }
    
    add(n) {
        this.value = add(this.value, n);
        return this;
    }
    
    subtract(n) {
        this.value = subtract(this.value, n);
        return this;
    }
    
    multiply(n) {
        this.value = multiply(this.value, n);
        return this;
    }
    
    divide(n) {
        this.value = divide(this.value, n);
        return this;
    }
    
    result() {
        return this.value;
    }
    
    reset() {
        this.value = 0;
        return this;
    }
}

