# Development Guide

## Quick Start

```bash
make test      # Run tests locally
make format    # Format code
make clean     # Clean build artifacts
```

## Linux Testing with Podman

The full test matrix covers 5 Swift versions × 5 swift-syntax versions = 25 combinations.

```bash
make test-linux   # Run full matrix with auto-detected parallelism
```

### Podman Setup

```bash
# First time, or to reconfigure
bin/setup-podman

# Quick start (non-interactive)
bin/setup-podman --auto

# Check status
bin/setup-podman --status
```

The setup script detects your system resources and offers appropriate configurations.

### Advanced Usage

The `bin/test-linux` script supports many options:

```bash
# Preview without running
./bin/test-linux --dry-run

# Test specific combinations
./bin/test-linux --swift 6.0 --swift-syntax 600
./bin/test-linux --swift 6                    # All Swift 6.x versions

# Override auto-detected parallelism
./bin/test-linux --parallel 4 --continue-on-error

# Save logs for analysis
./bin/test-linux --parallel --continue-on-error --log-dir ./logs

# Debug a specific failure
./bin/test-linux --swift 6.2 --swift-syntax 601 --verbose

# Run sequentially (no parallelism)
./bin/test-linux --sequential
```

### Troubleshooting

**OOM errors (signal 9/137)**: Reduce parallel jobs or reconfigure Podman VM:
```bash
bin/setup-podman  # Choose "Light" or reconfigure with less memory
```

**Sporadic compiler crashes**: Swift on arm64 Linux occasionally crashes with `error: fatalError`. The script auto-retries up to 2 times. If failures persist:
```bash
./bin/test-linux --swift <version> --swift-syntax <version> --verbose
```

**Podman not running**:
```bash
bin/setup-podman --auto
```

**Stale build artifacts**:
```bash
make clean
rm -rf .build-*-*
```

## Testing swift-syntax Versions Locally

```bash
SWIFT_SYNTAX_VERSION="600.0.0..<601.0.0" swift test
```

Available ranges: `509.0.0..<510.0.0`, `510.0.0..<511.0.0`, `600.0.0..<601.0.0`, `601.0.0..<602.0.0`, `602.0.0..<603.0.0`
