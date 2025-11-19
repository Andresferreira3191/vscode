#!/bin/bash
# StackCodeSy Security Scanning Script
# Scans Docker images for vulnerabilities and validates security configuration

set -e

IMAGE_NAME="${1:-stackcodesy:latest}"
SCAN_TOOL="${STACKCODESY_SCAN_TOOL:-trivy}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}StackCodeSy Security Scanner${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Image: $IMAGE_NAME"
echo "Scan Tool: $SCAN_TOOL"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo -e "${RED}Error: Image '$IMAGE_NAME' not found${NC}"
    echo "Build the image first: docker-compose build"
    exit 1
fi

# Function to check if tool is installed
check_tool() {
    local tool=$1
    if command -v "$tool" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $tool is installed"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $tool is not installed"
        return 1
    fi
}

# Scan with Trivy
scan_with_trivy() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Scanning with Trivy...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    if ! check_tool trivy; then
        echo "Install Trivy: https://github.com/aquasecurity/trivy"
        echo "  brew install trivy  # macOS"
        echo "  apt-get install trivy  # Debian/Ubuntu"
        return 1
    fi

    # Scan for vulnerabilities
    echo "Scanning for OS vulnerabilities..."
    trivy image --severity HIGH,CRITICAL "$IMAGE_NAME"

    echo ""
    echo "Scanning for misconfigurations..."
    trivy config --severity HIGH,CRITICAL .

    echo ""
    echo "Generating full report..."
    trivy image --format json --output trivy-report.json "$IMAGE_NAME"
    echo -e "${GREEN}✓${NC} Full report saved to: trivy-report.json"
}

# Scan with Docker Scout (if available)
scan_with_scout() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Scanning with Docker Scout...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    if ! docker scout version &>/dev/null; then
        echo "Docker Scout not available"
        echo "Enable it with: docker scout quickview"
        return 1
    fi

    docker scout cves "$IMAGE_NAME"
    docker scout recommendations "$IMAGE_NAME"
}

# Scan with Grype
scan_with_grype() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Scanning with Grype...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    if ! check_tool grype; then
        echo "Install Grype: https://github.com/anchore/grype"
        return 1
    fi

    grype "$IMAGE_NAME" -o table
    grype "$IMAGE_NAME" -o json > grype-report.json
    echo -e "${GREEN}✓${NC} Full report saved to: grype-report.json"
}

# Validate security configuration
validate_security_config() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Validating Security Configuration...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Check Dockerfile security best practices
    echo "Checking Dockerfile..."

    if grep -q "USER root" Dockerfile; then
        echo -e "${YELLOW}⚠${NC} Warning: Container runs as root"
    else
        echo -e "${GREEN}✓${NC} Container runs as non-root user"
    fi

    if grep -q "HEALTHCHECK" Dockerfile; then
        echo -e "${GREEN}✓${NC} Health check configured"
    else
        echo -e "${YELLOW}⚠${NC} Warning: No health check configured"
    fi

    # Check docker-compose.yml security
    echo ""
    echo "Checking docker-compose.yml..."

    if grep -q "cap_drop:" docker-compose*.yml; then
        echo -e "${GREEN}✓${NC} Capabilities are dropped"
    else
        echo -e "${YELLOW}⚠${NC} Warning: No capability restrictions"
    fi

    if grep -q "read_only: true" docker-compose*.yml; then
        echo -e "${GREEN}✓${NC} Read-only filesystem configured"
    else
        echo -e "${YELLOW}⚠${NC} Info: Read-only filesystem not configured"
    fi

    if grep -q "no-new-privileges" docker-compose*.yml; then
        echo -e "${GREEN}✓${NC} no-new-privileges enabled"
    else
        echo -e "${YELLOW}⚠${NC} Warning: no-new-privileges not enabled"
    fi

    # Check security profiles
    echo ""
    echo "Checking security profiles..."

    if [ -f "security/apparmor-profile.txt" ]; then
        echo -e "${GREEN}✓${NC} AppArmor profile exists"
    else
        echo -e "${YELLOW}⚠${NC} AppArmor profile not found"
    fi

    if [ -f "security/seccomp-profile.json" ]; then
        echo -e "${GREEN}✓${NC} Seccomp profile exists"
    else
        echo -e "${YELLOW}⚠${NC} Seccomp profile not found"
    fi
}

# Check for secrets in code
check_secrets() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Checking for Secrets in Code...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Simple regex-based secret detection
    echo "Scanning for potential secrets..."

    # Check for common secret patterns
    found_secrets=0

    if grep -r -i "password\s*=\s*['\"].*['\"]" --exclude-dir=node_modules --exclude="*.md" .; then
        echo -e "${RED}✗${NC} Found hardcoded passwords"
        ((found_secrets++))
    fi

    if grep -r -i "api[_-]?key\s*=\s*['\"].*['\"]" --exclude-dir=node_modules --exclude="*.md" .; then
        echo -e "${RED}✗${NC} Found hardcoded API keys"
        ((found_secrets++))
    fi

    if grep -r -i "secret\s*=\s*['\"].*['\"]" --exclude-dir=node_modules --exclude="*.md" --exclude=".env.example" .; then
        echo -e "${RED}✗${NC} Found hardcoded secrets"
        ((found_secrets++))
    fi

    if [ $found_secrets -eq 0 ]; then
        echo -e "${GREEN}✓${NC} No obvious secrets found in code"
    else
        echo -e "${RED}✗${NC} Found $found_secrets potential secret(s)"
        echo "Review and remove hardcoded secrets!"
    fi
}

# Generate security report
generate_report() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}Generating Security Report...${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    REPORT_FILE="security-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "StackCodeSy Security Scan Report"
        echo "================================="
        echo "Generated: $(date)"
        echo "Image: $IMAGE_NAME"
        echo ""
        echo "Summary:"
        echo "--------"
        docker image inspect "$IMAGE_NAME" --format '
Image ID: {{.Id}}
Created: {{.Created}}
Size: {{.Size}} bytes
Architecture: {{.Architecture}}
OS: {{.Os}}
'
        echo ""
        echo "Security Configuration:"
        echo "----------------------"
        echo "See detailed logs above"
        echo ""
    } > "$REPORT_FILE"

    echo -e "${GREEN}✓${NC} Security report saved to: $REPORT_FILE"
}

# Main execution
main() {
    case "$SCAN_TOOL" in
        "trivy")
            scan_with_trivy
            ;;
        "scout")
            scan_with_scout
            ;;
        "grype")
            scan_with_grype
            ;;
        "all")
            scan_with_trivy || true
            scan_with_scout || true
            scan_with_grype || true
            ;;
        *)
            echo -e "${YELLOW}Unknown scan tool: $SCAN_TOOL${NC}"
            echo "Supported tools: trivy, scout, grype, all"
            ;;
    esac

    echo ""
    validate_security_config
    echo ""
    check_secrets
    echo ""
    generate_report

    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${GREEN}Security scan complete!${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review scan results above"
    echo "2. Fix any HIGH or CRITICAL vulnerabilities"
    echo "3. Update base image and dependencies"
    echo "4. Re-scan after fixes"
    echo ""
    echo "For automated scanning in CI/CD:"
    echo "  ./scripts/security-scan.sh stackcodesy:latest"
}

main
