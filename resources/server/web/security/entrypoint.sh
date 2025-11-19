#!/bin/bash
#---------------------------------------------------------------------------------------------
#  Copyright (c) StackCodeSy. All rights reserved.
#  Licensed under the MIT License.
#---------------------------------------------------------------------------------------------

# StackCodeSy Entrypoint Script
# Configures security settings before starting the editor

set -e

echo "========================================="
echo "StackCodeSy - Code Editor"
echo "Security Configuration"
echo "========================================="

# Configure terminal access
/stackcodesy/resources/server/web/security/configure-terminal.sh

echo ""
echo "========================================="
echo "Starting StackCodeSy Editor..."
echo "========================================="

# Execute the original command (code-web.sh)
exec "$@"
