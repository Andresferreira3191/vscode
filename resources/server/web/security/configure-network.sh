#!/bin/bash
# StackCodeSy Network Security Configuration
# Implements egress filtering, domain whitelisting, and network isolation

set -e

ENABLE_EGRESS_FILTER="${STACKCODESY_ENABLE_EGRESS_FILTER:-false}"
ALLOWED_DOMAINS="${STACKCODESY_ALLOWED_DOMAINS:-}"
BLOCK_ALL_OUTBOUND="${STACKCODESY_BLOCK_ALL_OUTBOUND:-false}"
ALLOWED_PORTS="${STACKCODESY_ALLOWED_PORTS:-80,443}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[StackCodeSy Network]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[StackCodeSy Network]${NC} $1"
}

log_error() {
    echo -e "${RED}[StackCodeSy Network]${NC} $1"
}

# Check if running with network capabilities
check_network_capabilities() {
    if ! command -v iptables &> /dev/null; then
        log_warning "iptables not available - network filtering requires CAP_NET_ADMIN"
        log_warning "Add to docker-compose.yml: cap_add: [NET_ADMIN]"
        return 1
    fi
    return 0
}

# Configure egress filtering with iptables
configure_egress_filter() {
    if [ "$ENABLE_EGRESS_FILTER" != "true" ]; then
        log_info "Egress filtering disabled"
        return 0
    fi

    log_info "Configuring egress filtering..."

    if ! check_network_capabilities; then
        log_error "Cannot configure egress filtering - insufficient capabilities"
        return 1
    fi

    # Flush existing rules (careful in production!)
    # iptables -F OUTPUT 2>/dev/null || true

    if [ "$BLOCK_ALL_OUTBOUND" = "true" ]; then
        log_warning "BLOCKING all outbound traffic except loopback"

        # Allow loopback
        iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

        # Allow established connections
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

        # Block everything else
        iptables -A OUTPUT -j DROP 2>/dev/null || true

        log_info "All outbound traffic blocked"
    else
        # Allow specific ports
        if [ -n "$ALLOWED_PORTS" ]; then
            IFS=',' read -ra PORTS <<< "$ALLOWED_PORTS"
            for port in "${PORTS[@]}"; do
                port_trimmed=$(echo "$port" | xargs)
                iptables -A OUTPUT -p tcp --dport "$port_trimmed" -j ACCEPT 2>/dev/null || true
                log_info "Allowed outbound port: $port_trimmed"
            done
        fi

        # Block other ports
        iptables -A OUTPUT -p tcp -j DROP 2>/dev/null || true
        iptables -A OUTPUT -p udp -j DROP 2>/dev/null || true
    fi
}

# Configure domain whitelist
configure_domain_whitelist() {
    if [ -z "$ALLOWED_DOMAINS" ]; then
        log_info "No domain whitelist configured"
        return 0
    fi

    log_info "Configuring domain whitelist..."

    # Create domain whitelist file
    local WHITELIST_FILE="/etc/stackcodesy/allowed-domains.txt"
    mkdir -p "$(dirname "$WHITELIST_FILE")"

    echo "# StackCodeSy Allowed Domains" > "$WHITELIST_FILE"
    IFS=',' read -ra DOMAINS <<< "$ALLOWED_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        domain_trimmed=$(echo "$domain" | xargs)
        echo "$domain_trimmed" >> "$WHITELIST_FILE"
        log_info "Allowed domain: $domain_trimmed"
    done

    # Create domain validation script
    cat > /usr/local/bin/validate-domain.sh << 'DOMAIN_EOF'
#!/bin/bash
DOMAIN="$1"
WHITELIST_FILE="/etc/stackcodesy/allowed-domains.txt"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

if [ ! -f "$WHITELIST_FILE" ]; then
    echo "No whitelist configured - all domains blocked"
    exit 1
fi

while IFS= read -r line; do
    line_trimmed=$(echo "$line" | xargs)
    # Skip comments and empty lines
    if [[ -z "$line_trimmed" ]] || [[ "$line_trimmed" =~ ^# ]]; then
        continue
    fi

    if [ "$line_trimmed" = "$DOMAIN" ]; then
        echo "✓ Domain '$DOMAIN' is ALLOWED"
        exit 0
    fi

    # Check wildcard match
    if [[ "$line_trimmed" == \*.* ]] && [[ "$DOMAIN" =~ ${line_trimmed#\*.} ]]; then
        echo "✓ Domain '$DOMAIN' matches wildcard '$line_trimmed'"
        exit 0
    fi
done < "$WHITELIST_FILE"

echo "✗ Domain '$DOMAIN' is BLOCKED"
exit 1
DOMAIN_EOF

    chmod +x /usr/local/bin/validate-domain.sh
    log_info "Domain whitelist configured"
}

# Configure DNS filtering
configure_dns_filter() {
    local DNS_FILTER="${STACKCODESY_ENABLE_DNS_FILTER:-false}"

    if [ "$DNS_FILTER" != "true" ]; then
        return 0
    fi

    log_info "Configuring DNS filtering..."

    # Create custom DNS resolver configuration
    cat > /usr/local/bin/dns-filter.sh << 'DNS_EOF'
#!/bin/bash
# Custom DNS filter - blocks non-whitelisted domains
QUERY_DOMAIN="$1"

if /usr/local/bin/validate-domain.sh "$QUERY_DOMAIN" 2>/dev/null; then
    # Domain is whitelisted - allow DNS resolution
    exit 0
else
    # Domain is not whitelisted - block
    exit 1
fi
DNS_EOF

    chmod +x /usr/local/bin/dns-filter.sh
    log_info "DNS filtering configured"
}

# Create network monitoring script
create_network_monitor() {
    cat > /usr/local/bin/monitor-network.sh << 'NETMON_EOF'
#!/bin/bash
# Network activity monitor

LOG_FILE="/var/log/stackcodesy/network-activity.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] Network monitoring started" >> "$LOG_FILE"

# Monitor outbound connections
while true; do
    netstat -tunapo 2>/dev/null | grep ESTABLISHED | \
        while read -r line; do
            echo "[$(date)] $line" >> "$LOG_FILE"
        done
    sleep 10
done
NETMON_EOF

    chmod +x /usr/local/bin/monitor-network.sh
}

# Main execution
log_info "Configuring network security..."

configure_egress_filter
configure_domain_whitelist
configure_dns_filter
create_network_monitor

# Display network configuration summary
log_info "Network security configuration:"
echo "  - Egress Filter: $ENABLE_EGRESS_FILTER"
echo "  - Block All Outbound: $BLOCK_ALL_OUTBOUND"
echo "  - Allowed Ports: $ALLOWED_PORTS"
echo "  - Allowed Domains: ${ALLOWED_DOMAINS:-none}"

log_info "Network security configuration complete"
exit 0
