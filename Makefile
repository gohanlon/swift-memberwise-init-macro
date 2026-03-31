default: test

test: build-client test-swift

# Verify the example client compiles (swift test doesn't build executable targets)
build-client:
	swift build --target MemberwiseInitClient

test-swift:
	swift test --parallel

# Remove build artifacts while tolerating SourceKit-locked files
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf .build/* 2>&1 | grep -v "Permission denied" || true
	@echo "Checking remaining build artifacts..."
	@if [ -d .build ]; then \
		ls -R .build 2>/dev/null || echo "Unable to list some directories"; \
	else \
		echo "Build directory completely removed"; \
	fi
	@echo "Build artifacts cleaned (ensure that any remaining files listed above won't affect new builds, e.g. SourceKit files)"

# Run all tests: swift-syntax version matrix (macOS) + Linux via Podman.
# Use this before submitting PRs.
test-all: preflight-podman test-swift-syntax-versions test-linux

preflight-podman:
	@podman info > /dev/null 2>&1 || { echo "Error: Podman is not running. Start it with: podman machine start"; exit 1; }

test-swift-syntax-versions:
	@for version in \
		"509.0.0..<510.0.0" \
		"510.0.0..<511.0.0" \
		"600.0.0..<601.0.0" \
		"601.0.0..<602.0.0" \
		"602.0.0..<603.0.0" \
		"603.0.0..<604.0.0" \
		"604.0.0-prerelease..<605.0.0"; \
	do \
		echo "\n## Testing SwiftSyntax version $$version"; \
		$(MAKE) clean; \
		SWIFT_SYNTAX_VERSION="$$version" $(MAKE) test-swift || exit 1; \
	done

# Test Swift × swift-syntax combinations on Linux via Podman.
# Uses auto-detected parallelism. See bin/test-linux --help for options.
test-linux:
	./bin/test-linux --parallel --continue-on-error --log-dir ./tmp/logs

# Build the example client across Swift versions on Linux via Podman.
# Use before releases or after major changes to main.swift.
build-client-linux: preflight-podman
	@for swift_ver in 5.9 5.10 6.0 6.1 6.2; do \
		echo "\n## Building client with Swift $$swift_ver"; \
		build_dir=".build-client-$$swift_ver"; \
		rm -rf "$$build_dir" 2>/dev/null; \
		mkdir -p "$$build_dir"; \
		podman run --rm \
			-v "$$(pwd)":/workspace \
			-v "$$(pwd)/$$build_dir":/workspace/.build \
			-w /workspace \
			"swift:$$swift_ver" \
			swift build --target MemberwiseInitClient || exit 1; \
	done
	@rm -rf .build-client-* 2>/dev/null

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: default test build-client test-swift clean test-all preflight-podman test-swift-syntax-versions test-linux build-client-linux format
