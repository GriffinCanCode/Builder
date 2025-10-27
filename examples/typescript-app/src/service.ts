/**
 * Service layer with business logic and type-safe operations
 */

import {
    User,
    UserId,
    Email,
    UserRole,
    UserProfile,
    UserPreferences,
    Result,
    QueryOptions,
    DomainEvent,
    isErr,
} from './types';
import { Repository, BaseRepository } from './repository';
import { ValidationBuilder } from './validation';

// User Repository Implementation
export class UserRepository extends BaseRepository<User, UserId> {
    private idCounter = 0;

    protected generateId(): UserId {
        return `user_${++this.idCounter}` as UserId;
    }

    async findByEmail(email: Email): Promise<Result<User, Error>> {
        try {
            const result = await this.findAll({
                filters: { email },
            });

            if (isErr(result)) {
                return { ok: false, error: result.error };
            }

            const user = result.value[0];
            if (!user) {
                return {
                    ok: false,
                    error: new Error(`User with email ${email} not found`),
                };
            }

            return { ok: true, value: user };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }
}

// User Service with business logic
export class UserService {
    private events: DomainEvent[] = [];

    constructor(private readonly repository: UserRepository) {}

    async createUser(
        name: string,
        email: string,
        profile: UserProfile
    ): Promise<Result<User, Error>> {
        // Validate input
        const validator = new ValidationBuilder();
        validator
            .field('name')
            .required(name)
            .minLength(name, 2)
            .maxLength(name, 100);
        validator
            .field('email')
            .required(email)
            .email(email);
        validator
            .field('firstName')
            .required(profile.firstName)
            .minLength(profile.firstName, 1);
        validator
            .field('lastName')
            .required(profile.lastName)
            .minLength(profile.lastName, 1);

        const validationResult = validator.build({ name, email, profile });
        if (isErr(validationResult)) {
            const errors = validationResult.error;
            return {
                ok: false,
                error: new Error(
                    `Validation failed: ${errors.map(e => e.message).join(', ')}`
                ),
            };
        }

        // Check if user already exists
        const existingUser = await this.repository.findByEmail(email as Email);
        if (existingUser.ok) {
            return {
                ok: false,
                error: new Error(`User with email ${email} already exists`),
            };
        }

        // Create user with default preferences
        const defaultPreferences: UserPreferences = {
            theme: 'auto',
            notifications: true,
            language: 'en',
            timezone: 'UTC',
        };

        const createResult = await this.repository.create({
            name,
            email: email as Email,
            role: UserRole.User,
            profile,
            preferences: defaultPreferences,
        });

        if (createResult.ok) {
            this.emitEvent({
                id: this.generateEventId(),
                type: 'user.created',
                timestamp: Date.now() as any,
                payload: createResult.value,
            });
        }

        return createResult;
    }

    async updateUserProfile(
        userId: UserId,
        updates: Partial<UserProfile>
    ): Promise<Result<User, Error>> {
        const userResult = await this.repository.findById(userId);
        if (!userResult.ok) {
            return userResult;
        }

        const user = userResult.value;
        const updatedProfile = { ...user.profile, ...updates };

        const updateResult = await this.repository.update(userId, {
            profile: updatedProfile,
        });

        if (updateResult.ok) {
            this.emitEvent({
                id: this.generateEventId(),
                type: 'user.profile.updated',
                timestamp: Date.now() as any,
                payload: { userId, updates },
            });
        }

        return updateResult;
    }

    async updateUserPreferences(
        userId: UserId,
        preferences: Partial<UserPreferences>
    ): Promise<Result<User, Error>> {
        const userResult = await this.repository.findById(userId);
        if (!userResult.ok) {
            return userResult;
        }

        const user = userResult.value;
        const updatedPreferences = { ...user.preferences, ...preferences };

        return this.repository.update(userId, {
            preferences: updatedPreferences,
        });
    }

    async promoteToAdmin(userId: UserId): Promise<Result<User, Error>> {
        const result = await this.repository.update(userId, {
            role: UserRole.Admin,
        });

        if (result.ok) {
            this.emitEvent({
                id: this.generateEventId(),
                type: 'user.promoted',
                timestamp: Date.now() as any,
                payload: { userId, role: UserRole.Admin },
            });
        }

        return result;
    }

    async listUsers(options?: QueryOptions): Promise<Result<User[], Error>> {
        return this.repository.findAll(options);
    }

    async deleteUser(userId: UserId): Promise<Result<void, Error>> {
        const result = await this.repository.delete(userId);

        if (result.ok) {
            this.emitEvent({
                id: this.generateEventId(),
                type: 'user.deleted',
                timestamp: Date.now() as any,
                payload: { userId },
            });
        }

        return result;
    }

    getEvents(): DomainEvent[] {
        return [...this.events];
    }

    clearEvents(): void {
        this.events = [];
    }

    private emitEvent(event: DomainEvent): void {
        this.events.push(event);
        console.log(`[EVENT] ${event.type}:`, event.payload);
    }

    private generateEventId(): string {
        return `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }
}

// Factory function with dependency injection
export function createUserService(): UserService {
    const repository = new UserRepository();
    return new UserService(repository);
}

