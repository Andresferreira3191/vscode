#!/bin/bash
#---------------------------------------------------------------------------------------------
#  Copyright (c) StackCodeSy. All rights reserved.
#  Licensed under the MIT License.
#---------------------------------------------------------------------------------------------

# StackCodeSy Entrypoint Script
# Configures comprehensive security settings before starting the editor

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}StackCodeSy - Code Editor${NC}"
echo -e "${BLUE}Comprehensive Security Configuration${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Make all security scripts executable
chmod +x /stackcodesy/resources/server/web/security/*.sh 2>/dev/null || true

# 1. Configure Extension Marketplace Security
echo -e "${YELLOW}[1/6]${NC} Configuring extension marketplace security..."
if [ -f /stackcodesy/resources/server/web/security/configure-extensions.sh ]; then
    /stackcodesy/resources/server/web/security/configure-extensions.sh
fi

# 2. Configure Terminal Security
echo ""
echo -e "${YELLOW}[2/6]${NC} Configuring terminal security..."
if [ -f /stackcodesy/resources/server/web/security/configure-terminal.sh ]; then
    /stackcodesy/resources/server/web/security/configure-terminal.sh
fi

# 3. Configure File System Security
echo ""
echo -e "${YELLOW}[3/6]${NC} Configuring filesystem security..."
if [ -f /stackcodesy/resources/server/web/security/configure-filesystem.sh ]; then
    /stackcodesy/resources/server/web/security/configure-filesystem.sh
fi

# 4. Configure Network Security
echo ""
echo -e "${YELLOW}[4/6]${NC} Configuring network security..."
if [ -f /stackcodesy/resources/server/web/security/configure-network.sh ]; then
    /stackcodesy/resources/server/web/security/configure-network.sh || echo "Network configuration skipped (requires NET_ADMIN capability)"
fi

# 5. Configure Audit Logging
echo ""
echo -e "${YELLOW}[5/6]${NC} Configuring audit logging..."
if [ -f /stackcodesy/resources/server/web/security/configure-audit-logging.sh ]; then
    /stackcodesy/resources/server/web/security/configure-audit-logging.sh
fi

# 6. Configure Content Security Policy
echo ""
echo -e "${YELLOW}[6/6]${NC} Configuring Content Security Policy..."
if [ -f /stackcodesy/resources/server/web/security/configure-csp.sh ]; then
    /stackcodesy/resources/server/web/security/configure-csp.sh || echo "CSP configuration skipped"
fi

# Security Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Security Configuration Summary${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Authentication: ${STACKCODESY_REQUIRE_AUTH:-false}"
echo "Terminal Mode: ${STACKCODESY_TERMINAL_MODE:-full}"
echo "Extension Mode: ${STACKCODESY_EXTENSION_MODE:-full}"
echo "Audit Logging: ${STACKCODESY_ENABLE_AUDIT_LOG:-true}"
echo "Disk Quota: ${STACKCODESY_DISK_QUOTA_MB:-5000}MB"
echo "Egress Filter: ${STACKCODESY_ENABLE_EGRESS_FILTER:-false}"
echo "CSP Enabled: ${STACKCODESY_ENABLE_CSP:-true}"
echo ""

# Log startup event
if [ -f /usr/local/bin/audit-log.sh ]; then
    /usr/local/bin/audit-log.sh "system" "StackCodeSy starting with security configuration" "INFO" 2>/dev/null || true
fi

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Starting StackCodeSy Editor...${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Execute the original command (code-web.sh)
exec "$@"
