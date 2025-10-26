/**
 * Math operations with enums
 */

export enum MathOperation {
    Add,
    Subtract,
    Multiply,
    Divide
}

export function calculate(a: number, b: number, op: MathOperation): number {
    switch (op) {
        case MathOperation.Add:
            return a + b;
        case MathOperation.Subtract:
            return a - b;
        case MathOperation.Multiply:
            return a * b;
        case MathOperation.Divide:
            if (b === 0) throw new Error('Division by zero');
            return a / b;
    }
}

