/**
 * Utility functions for formatting and display
 */

import { User, Result, isErr } from './types';

export function formatUser(user: User): string {
    return `${user.name} <${user.email}> [${user.role}]`;
}

export function formatError(error: Error): string {
    return `Error: ${error.message}`;
}

export function formatResult<T>(result: Result<T, Error>, formatter?: (value: T) => string): string {
    if (isErr(result)) {
        return formatError(result.error);
    } else {
        return formatter ? formatter(result.value) : String(result.value);
    }
}

export function capitalize(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

export function truncate(str: string, maxLength: number): string {
    if (str.length <= maxLength) return str;
    return str.slice(0, maxLength - 3) + '...';
}

export function formatDate(date: Date): string {
    return date.toISOString().split('T')[0];
}

export function formatDateTime(date: Date): string {
    return date.toISOString();
}
