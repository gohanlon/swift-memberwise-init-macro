default: test

test: test-swift

test-swift:
	swift test --parallel

clean:
	rm -rf .build

test-swift-syntax-versions:
	@for version in \
		"509.0.0..<510.0.0" \
		"510.0.0..<511.0.0" \
		"511.0.0..<601.0.0"; \
	do \
		echo "\n## Testing SwiftSyntax version $$version"; \
		$(MAKE) clean; \
		SWIFT_SYNTAX_VERSION="$$version" $(MAKE) test-swift || exit 1; \
	done

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: default test test-swift clean test-swift-syntax-versions format
