# FlowBar Makefile
# Usage: make <target>

SCHEME        = FlowBar
CONFIGURATION = Debug
DERIVED_DATA  = .build/DerivedData
APP_NAME      = FlowBar

.PHONY: setup generate build run clean archive lint

# ── Setup ────────────────────────────────────────────────────────────────────
setup:
	@bash setup.sh

generate:
	@echo "→ Generating Xcode project…"
	xcodegen generate --spec project.yml
	@echo "✓ Done"

# ── Build ────────────────────────────────────────────────────────────────────
build: generate
	@echo "→ Building $(APP_NAME)…"
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=macOS' \
		build | xcbeautify || xcodebuild \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=macOS' \
		build

# ── Run ──────────────────────────────────────────────────────────────────────
run: build
	@echo "→ Launching $(APP_NAME)…"
	open "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app"

# ── Archive (for distribution) ────────────────────────────────────────────────
archive: generate
	xcodebuild \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=macOS' \
		archive \
		-archivePath .build/$(APP_NAME).xcarchive

# ── Clean ────────────────────────────────────────────────────────────────────
clean:
	@echo "→ Cleaning…"
	rm -rf $(DERIVED_DATA) FlowBar.xcodeproj
	@echo "✓ Cleaned"

# ── Lint (SwiftLint) ─────────────────────────────────────────────────────────
lint:
	@if command -v swiftlint &>/dev/null; then \
		swiftlint lint --config .swiftlint.yml 2>/dev/null || swiftlint lint; \
	else \
		echo "SwiftLint not installed. Run: brew install swiftlint"; \
	fi

# ── Help ─────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "FlowBar - available make targets:"
	@echo ""
	@echo "  setup     Install dependencies and generate Xcode project"
	@echo "  generate  Regenerate Xcode project from project.yml"
	@echo "  build     Build the app"
	@echo "  run       Build and launch the app"
	@echo "  archive   Create a release archive"
	@echo "  clean     Remove build artifacts"
	@echo "  lint      Run SwiftLint"
	@echo ""
