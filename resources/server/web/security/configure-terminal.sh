#!/bin/bash
#---------------------------------------------------------------------------------------------
#  Copyright (c) StackCodeSy. All rights reserved.
#  Licensed under the MIT License.
#---------------------------------------------------------------------------------------------

# StackCodeSy Terminal Control Script
# This script configures whether terminals are enabled or disabled in the editor

set -e

ENABLE_TERMINAL="${STACKCODESY_ENABLE_TERMINAL:-true}"
CONFIG_DIR="/home/stackcodesy/.stackcodesy/User"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

echo "StackCodeSy: Configuring terminal settings..."
echo "StackCodeSy: STACKCODESY_ENABLE_TERMINAL=${ENABLE_TERMINAL}"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

if [ "$ENABLE_TERMINAL" = "false" ] || [ "$ENABLE_TERMINAL" = "0" ] || [ "$ENABLE_TERMINAL" = "no" ]; then
    echo "StackCodeSy: DISABLING terminal access (security mode)"

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
  "debug.internalConsoleOptions": "neverOpen",
  "comments.visible": false,
  "scm.showActionButton": false
}
EOF

    echo "StackCodeSy: Terminal access DISABLED"
    echo "StackCodeSy: All terminal profiles removed"
    echo "StackCodeSy: Task execution disabled"

else
    echo "StackCodeSy: ENABLING terminal access (default mode)"

    # Create minimal settings that allow terminal
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "terminal.integrated.enabled": true,
  "terminal.integrated.defaultProfile.linux": "bash"
}
EOF

    echo "StackCodeSy: Terminal access ENABLED"
fi

echo "StackCodeSy: Terminal configuration complete"
echo "StackCodeSy: Settings file: $SETTINGS_FILE"
