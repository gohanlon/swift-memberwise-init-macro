default: test

test: test-swift

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

test-swift-syntax-versions:
	@for version in \
		"509.0.0..<510.0.0" \
		"510.0.0..<511.0.0" \
		"600.0.0..<601.0.0" \
		"601.0.0..<602.0.0" \
		"602.0.0..<603.0.0"; \
	do \
		echo "\n## Testing SwiftSyntax version $$version"; \
		$(MAKE) clean; \
		SWIFT_SYNTAX_VERSION="$$version" $(MAKE) test-swift || exit 1; \
	done

# Test Swift × swift-syntax combinations on Linux via Podman.
# Uses auto-detected parallelism. See bin/test-linux --help for options.
test-linux:
	./bin/test-linux --parallel --continue-on-error --log-dir ./tmp/logs

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: default test test-swift clean test-swift-syntax-versions test-linux format
