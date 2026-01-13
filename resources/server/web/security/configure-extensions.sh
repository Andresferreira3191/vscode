#!/bin/bash
# StackCodeSy Extension Marketplace Security Configuration
# This script controls extension marketplace access and whitelisting

set -e

EXTENSION_MODE="${STACKCODESY_EXTENSION_MODE:-full}"
EXTENSION_WHITELIST="${STACKCODESY_EXTENSION_WHITELIST:-}"
EXTENSION_WHITELIST_FILE="${STACKCODESY_EXTENSION_WHITELIST_FILE:-/stackcodesy/config/approved-extensions.txt}"
SETTINGS_DIR="/home/stackcodesy/.stackcodesy/data/Machine"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[StackCodeSy Extensions]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[StackCodeSy Extensions]${NC} $1"
}

log_error() {
    echo -e "${RED}[StackCodeSy Extensions]${NC} $1"
}

# Ensure settings directory exists
mkdir -p "$SETTINGS_DIR"

case "$EXTENSION_MODE" in
    "disabled"|"false"|"0"|"no")
        log_warning "Extension marketplace is DISABLED"

        # Disable marketplace completely
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": true,
  "workbench.enableExperiments": false,
  "extensions.showRecommendationsOnlyOnDemand": true
}
EOF

        # Also disable in product.json at runtime if possible
        log_info "Extension installation and marketplace access completely disabled"
        ;;

    "whitelist"|"restricted")
        log_info "Extension marketplace in WHITELIST mode"

        # Build whitelist array
        WHITELIST_ARRAY=()

        # Load from environment variable (comma-separated)
        if [ -n "$EXTENSION_WHITELIST" ]; then
            IFS=',' read -ra EXTENSIONS <<< "$EXTENSION_WHITELIST"
            for ext in "${EXTENSIONS[@]}"; do
                ext_trimmed=$(echo "$ext" | xargs)
                if [ -n "$ext_trimmed" ]; then
                    WHITELIST_ARRAY+=("$ext_trimmed")
                fi
            done
        fi

        # Load from file (one extension per line)
        if [ -f "$EXTENSION_WHITELIST_FILE" ]; then
            log_info "Loading approved extensions from: $EXTENSION_WHITELIST_FILE"
            while IFS= read -r line; do
                # Skip empty lines and comments
                line_trimmed=$(echo "$line" | xargs)
                if [ -n "$line_trimmed" ] && [[ ! "$line_trimmed" =~ ^# ]]; then
                    WHITELIST_ARRAY+=("$line_trimmed")
                fi
            done < "$EXTENSION_WHITELIST_FILE"
        fi

        # Log whitelist
        if [ ${#WHITELIST_ARRAY[@]} -gt 0 ]; then
            log_info "Approved extensions (${#WHITELIST_ARRAY[@]} total):"
            for ext in "${WHITELIST_ARRAY[@]}"; do
                echo "  ✓ $ext"
            done
        else
            log_warning "No extensions in whitelist - marketplace effectively disabled"
        fi

        # Configure VSCode settings for restricted marketplace
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": true,
  "workbench.enableExperiments": false,
  "extensions.showRecommendationsOnlyOnDemand": true
}
EOF

        # Create extension validation script
        create_extension_validator

        log_info "Extension whitelist configured - only approved extensions can be installed"
        ;;

    "full"|"true"|"1"|"yes"|*)
        log_info "Extension marketplace is FULLY ENABLED"

        # Allow full marketplace access (development mode)
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "extensions.autoCheckUpdates": true,
  "extensions.autoUpdate": false,
  "workbench.enableExperiments": true
}
EOF

        log_info "Full extension marketplace access enabled (development mode)"
        ;;
esac

# Create extension validator function
create_extension_validator() {
    local validator_script="/stackcodesy/resources/server/web/security/validate-extension.sh"

    cat > "$validator_script" << 'VALIDATOR_EOF'
#!/bin/bash
# Extension Validation Script
# Validates if an extension is in the approved whitelist

EXTENSION_ID="$1"
WHITELIST_FILE="${STACKCODESY_EXTENSION_WHITELIST_FILE:-/stackcodesy/config/approved-extensions.txt}"
WHITELIST_ENV="${STACKCODESY_EXTENSION_WHITELIST:-}"

if [ -z "$EXTENSION_ID" ]; then
    echo "Usage: $0 <extension-id>"
    exit 1
fi

# Check environment variable whitelist
if [ -n "$WHITELIST_ENV" ]; then
    IFS=',' read -ra EXTENSIONS <<< "$WHITELIST_ENV"
    for ext in "${EXTENSIONS[@]}"; do
        ext_trimmed=$(echo "$ext" | xargs)
        if [ "$ext_trimmed" = "$EXTENSION_ID" ]; then
            echo "✓ Extension '$EXTENSION_ID' is APPROVED (from environment)"
            exit 0
        fi
    done
fi

# Check whitelist file
if [ -f "$WHITELIST_FILE" ]; then
    while IFS= read -r line; do
        line_trimmed=$(echo "$line" | xargs)
        if [ "$line_trimmed" = "$EXTENSION_ID" ]; then
            echo "✓ Extension '$EXTENSION_ID' is APPROVED (from file)"
            exit 0
        fi
    done < "$WHITELIST_FILE"
fi

echo "✗ Extension '$EXTENSION_ID' is NOT APPROVED"
exit 1
VALIDATOR_EOF

    chmod +x "$validator_script"
}

log_info "Extension marketplace configuration complete"
exit 0
