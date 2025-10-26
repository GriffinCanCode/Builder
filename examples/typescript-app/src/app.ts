/**
 * TypeScript Application - Real-world Example
 * Demonstrates advanced TypeScript features and patterns
 */

import { UserId, Email, UserRole } from './types';
import { createUserService } from './service';
import { formatResult, formatUser, formatError } from './utils';

async function main(): Promise<void> {
    console.log('=== Builder TypeScript Example ===');
    console.log('Real-world application with advanced patterns\n');

    const userService = createUserService();

    try {
        // Create users
        console.log('📝 Creating users...');
        const alice = await userService.createUser(
            'Alice Johnson',
            'alice@example.com',
            {
                firstName: 'Alice',
                lastName: 'Johnson',
                bio: 'Software engineer passionate about TypeScript',
                location: 'San Francisco, CA',
            }
        );

        if (!alice.ok) {
            console.error('Failed to create Alice:', formatError(alice.error));
            return;
        }

        console.log('✓ Created:', formatUser(alice.value));

        const bob = await userService.createUser(
            'Bob Smith',
            'bob@example.com',
            {
                firstName: 'Bob',
                lastName: 'Smith',
                bio: 'DevOps enthusiast and automation expert',
                location: 'New York, NY',
            }
        );

        if (!bob.ok) {
            console.error('Failed to create Bob:', formatError(bob.error));
            return;
        }

        console.log('✓ Created:', formatUser(bob.value));

        // Try to create duplicate user (should fail)
        console.log('\n🔄 Attempting to create duplicate user...');
        const duplicate = await userService.createUser(
            'Alice Clone',
            'alice@example.com',
            {
                firstName: 'Alice',
                lastName: 'Clone',
            }
        );

        if (!duplicate.ok) {
            console.log('✓ Correctly rejected duplicate:', formatError(duplicate.error));
        }

        // Update user profile
        console.log('\n✏️  Updating user profile...');
        const updated = await userService.updateUserProfile(alice.value.id, {
            bio: 'Senior TypeScript engineer and open source contributor',
            avatar: 'https://example.com/avatars/alice.jpg',
        });

        if (updated.ok) {
            console.log('✓ Updated:', formatUser(updated.value));
        }

        // Update preferences
        console.log('\n⚙️  Updating user preferences...');
        const prefsUpdated = await userService.updateUserPreferences(bob.value.id, {
            theme: 'dark',
            language: 'en-US',
            notifications: false,
        });

        if (prefsUpdated.ok) {
            console.log('✓ Preferences updated for', prefsUpdated.value.name);
        }

        // Promote to admin
        console.log('\n👑 Promoting user to admin...');
        const promoted = await userService.promoteToAdmin(alice.value.id);

        if (promoted.ok) {
            console.log('✓ Promoted', promoted.value.name, 'to', promoted.value.role);
        }

        // List all users with pagination
        console.log('\n📋 Listing all users...');
        const allUsers = await userService.listUsers({
            sortBy: 'name',
            sortOrder: 'asc',
        });

        if (allUsers.ok) {
            console.log(`Found ${allUsers.value.length} users:`);
            allUsers.value.forEach((user, index) => {
                console.log(`  ${index + 1}. ${formatUser(user)}`);
            });
        }

        // Demonstrate type-safe queries
        console.log('\n🔍 Filtering users by role...');
        const adminUsers = await userService.listUsers({
            filters: { role: UserRole.Admin },
        });

        if (adminUsers.ok) {
            console.log(`Found ${adminUsers.value.length} admin(s):`);
            adminUsers.value.forEach(user => {
                console.log(`  - ${user.name} (${user.email})`);
            });
        }

        // Display events
        console.log('\n📨 Domain events generated:');
        const events = userService.getEvents();
        events.forEach((event, index) => {
            console.log(`  ${index + 1}. [${event.type}] at ${new Date(event.timestamp).toISOString()}`);
        });

        // Validation error demonstration
        console.log('\n❌ Testing validation errors...');
        const invalid = await userService.createUser(
            'X', // Too short
            'not-an-email', // Invalid email
            {
                firstName: '',
                lastName: 'Test',
            }
        );

        if (!invalid.ok) {
            console.log('✓ Correctly rejected invalid input:', formatError(invalid.error));
        }

        // Type safety demonstration
        console.log('\n🔒 Type safety features:');
        console.log('  ✓ Branded types (UserId, Email)');
        console.log('  ✓ Strict null checks');
        console.log('  ✓ Type guards and discriminated unions');
        console.log('  ✓ Generic constraints');
        console.log('  ✓ Advanced mapped types');

        console.log('\n✅ All operations completed successfully!');
        console.log('\nThis example demonstrates:');
        console.log('  • Repository pattern with generics');
        console.log('  • Service layer with business logic');
        console.log('  • Type-safe validation framework');
        console.log('  • Result types for error handling');
        console.log('  • Domain events');
        console.log('  • Advanced TypeScript type system');

    } catch (error) {
        console.error('\n💥 Unexpected error:', error);
        process.exit(1);
    }
}

// Handle unhandled rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// Run the application
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
