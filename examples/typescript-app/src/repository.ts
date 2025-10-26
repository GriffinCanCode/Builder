/**
 * Generic repository pattern with type-safe CRUD operations
 */

import { Result, QueryOptions, WithTimestamps } from './types';

export interface Repository<T, ID> {
    findById(id: ID): Promise<Result<T, Error>>;
    findAll(options?: QueryOptions): Promise<Result<T[], Error>>;
    create(entity: Omit<T, 'id'>): Promise<Result<T, Error>>;
    update(id: ID, entity: Partial<T>): Promise<Result<T, Error>>;
    delete(id: ID): Promise<Result<void, Error>>;
}

export abstract class BaseRepository<T extends { id: ID }, ID> implements Repository<T, ID> {
    protected storage: Map<ID, WithTimestamps<T>> = new Map();

    async findById(id: ID): Promise<Result<T, Error>> {
        try {
            const entity = this.storage.get(id);
            if (!entity) {
                return {
                    ok: false,
                    error: new Error(`Entity with id ${id} not found`),
                };
            }
            return { ok: true, value: this.stripTimestamps(entity) };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }

    async findAll(options?: QueryOptions): Promise<Result<T[], Error>> {
        try {
            let entities = Array.from(this.storage.values());

            // Apply filters
            if (options?.filters) {
                entities = this.applyFilters(entities, options.filters);
            }

            // Apply sorting
            if (options?.sortBy) {
                entities = this.applySorting(entities, options.sortBy, options.sortOrder);
            }

            // Apply pagination
            const offset = options?.offset ?? 0;
            const limit = options?.limit ?? entities.length;
            entities = entities.slice(offset, offset + limit);

            return {
                ok: true,
                value: entities.map(e => this.stripTimestamps(e)),
            };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }

    async create(entity: Omit<T, 'id'>): Promise<Result<T, Error>> {
        try {
            const id = this.generateId();
            const now = Date.now() as any;
            const newEntity: WithTimestamps<T> = {
                ...entity,
                id,
                createdAt: now,
                updatedAt: now,
            } as WithTimestamps<T>;

            this.storage.set(id, newEntity);
            return { ok: true, value: this.stripTimestamps(newEntity) };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }

    async update(id: ID, updates: Partial<T>): Promise<Result<T, Error>> {
        try {
            const existing = this.storage.get(id);
            if (!existing) {
                return {
                    ok: false,
                    error: new Error(`Entity with id ${id} not found`),
                };
            }

            const updated: WithTimestamps<T> = {
                ...existing,
                ...updates,
                id,
                updatedAt: Date.now() as any,
            };

            this.storage.set(id, updated);
            return { ok: true, value: this.stripTimestamps(updated) };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }

    async delete(id: ID): Promise<Result<void, Error>> {
        try {
            if (!this.storage.has(id)) {
                return {
                    ok: false,
                    error: new Error(`Entity with id ${id} not found`),
                };
            }
            this.storage.delete(id);
            return { ok: true, value: undefined };
        } catch (error) {
            return { ok: false, error: error as Error };
        }
    }

    protected abstract generateId(): ID;

    private stripTimestamps(entity: WithTimestamps<T>): T {
        const { createdAt, updatedAt, ...rest } = entity as any;
        return rest as T;
    }

    private applyFilters(
        entities: WithTimestamps<T>[],
        filters: Record<string, unknown>
    ): WithTimestamps<T>[] {
        return entities.filter(entity => {
            for (const [key, value] of Object.entries(filters)) {
                if ((entity as any)[key] !== value) {
                    return false;
                }
            }
            return true;
        });
    }

    private applySorting(
        entities: WithTimestamps<T>[],
        sortBy: string,
        sortOrder: 'asc' | 'desc' = 'asc'
    ): WithTimestamps<T>[] {
        return [...entities].sort((a, b) => {
            const aVal = (a as any)[sortBy];
            const bVal = (b as any)[sortBy];
            const compare = aVal < bVal ? -1 : aVal > bVal ? 1 : 0;
            return sortOrder === 'asc' ? compare : -compare;
        });
    }
}

