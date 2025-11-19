#!/bin/bash
#---------------------------------------------------------------------------------------------
#  Copyright (c) StackCodeSy. All rights reserved.
#  Licensed under the MIT License.
#---------------------------------------------------------------------------------------------

# StackCodeSy Terminal Control Script
# This script configures terminal access mode: disabled, restricted, or full

set -e

TERMINAL_MODE="${STACKCODESY_TERMINAL_MODE:-full}"
CONFIG_DIR="/home/stackcodesy/.stackcodesy/User"
SETTINGS_FILE="$CONFIG_DIR/settings.json"
RESTRICTED_SHELL="/stackcodesy/resources/server/web/security/restricted-shell.sh"

echo "========================================="
echo "StackCodeSy: Terminal Configuration"
echo "========================================="
echo "Mode: $TERMINAL_MODE"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

case "$TERMINAL_MODE" in
    "disabled"|"false"|"0"|"no")
        echo ""
        echo "🔒 DISABLING terminal access (maximum security)"
        echo ""

        # Create settings that disable terminal completely
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "terminal.integrated.enabled": false,
  "terminal.integrated.hideOnStartup": "always",
  "terminal.integrated.allowChords": false,
  "terminal.integrated.allowWorkspaceConfiguration": false,
  "terminal.integrated.commandsToSkipShell": [],
  "terminal.integrated.defaultProfile.linux": "",
  "terminal.integrated.defaultProfile.osx": "",
  "terminal.integrated.defaultProfile.windows": "",
  "terminal.integrated.profiles.linux": {},
  "terminal.integrated.profiles.osx": {},
  "terminal.integrated.profiles.windows": {},
  "terminal.external.linuxExec": "",
  "terminal.external.osxExec": "",
  "terminal.external.windowsExec": "",
  "task.allowAutomaticTasks": "off",
  "task.autoDetect": "off",
  "debug.allowBreakpointsEverywhere": false,
  "debug.console.closeOnEnd": true,
  "debug.internalConsoleOptions": "neverOpen"
}
EOF

        echo "✅ Terminal access DISABLED"
        echo "✅ All terminal profiles removed"
        echo "✅ Task execution disabled"
        echo "✅ Debug console disabled"
        ;;

    "restricted")
        echo ""
        echo "⚠️  RESTRICTED terminal mode (limited commands)"
        echo ""

        # Get restriction settings
        WORKSPACE_ONLY="${STACKCODESY_TERMINAL_WORKSPACE_ONLY:-true}"
        ALLOWED_COMMANDS="${STACKCODESY_TERMINAL_ALLOWED_COMMANDS:-npm,yarn,node,git,python,python3,pip,make,gcc,cargo,go}"
        WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"

        echo "Configuration:"
        echo "  - Workspace Only: $WORKSPACE_ONLY"
        echo "  - Workspace Dir: $WORKSPACE_DIR"
        echo "  - Allowed Commands: $ALLOWED_COMMANDS"
        echo ""

        # Create settings for restricted terminal using custom shell
        cat > "$SETTINGS_FILE" << EOF
{
  "terminal.integrated.enabled": true,
  "terminal.integrated.defaultProfile.linux": "StackCodeSy Restricted",
  "terminal.integrated.profiles.linux": {
    "StackCodeSy Restricted": {
      "path": "$RESTRICTED_SHELL",
      "icon": "shield",
      "color": "terminal.ansiYellow"
    }
  },
  "terminal.integrated.allowWorkspaceConfiguration": false,
  "terminal.integrated.allowChords": true,
  "terminal.integrated.cwd": "$WORKSPACE_DIR",
  "terminal.integrated.confirmOnExit": "always",
  "terminal.integrated.confirmOnKill": "always",
  "terminal.integrated.enablePersistentSessions": false,
  "task.allowAutomaticTasks": "off",
  "task.autoDetect": "off",
  "debug.allowBreakpointsEverywhere": false
}
EOF

        echo "✅ Restricted terminal ENABLED"
        echo "✅ Using restricted shell: $RESTRICTED_SHELL"
        echo "✅ Workspace restrictions applied"
        echo "✅ Command whitelist active"
        ;;

    "full"|"true"|"1"|"yes"|*)
        echo ""
        echo "✅ FULL terminal access (development mode)"
        echo ""

        # Create settings for full terminal access
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "terminal.integrated.enabled": true,
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.profiles.linux": {
    "bash": {
      "path": "/bin/bash",
      "icon": "terminal-bash"
    }
  },
  "terminal.integrated.allowWorkspaceConfiguration": true
}
EOF

        echo "✅ Full terminal access ENABLED"
        echo "✅ All commands available"
        echo "⚠️  WARNING: Use only in trusted environments"
        ;;
esac

echo ""
echo "========================================="
echo "Terminal Configuration Complete"
echo "Settings file: $SETTINGS_FILE"
echo "========================================="
