#!/bin/bash
# StackCodeSy Comprehensive Audit Logging Configuration
# Logs all security events, terminal commands, file access, and authentication

set -e

ENABLE_AUDIT_LOG="${STACKCODESY_ENABLE_AUDIT_LOG:-true}"
AUDIT_LOG_DIR="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}"
AUDIT_LOG_RETENTION_DAYS="${STACKCODESY_AUDIT_LOG_RETENTION_DAYS:-30}"
LOG_TERMINAL_COMMANDS="${STACKCODESY_LOG_TERMINAL_COMMANDS:-true}"
LOG_FILE_ACCESS="${STACKCODESY_LOG_FILE_ACCESS:-false}"
LOG_AUTH_EVENTS="${STACKCODESY_LOG_AUTH_EVENTS:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[StackCodeSy Audit]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[StackCodeSy Audit]${NC} $1"
}

# Create audit log directory structure
setup_audit_directories() {
    mkdir -p "$AUDIT_LOG_DIR"/{terminal,file-access,auth,security,system}
    chown -R stackcodesy:stackcodesy "$AUDIT_LOG_DIR" 2>/dev/null || true
    chmod 755 "$AUDIT_LOG_DIR"

    log_info "Audit log directory created: $AUDIT_LOG_DIR"
}

# Create central audit logging function
create_audit_logger() {
    cat > /usr/local/bin/audit-log.sh << 'AUDIT_EOF'
#!/bin/bash
# Central audit logging utility

AUDIT_LOG_DIR="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}"
CATEGORY="$1"  # terminal, file-access, auth, security, system
MESSAGE="$2"
SEVERITY="${3:-INFO}"  # INFO, WARNING, ERROR, CRITICAL

if [ -z "$CATEGORY" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <category> <message> [severity]"
    exit 1
fi

LOG_FILE="$AUDIT_LOG_DIR/$CATEGORY/events.log"
mkdir -p "$(dirname "$LOG_FILE")"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
USER="${USER:-unknown}"
PID="$$"
HOSTNAME=$(hostname)

# JSON format for easy parsing
LOG_ENTRY=$(cat <<JSON_EOF
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "category": "$CATEGORY",
  "severity": "$SEVERITY",
  "user": "$USER",
  "pid": $PID,
  "message": "$MESSAGE",
  "pwd": "$(pwd 2>/dev/null || echo 'unknown')"
}
JSON_EOF
)

echo "$LOG_ENTRY" >> "$LOG_FILE"

# Also log to syslog if available
if command -v logger &> /dev/null; then
    logger -t "stackcodesy-audit" -p "user.$SEVERITY" "$CATEGORY: $MESSAGE"
fi

exit 0
AUDIT_EOF

    chmod +x /usr/local/bin/audit-log.sh
    log_info "Central audit logger created"
}

# Configure terminal command logging
configure_terminal_logging() {
    if [ "$LOG_TERMINAL_COMMANDS" != "true" ]; then
        log_info "Terminal command logging disabled"
        return 0
    fi

    log_info "Terminal command logging ENABLED"

    # This is integrated into restricted-shell.sh
    # Create separate terminal logger
    cat > /usr/local/bin/log-terminal-command.sh << 'TERM_LOG_EOF'
#!/bin/bash
COMMAND="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}/terminal/commands.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "[$TIMESTAMP] [USER:$USER] [PID:$$] [PWD:$(pwd)] COMMAND: $COMMAND" >> "$LOG_FILE"

# Log via central audit
/usr/local/bin/audit-log.sh "terminal" "Command executed: $COMMAND" "INFO" 2>/dev/null || true

exit 0
TERM_LOG_EOF

    chmod +x /usr/local/bin/log-terminal-command.sh
}

# Configure file access logging
configure_file_access_logging() {
    if [ "$LOG_FILE_ACCESS" != "true" ]; then
        log_info "File access logging disabled"
        return 0
    fi

    log_info "File access logging ENABLED"

    cat > /usr/local/bin/log-file-access.sh << 'FILE_LOG_EOF'
#!/bin/bash
OPERATION="$1"  # read, write, delete, create
FILE_PATH="$2"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}/file-access/operations.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "[$TIMESTAMP] [$OPERATION] [USER:$USER] FILE: $FILE_PATH" >> "$LOG_FILE"

# Log via central audit
/usr/local/bin/audit-log.sh "file-access" "$OPERATION: $FILE_PATH" "INFO" 2>/dev/null || true

exit 0
FILE_LOG_EOF

    chmod +x /usr/local/bin/log-file-access.sh
}

# Configure authentication event logging
configure_auth_logging() {
    if [ "$LOG_AUTH_EVENTS" != "true" ]; then
        log_info "Authentication logging disabled"
        return 0
    fi

    log_info "Authentication event logging ENABLED"

    cat > /usr/local/bin/log-auth-event.sh << 'AUTH_LOG_EOF'
#!/bin/bash
EVENT_TYPE="$1"  # login, logout, auth_failure, token_refresh
USER_ID="$2"
USER_EMAIL="${3:-unknown}"
RESULT="${4:-success}"  # success, failure
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}/auth/events.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "[$TIMESTAMP] [$EVENT_TYPE] [RESULT:$RESULT] USER_ID:$USER_ID EMAIL:$USER_EMAIL" >> "$LOG_FILE"

# Log via central audit
SEVERITY="INFO"
if [ "$RESULT" = "failure" ]; then
    SEVERITY="WARNING"
fi

/usr/local/bin/audit-log.sh "auth" "$EVENT_TYPE for user $USER_ID ($USER_EMAIL): $RESULT" "$SEVERITY" 2>/dev/null || true

