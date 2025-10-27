/**
 * Core type definitions demonstrating advanced TypeScript features
 */

// Branded types for type safety
export type UserId = string & { readonly __brand: 'UserId' };
export type Email = string & { readonly __brand: 'Email' };
export type Timestamp = number & { readonly __brand: 'Timestamp' };

// Type guards
export function isUserId(value: unknown): value is UserId {
    return typeof value === 'string' && value.length > 0;
}

export function isEmail(value: unknown): value is Email {
    return typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

// Advanced type utilities
export type DeepPartial<T> = {
    [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

export type DeepReadonly<T> = {
    readonly [P in keyof T]: T[P] extends object ? DeepReadonly<T[P]> : T[P];
};

export type Nullable<T> = T | null;
export type Optional<T> = T | undefined;

// Mapped types for transformations
export type WithTimestamps<T> = T & {
    createdAt: Timestamp;
    updatedAt: Timestamp;
};

export type APIResponse<T> = {
    data: T;
    status: 'success' | 'error';
    message?: string;
    meta?: {
        page?: number;
        totalPages?: number;
        total?: number;
    };
};

// Domain models
export interface User {
    id: UserId;
    name: string;
    email: Email;
    role: UserRole;
    profile: UserProfile;
    preferences: UserPreferences;
}

export enum UserRole {
    Admin = 'admin',
    User = 'user',
    Guest = 'guest',
}

export interface UserProfile {
    firstName: string;
    lastName: string;
    bio?: string;
    avatar?: string;
    location?: string;
    dateOfBirth?: Date;
}

export interface UserPreferences {
    theme: 'light' | 'dark' | 'auto';
    notifications: boolean;
    language: string;
    timezone: string;
}

// Repository result types
export type Result<T, E = Error> = 
    | { ok: true; value: T }
    | { ok: false; error: E };

// Type guard helpers for Result type
export function isOk<T, E>(result: Result<T, E>): result is { ok: true; value: T } {
    return result.ok === true;
}

export function isErr<T, E>(result: Result<T, E>): result is { ok: false; error: E } {
    return result.ok === false;
}

// Validation types
export interface ValidationError {
    field: string;
    message: string;
    code: string;
}

export type Validator<T> = (value: unknown) => Result<T, ValidationError[]>;

// Event types
export interface DomainEvent<T = unknown> {
    id: string;
    type: string;
    timestamp: Timestamp;
    payload: T;
    metadata?: Record<string, unknown>;
}

// Query/Filter types
export interface QueryOptions {
    limit?: number;
    offset?: number;
    sortBy?: string;
    sortOrder?: 'asc' | 'desc';
    filters?: Record<string, unknown>;
}

// Type-safe builder pattern
export type Builder<T> = {
    [K in keyof T]-?: (value: T[K]) => Builder<T>;
} & {
    build(): T;
};

