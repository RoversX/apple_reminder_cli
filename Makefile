SHELL := /bin/bash

.PHONY: help format lint test check build apple_reminder_cli clean

help:
	@printf "%s\n" \
		"make format    - swift format in-place" \
		"make lint      - swift format lint + swiftlint" \
		"make test      - sync version + swift test (coverage enabled)" \
		"make check     - lint + test + coverage gate" \
		"make build     - release build into bin/ (codesigned)" \
		"make apple_reminder_cli - clean rebuild + run debug binary (ARGS=...)" \
		"make clean     - swift package clean"

format:
	swift format --in-place --recursive Sources Tests

lint:
	swift format lint --recursive Sources Tests
	swiftlint

test:
	scripts/generate-version.sh
	swift test --enable-code-coverage

check:
	$(MAKE) lint
	$(MAKE) test
	scripts/check-coverage.sh

build:
	scripts/generate-version.sh
	mkdir -p bin dist
	swift build -c release --product apple_reminder_cli --arch arm64
	swift build -c release --product apple_reminder_cli --arch x86_64
	lipo -create -output bin/apple_reminder_cli \
		.build/arm64-apple-macosx/release/apple_reminder_cli \
		.build/x86_64-apple-macosx/release/apple_reminder_cli
	codesign --force --sign - --identifier com.roversx.apple_reminder_cli bin/apple_reminder_cli
	cp bin/apple_reminder_cli dist/apple_reminder_cli
	cd dist && zip -r apple_reminder_cli-macos.zip apple_reminder_cli
	@echo "sha256: $$(shasum -a 256 dist/apple_reminder_cli-macos.zip | awk '{print $$1}')"

apple_reminder_cli:
	scripts/generate-version.sh
	swift package clean
	swift build -c debug --product apple_reminder_cli
	./.build/debug/apple_reminder_cli $(ARGS)

clean:
	swift package clean