exit 0
AUTH_LOG_EOF

    chmod +x /usr/local/bin/log-auth-event.sh
}

# Create security event logger
create_security_logger() {
    cat > /usr/local/bin/log-security-event.sh << 'SEC_LOG_EOF'
#!/bin/bash
EVENT="$1"
SEVERITY="${2:-WARNING}"  # INFO, WARNING, ERROR, CRITICAL
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}/security/events.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "[$TIMESTAMP] [$SEVERITY] $EVENT" >> "$LOG_FILE"

# Log via central audit
/usr/local/bin/audit-log.sh "security" "$EVENT" "$SEVERITY" 2>/dev/null || true

# Send alert for CRITICAL events
if [ "$SEVERITY" = "CRITICAL" ]; then
    echo "[CRITICAL SECURITY ALERT] $EVENT" >&2
fi

exit 0
SEC_LOG_EOF

    chmod +x /usr/local/bin/log-security-event.sh
    log_info "Security event logger created"
}

# Configure log rotation
configure_log_rotation() {
    log_info "Configuring log rotation (${AUDIT_LOG_RETENTION_DAYS} days retention)"

    # Create log rotation script
    cat > /usr/local/bin/rotate-audit-logs.sh << 'ROTATE_EOF'
#!/bin/bash
AUDIT_LOG_DIR="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}"
RETENTION_DAYS="${STACKCODESY_AUDIT_LOG_RETENTION_DAYS:-30}"

# Find and delete old logs
find "$AUDIT_LOG_DIR" -type f -name "*.log" -mtime "+$RETENTION_DAYS" -delete

# Compress logs older than 7 days
find "$AUDIT_LOG_DIR" -type f -name "*.log" -mtime +7 ! -name "*.gz" -exec gzip {} \;

echo "[$(date)] Log rotation completed - retention: $RETENTION_DAYS days"
exit 0
ROTATE_EOF

    chmod +x /usr/local/bin/rotate-audit-logs.sh

    # Create daily cron job (if cron is available)
    if command -v crontab &> /dev/null; then
        echo "0 2 * * * /usr/local/bin/rotate-audit-logs.sh" | crontab - 2>/dev/null || true
        log_info "Log rotation cron job created (daily at 2 AM)"
    fi
}

# Create audit summary script
create_audit_summary() {
    cat > /usr/local/bin/audit-summary.sh << 'SUMMARY_EOF'
#!/bin/bash
AUDIT_LOG_DIR="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}"

echo "========================================="
echo "StackCodeSy Audit Log Summary"
echo "Generated: $(date)"
echo "========================================="
echo ""

for category in terminal file-access auth security system; do
    LOG_FILE="$AUDIT_LOG_DIR/$category/events.log"
    if [ -f "$LOG_FILE" ]; then
        COUNT=$(wc -l < "$LOG_FILE")
        echo "[$category] Total events: $COUNT"

        # Show last 5 entries
        echo "  Last 5 events:"
        tail -5 "$LOG_FILE" | sed 's/^/    /'
        echo ""
    fi
done

echo "========================================="
exit 0
SUMMARY_EOF

    chmod +x /usr/local/bin/audit-summary.sh
    log_info "Audit summary script created: /usr/local/bin/audit-summary.sh"
}

# Create real-time audit monitor
create_audit_monitor() {
    cat > /usr/local/bin/monitor-audit.sh << 'MONITOR_EOF'
#!/bin/bash
AUDIT_LOG_DIR="${STACKCODESY_AUDIT_LOG_DIR:-/var/log/stackcodesy}"

echo "Real-time audit log monitor (Ctrl+C to exit)"
echo "Monitoring: $AUDIT_LOG_DIR"
echo "========================================="

# Monitor all log files
tail -F "$AUDIT_LOG_DIR"/**/events.log 2>/dev/null | \
    while read -r line; do
        # Highlight security events
        if echo "$line" | grep -qi "critical\|error\|failure"; then
            echo -e "\033[0;31m$line\033[0m"  # Red
        elif echo "$line" | grep -qi "warning"; then
            echo -e "\033[1;33m$line\033[0m"  # Yellow
        else
            echo "$line"
        fi
    done
MONITOR_EOF

    chmod +x /usr/local/bin/monitor-audit.sh
    log_info "Real-time audit monitor created: /usr/local/bin/monitor-audit.sh"
}

# Main execution
if [ "$ENABLE_AUDIT_LOG" != "true" ]; then
    log_warning "Audit logging is DISABLED"
    exit 0
fi

log_info "Configuring comprehensive audit logging..."

setup_audit_directories
create_audit_logger
configure_terminal_logging
configure_file_access_logging
configure_auth_logging
create_security_logger
configure_log_rotation
create_audit_summary
create_audit_monitor

log_info "Audit logging configuration complete"
echo ""
echo "Audit Log Locations:"
echo "  - Terminal commands: $AUDIT_LOG_DIR/terminal/commands.log"
echo "  - File access: $AUDIT_LOG_DIR/file-access/operations.log"
echo "  - Authentication: $AUDIT_LOG_DIR/auth/events.log"
echo "  - Security events: $AUDIT_LOG_DIR/security/events.log"
echo "  - All events: $AUDIT_LOG_DIR/*/events.log"
echo ""
echo "Useful commands:"
echo "  - View summary: /usr/local/bin/audit-summary.sh"
echo "  - Monitor real-time: /usr/local/bin/monitor-audit.sh"
echo "  - Rotate logs: /usr/local/bin/rotate-audit-logs.sh"
echo ""

exit 0
