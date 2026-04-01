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

# Swift version → compatible Xcode mapping for macOS multi-version builds.
# Each toolchain needs an SDK from a compatible Xcode version.
SWIFT_VERSIONS := 5.9 5.10 6.0 6.1 6.2
SWIFT_VERSIONS_MACOS := 5.9 5.10 6.0 6.1 6.2
XCODE_5.9  := /Applications/Xcode-15.4.0.app
XCODE_5.10 := /Applications/Xcode-15.4.0.app
XCODE_6.0  := /Applications/Xcode-16.0.0.app
XCODE_6.1  := /Applications/Xcode-16.3.0.app
XCODE_6.2  := /Applications/Xcode-26.0.1.app

preflight-swiftly:
	@swiftly --version > /dev/null 2>&1 || { echo "Error: swiftly is not installed. Install it with: brew install swiftly"; exit 1; }

# Build the example client across Swift versions on macOS via swiftly.
# Requires multiple Xcode versions installed (older toolchains need matching SDKs).
build-client-macos: preflight-swiftly
	@for swift_ver in $(SWIFT_VERSIONS_MACOS); do \
		echo "## Ensuring Swift $$swift_ver is installed"; \
		swiftly install $$swift_ver --assume-yes; \
	done
	@set -e; \
	for swift_ver in $(SWIFT_VERSIONS_MACOS); do \
		case $$swift_ver in \
			5.9)  xcode_path="$(XCODE_5.9)" ;; \
			5.10) xcode_path="$(XCODE_5.10)" ;; \
			6.0)  xcode_path="$(XCODE_6.0)" ;; \
			6.1)  xcode_path="$(XCODE_6.1)" ;; \
			6.2)  xcode_path="$(XCODE_6.2)" ;; \
		esac; \
		if [ ! -d "$$xcode_path" ]; then \
			echo "Error: $$xcode_path not found (needed for Swift $$swift_ver)"; \
			exit 1; \
		fi; \
		echo "\n## Building client with Swift $$swift_ver (macOS, $$(basename $$xcode_path))"; \
		DEVELOPER_DIR="$$xcode_path/Contents/Developer" \
			swiftly run swift build +$$swift_ver --build-path .build-client-macos-$$swift_ver --target MemberwiseInitClient; \
	done
	@rm -rf .build-client-macos-* 2>/dev/null

# Build the example client across Swift versions on Linux via Podman.
build-client-linux: preflight-podman
	@for swift_ver in $(SWIFT_VERSIONS); do \
		echo "\n## Building client with Swift $$swift_ver (Linux)"; \
		build_dir=".build-client-linux-$$swift_ver"; \
		rm -rf "$$build_dir" 2>/dev/null; \
		mkdir -p "$$build_dir"; \
		podman run --rm \
			-v "$$(pwd)":/workspace \
			-v "$$(pwd)/$$build_dir":/workspace/.build \
			-w /workspace \
			"swift:$$swift_ver" \
			swift build --target MemberwiseInitClient || exit 1; \
	done
	@rm -rf .build-client-linux-* 2>/dev/null

build-client-all: build-client-macos build-client-linux

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: default test build-client build-client-macos build-client-linux build-client-all test-swift clean test-all preflight-swiftly preflight-podman test-swift-syntax-versions test-linux format
