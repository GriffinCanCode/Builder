# Cloud Provider Unit Tests

This directory contains comprehensive unit tests for the cloud provider implementations used in Builder's remote execution system.

## Test Coverage

### File: `remote_providers_test.d`

Comprehensive test suite for all cloud provider implementations:

#### Test Categories

1. **MockCloudProvider Tests**
   - Basic provisioning and termination
   - Worker status queries
   - Full lifecycle management
   - Multiple worker provisioning
   - Concurrent operations
   - IP address assignment

2. **AWS EC2 Provider Tests**
   - Interface validation
   - Provider creation with credentials
   - (Note: Actual AWS API calls require credentials and are not tested)

3. **GCP Compute Provider Tests**
   - Interface validation
   - Provider creation with project configuration
   - (Note: Actual GCP API calls require credentials and are not tested)

4. **Kubernetes Provider Tests**
   - Interface validation
   - Provider creation with namespace configuration
   - (Note: Actual K8s API calls require a cluster and are not tested)

5. **Worker Status Tests**
   - All state transitions (Pending, Running, Stopping, Stopped, Failed)
   - Status field validation (IPs, launch time)

6. **Error Handling Tests**
   - Invalid worker IDs
   - Double termination (idempotency)
   - Non-existent worker queries

7. **Interface Compliance Tests**
   - Verifies all providers implement `CloudProvider` interface

8. **Worker Metadata Tests**
   - Tag support
   - Instance type variations

## Running the Tests

### Run all tests:
```bash
make test
```

### Run only provider tests:
```bash
dub test --single tests/unit/core/remote_providers_test.d
```

### Run with verbose output:
```bash
dub test -- --verbose
```

## Implementation Notes

### WorkerId Handling

The providers use a mapping system to convert cloud-specific string IDs to numeric WorkerIds:

- **AWS**: Instance IDs (e.g., "i-1234567") are hashed to create WorkerId
- **GCP**: Instance names are hashed to create WorkerId
- **Kubernetes**: Pod names are hashed to create WorkerId
- **Mock**: Generates random ulong values directly

Each provider maintains an internal map (`instanceIdMap`, `instanceNameMap`, `podNameMap`) to translate between WorkerId and the actual cloud resource identifier.

### Mock Provider Behavior

The MockCloudProvider removes terminated workers from its internal map, simulating real cloud provider behavior where terminated resources are no longer queryable.

## Dependencies

- `engine.runtime.remote.providers.base` - Base interfaces
- `engine.runtime.remote.providers.mock` - Mock implementation
- `engine.runtime.remote.providers.aws` - AWS EC2 provider
- `engine.runtime.remote.providers.gcp` - GCP Compute provider
- `engine.runtime.remote.providers.kubernetes` - Kubernetes provider
- `infrastructure.errors` - Error handling
- `std.digest.murmurhash` - Hash functions for ID conversion

## Test Results

All tests should pass. Expected output:

```
=== Cloud Provider Tests ===

Testing MockCloudProvider...
  ✓ Provisioned mock worker: <id>
  ✓ Worker status: Running
  ✓ Terminated mock worker
  ✓ Worker properly removed after termination

Testing AwsEc2Provider interface...
  ✓ AWS provider created
  ✓ AWS provider interface validated

... (additional test output)

=== All Tests Passed ===
```

## Future Enhancements

1. **Integration Tests**: Add tests that interact with actual cloud providers (require credentials/resources)
2. **Mocking Framework**: Use a proper mocking framework for external API calls
3. **Performance Tests**: Measure provisioning and termination times
4. **Failure Scenarios**: Test network failures, timeouts, rate limiting
5. **Resource Cleanup**: Automated cleanup of orphaned test resources

