#!/bin/bash
# FlowBar Setup Script
# Installs dependencies and generates the Xcode project

set -euo pipefail

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLU}[FlowBar]${NC} $1"; }
ok()   { echo -e "${GRN}  ✓${NC} $1"; }
warn() { echo -e "${YEL}  ⚠${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

echo ""
echo "  ⚡  FlowBar Setup"
echo "  ─────────────────────────────"
echo ""

# ── Check macOS version ───────────────────────────────────────────────────────
MACOS_VER=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
    err "FlowBar requires macOS 14 (Sonoma) or later. You have macOS $MACOS_VER."
fi
ok "macOS $MACOS_VER detected"

# ── Check Xcode ───────────────────────────────────────────────────────────────
if ! command -v xcodebuild &>/dev/null; then
    err "Xcode not found. Install Xcode from the App Store: https://apps.apple.com/app/xcode/id497799835"
fi
XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1)
ok "$XCODE_VER detected"

# ── Install Homebrew if needed ────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
ok "Homebrew available"

# ── Install XcodeGen ─────────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    log "Installing XcodeGen…"
    brew install xcodegen
fi
ok "XcodeGen available ($(xcodegen --version 2>/dev/null || echo 'unknown version'))"

# ── Generate Xcode project ────────────────────────────────────────────────────
log "Generating Xcode project…"
xcodegen generate --spec project.yml
ok "FlowBar.xcodeproj generated"

# ── Create script directory ───────────────────────────────────────────────────
SCRIPTS_DIR="$HOME/.flowbar/scripts"
mkdir -p "$SCRIPTS_DIR"
ok "Scripts directory: $SCRIPTS_DIR"

# ── Copy example scripts ──────────────────────────────────────────────────────
if [ -f "FlowBar/Resources/ai_token_monitor.py" ]; then
    cp "FlowBar/Resources/ai_token_monitor.py" "$SCRIPTS_DIR/"
    chmod +x "$SCRIPTS_DIR/ai_token_monitor.py"
    ok "Installed ai_token_monitor.py"
fi

# ── Create LaunchAgents directory ─────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"
ok "LaunchAgents directory ready"

# ── Open in Xcode ────────────────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────"
echo -e "  ${GRN}✅ Setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "  1. Open FlowBar.xcodeproj in Xcode"
echo "  2. Set your Team in Signing & Capabilities"
echo "  3. Build & Run (⌘R)"
echo ""
echo "  Or open now:"

if command -v open &>/dev/null; then
    read -r -p "  Open FlowBar.xcodeproj now? [Y/n] " response
    response=${response:-Y}
    if [[ "$response" =~ ^[Yy]$ ]]; then
        open FlowBar.xcodeproj
    fi
fi

echo ""
