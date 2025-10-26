/**
 * Type-safe validation framework
 */

import { Result, ValidationError, Validator } from './types';

export class ValidationErrorImpl implements ValidationError {
    constructor(
        public readonly field: string,
        public readonly message: string,
        public readonly code: string
    ) {}
}

export class ValidationBuilder {
    private errors: ValidationError[] = [];

    field(fieldName: string): FieldValidator {
        return new FieldValidator(fieldName, this.errors);
    }

    build<T>(value: T): Result<T, ValidationError[]> {
        if (this.errors.length > 0) {
            return { ok: false, error: this.errors };
        }
        return { ok: true, value };
    }
}

class FieldValidator {
    constructor(
        private fieldName: string,
        private errors: ValidationError[]
    ) {}

    required(value: unknown, message?: string): this {
        if (value === null || value === undefined || value === '') {
            this.errors.push(
                new ValidationErrorImpl(
                    this.fieldName,
                    message || `${this.fieldName} is required`,
                    'REQUIRED'
                )
            );
        }
        return this;
    }

    minLength(value: string | unknown[], min: number, message?: string): this {
        if (typeof value === 'string' || Array.isArray(value)) {
            if (value.length < min) {
                this.errors.push(
                    new ValidationErrorImpl(
                        this.fieldName,
                        message || `${this.fieldName} must be at least ${min} characters`,
                        'MIN_LENGTH'
                    )
                );
            }
        }
        return this;
    }

    maxLength(value: string | unknown[], max: number, message?: string): this {
        if (typeof value === 'string' || Array.isArray(value)) {
            if (value.length > max) {
                this.errors.push(
                    new ValidationErrorImpl(
                        this.fieldName,
                        message || `${this.fieldName} must be at most ${max} characters`,
                        'MAX_LENGTH'
                    )
                );
            }
        }
        return this;
    }

    pattern(value: string, pattern: RegExp, message?: string): this {
        if (typeof value === 'string' && !pattern.test(value)) {
            this.errors.push(
                new ValidationErrorImpl(
                    this.fieldName,
                    message || `${this.fieldName} has invalid format`,
                    'PATTERN'
                )
            );
        }
        return this;
    }

    email(value: string, message?: string): this {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return this.pattern(value, emailRegex, message || 'Invalid email address');
    }

    min(value: number, min: number, message?: string): this {
        if (typeof value === 'number' && value < min) {
            this.errors.push(
                new ValidationErrorImpl(
                    this.fieldName,
                    message || `${this.fieldName} must be at least ${min}`,
                    'MIN'
                )
            );
        }
        return this;
    }

    max(value: number, max: number, message?: string): this {
        if (typeof value === 'number' && value > max) {
            this.errors.push(
                new ValidationErrorImpl(
                    this.fieldName,
                    message || `${this.fieldName} must be at most ${max}`,
                    'MAX'
                )
            );
        }
        return this;
    }

    custom<T>(value: T, validator: (v: T) => boolean, message: string, code: string): this {
        if (!validator(value)) {
            this.errors.push(
                new ValidationErrorImpl(this.fieldName, message, code)
            );
        }
        return this;
    }
}

// Composable validators
export function compose<T>(...validators: Validator<T>[]): Validator<T> {
    return (value: unknown): Result<T, ValidationError[]> => {
        const errors: ValidationError[] = [];
        let lastValidValue: T | undefined;

        for (const validator of validators) {
            const result = validator(value);
            if (!result.ok) {
                errors.push(...result.error);
            } else {
                lastValidValue = result.value;
            }
        }

        if (errors.length > 0) {
            return { ok: false, error: errors };
        }

        return { ok: true, value: lastValidValue as T };
    };
}

