/**
 * TypeScript utility functions with type definitions
 */

export interface User {
    name: string;
    age: number;
    email: string;
}

export function greet(user: User): string {
    return `Hello, ${user.name}! You are ${user.age} years old.`;
}

export function formatDate(date: Date): string {
    return date.toISOString().split('T')[0];
}

