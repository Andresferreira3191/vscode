#!/bin/bash
# StackCodeSy File System Security Configuration
# Implements disk quotas, file type restrictions, and monitoring

set -e

WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"
DISK_QUOTA_MB="${STACKCODESY_DISK_QUOTA_MB:-5000}"
MAX_FILE_SIZE_MB="${STACKCODESY_MAX_FILE_SIZE_MB:-100}"
BLOCKED_FILE_TYPES="${STACKCODESY_BLOCKED_FILE_TYPES:-.exe,.dll,.so.malicious,.sh.malicious}"
ENABLE_FILE_MONITORING="${STACKCODESY_ENABLE_FILE_MONITORING:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[StackCodeSy FS Security]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[StackCodeSy FS Security]${NC} $1"
}

log_error() {
    echo -e "${RED}[StackCodeSy FS Security]${NC} $1"
}

# Ensure workspace directory exists
mkdir -p "$WORKSPACE_DIR"
chown -R stackcodesy:stackcodesy "$WORKSPACE_DIR" 2>/dev/null || true

# Configure disk quota using prlimit (cgroup-based quota)
configure_disk_quota() {
    if [ "$DISK_QUOTA_MB" -gt 0 ]; then
        log_info "Disk quota configured: ${DISK_QUOTA_MB}MB for workspace"

        # Create quota check script
        cat > /usr/local/bin/check-disk-quota.sh << 'QUOTA_EOF'
#!/bin/bash
WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"
QUOTA_MB="${STACKCODESY_DISK_QUOTA_MB:-5000}"
QUOTA_BYTES=$((QUOTA_MB * 1024 * 1024))

# Get current usage
CURRENT_USAGE=$(du -sb "$WORKSPACE_DIR" 2>/dev/null | awk '{print $1}')

if [ "$CURRENT_USAGE" -gt "$QUOTA_BYTES" ]; then
    echo "ERROR: Disk quota exceeded! Current: $((CURRENT_USAGE / 1024 / 1024))MB, Quota: ${QUOTA_MB}MB"
    exit 1
fi

echo "Disk usage: $((CURRENT_USAGE / 1024 / 1024))MB / ${QUOTA_MB}MB"
exit 0
QUOTA_EOF

        chmod +x /usr/local/bin/check-disk-quota.sh
        log_info "Disk quota check script created at /usr/local/bin/check-disk-quota.sh"
    else
        log_warning "Disk quota disabled (STACKCODESY_DISK_QUOTA_MB=0)"
    fi
}

# Configure file size limits
configure_file_size_limits() {
    if [ "$MAX_FILE_SIZE_MB" -gt 0 ]; then
        log_info "Maximum file size: ${MAX_FILE_SIZE_MB}MB"

        # Create file size validator
        cat > /usr/local/bin/validate-file-size.sh << 'FILESIZE_EOF'
#!/bin/bash
FILE_PATH="$1"
MAX_SIZE_MB="${STACKCODESY_MAX_FILE_SIZE_MB:-100}"
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))

if [ ! -f "$FILE_PATH" ]; then
    echo "File not found: $FILE_PATH"
    exit 1
fi

FILE_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null)

if [ "$FILE_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "ERROR: File too large! Size: $((FILE_SIZE / 1024 / 1024))MB, Max: ${MAX_SIZE_MB}MB"
    exit 1
fi

exit 0
FILESIZE_EOF

        chmod +x /usr/local/bin/validate-file-size.sh
    fi
}

# Configure blocked file types
configure_blocked_file_types() {
    if [ -n "$BLOCKED_FILE_TYPES" ]; then
        log_info "Blocked file types: $BLOCKED_FILE_TYPES"

        # Create file type validator
        cat > /usr/local/bin/validate-file-type.sh << 'FILETYPE_EOF'
#!/bin/bash
FILE_PATH="$1"
BLOCKED_TYPES="${STACKCODESY_BLOCKED_FILE_TYPES:-.exe,.dll,.so.malicious}"

if [ ! -e "$FILE_PATH" ]; then
    exit 0  # File doesn't exist yet, allow
fi

FILE_EXT="${FILE_PATH##*.}"
FILE_EXT_WITH_DOT=".${FILE_EXT}"

IFS=',' read -ra BLOCKED <<< "$BLOCKED_TYPES"
for blocked in "${BLOCKED[@]}"; do
    blocked_trimmed=$(echo "$blocked" | xargs)
    if [ "$FILE_EXT_WITH_DOT" = "$blocked_trimmed" ]; then
        echo "ERROR: File type blocked: $blocked_trimmed"
        exit 1
    fi
done

exit 0
FILETYPE_EOF

        chmod +x /usr/local/bin/validate-file-type.sh
    fi
}

# Configure filesystem monitoring with inotify
configure_file_monitoring() {
    if [ "$ENABLE_FILE_MONITORING" = "true" ]; then
        log_info "File system monitoring ENABLED"

        # Install inotify-tools if available
        if command -v inotifywait &> /dev/null; then
            log_info "inotify-tools detected - filesystem monitoring available"

            # Create monitoring script
            cat > /usr/local/bin/monitor-filesystem.sh << 'MONITOR_EOF'
#!/bin/bash
WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"
LOG_FILE="/var/log/stackcodesy/filesystem-events.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] Starting filesystem monitoring on $WORKSPACE_DIR" >> "$LOG_FILE"

inotifywait -m -r -e create,delete,modify,move "$WORKSPACE_DIR" \
    --format '%T %e %w%f' --timefmt '%Y-%m-%d %H:%M:%S' 2>/dev/null | \
    while read -r event; do
        echo "$event" >> "$LOG_FILE"

        # Check for suspicious patterns
        if echo "$event" | grep -qE '\.(exe|dll|ps1|bat|cmd)$'; then
            echo "[ALERT] Suspicious file detected: $event" >> "$LOG_FILE"
        fi
    done &

            log_info "Filesystem monitoring started in background"
MONITOR_EOF

            chmod +x /usr/local/bin/monitor-filesystem.sh
            # Note: This would be started by the entrypoint in background if needed
        else
            log_warning "inotify-tools not installed - filesystem monitoring unavailable"
        fi
    else
        log_info "File system monitoring disabled"
    fi
}

# Make certain directories read-only
configure_readonly_directories() {
    local READONLY_DIRS="${STACKCODESY_READONLY_DIRS:-}"

    if [ -n "$READONLY_DIRS" ]; then
        IFS=',' read -ra DIRS <<< "$READONLY_DIRS"
        for dir in "${DIRS[@]}"; do
            dir_trimmed=$(echo "$dir" | xargs)
            if [ -d "$dir_trimmed" ]; then
                chmod -R a-w "$dir_trimmed" 2>/dev/null || true
                log_info "Directory set to read-only: $dir_trimmed"
            fi
        done
    fi
}

# Main execution
log_info "Configuring filesystem security..."

configure_disk_quota
configure_file_size_limits
configure_blocked_file_types
configure_file_monitoring
configure_readonly_directories

log_info "Filesystem security configuration complete"
exit 0
