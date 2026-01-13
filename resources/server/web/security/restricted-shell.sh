#!/bin/bash
#---------------------------------------------------------------------------------------------
#  Copyright (c) StackCodeSy. All rights reserved.
#  Licensed under the MIT License.
#---------------------------------------------------------------------------------------------

# StackCodeSy Restricted Shell Wrapper
# This script provides a restricted shell environment with configurable permissions

# Get configuration from environment
WORKSPACE_ONLY="${STACKCODESY_TERMINAL_WORKSPACE_ONLY:-true}"
ALLOWED_COMMANDS="${STACKCODESY_TERMINAL_ALLOWED_COMMANDS:-npm,yarn,node,git,python,python3,pip,pip3,make,gcc,g++,rustc,cargo,go,java,javac,mvn,gradle}"
BLOCKED_COMMANDS="${STACKCODESY_TERMINAL_BLOCKED_COMMANDS:-rm -rf,dd,mkfs,fdisk,parted,reboot,shutdown,init,systemctl,service,chmod,chown,sudo,su,passwd,useradd,usermod,userdel,wget,curl,nc,netcat,telnet,ssh,scp,sftp}"
BLOCK_NETWORK="${STACKCODESY_TERMINAL_BLOCK_NETWORK:-false}"
MAX_COMMAND_LENGTH="${STACKCODESY_TERMINAL_MAX_COMMAND_LENGTH:-1000}"

# Workspace directory (default to /workspace or /projects)
WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Log file for security events
SECURITY_LOG="/tmp/stackcodesy-terminal-security.log"

log_security_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SECURITY_LOG"
}

print_error() {
    echo -e "${RED}[StackCodeSy Security]${NC} $1" >&2
    log_security_event "BLOCKED: $1"
}

print_warning() {
    echo -e "${YELLOW}[StackCodeSy Warning]${NC} $1" >&2
}

print_info() {
    echo -e "${GREEN}[StackCodeSy]${NC} $1"
}

# Check if command contains blocked patterns
is_command_blocked() {
    local cmd="$1"

    # Check command length
    if [ ${#cmd} -gt "$MAX_COMMAND_LENGTH" ]; then
        print_error "Command too long (max: $MAX_COMMAND_LENGTH characters)"
        return 0
    fi

    # Check for dangerous patterns
    IFS=',' read -ra BLOCKED <<< "$BLOCKED_COMMANDS"
    for blocked in "${BLOCKED[@]}"; do
        if echo "$cmd" | grep -q "$blocked"; then
            print_error "Blocked command: $blocked"
            return 0
        fi
    done

    # Check for path traversal attempts
    if echo "$cmd" | grep -qE '\.\.|^/|~/'; then
        if [ "$WORKSPACE_ONLY" = "true" ]; then
            print_error "Path traversal not allowed (WORKSPACE_ONLY mode)"
            return 0
        fi
    fi

    # Check for shell redirects to sensitive files
    if echo "$cmd" | grep -qE '>/etc|>/root|>/usr|>/bin|>/sbin|>/var'; then
        print_error "Cannot redirect output to system directories"
        return 0
    fi

    # Check for piping to dangerous commands
    if echo "$cmd" | grep -qE '\|.*bash|\|.*sh|\|.*eval'; then
        print_error "Piping to shell interpreters is blocked"
        return 0
    fi

    # Check for command substitution with dangerous commands
    if echo "$cmd" | grep -qE '\$\(.*rm|\$\(.*dd|\`.*rm|\`.*dd'; then
        print_error "Dangerous command substitution detected"
        return 0
    fi

    return 1
}

# Check if command is in allowed list
is_command_allowed() {
    local cmd="$1"
    local base_cmd=$(echo "$cmd" | awk '{print $1}')

    # If allowed commands is "*", allow everything (except blocked)
    if [ "$ALLOWED_COMMANDS" = "*" ]; then
        return 0
    fi

    # Check if base command is in allowed list
    IFS=',' read -ra ALLOWED <<< "$ALLOWED_COMMANDS"
    for allowed in "${ALLOWED[@]}"; do
        if [ "$base_cmd" = "$allowed" ]; then
            return 0
        fi
    done

    print_error "Command not in allowed list: $base_cmd"
    print_info "Allowed commands: $ALLOWED_COMMANDS"
    return 1
}

# Validate and execute command
execute_command() {
    local cmd="$*"

    # Skip empty commands
    if [ -z "$cmd" ]; then
        return 0
    fi

    # Check if command is blocked
    if is_command_blocked "$cmd"; then
        return 1
    fi

    # Check if command is allowed
    if ! is_command_allowed "$cmd"; then
        return 1
    fi

    # If workspace-only mode, change to workspace and restrict cd
    if [ "$WORKSPACE_ONLY" = "true" ]; then
        # Validate we're in workspace
        current_dir=$(pwd)
        if [[ ! "$current_dir" =~ ^"$WORKSPACE_DIR" ]]; then
            cd "$WORKSPACE_DIR" 2>/dev/null || {
                print_error "Cannot access workspace directory: $WORKSPACE_DIR"
                return 1
            }
        fi

        # If command is cd, validate target is within workspace
        if echo "$cmd" | grep -q "^cd "; then
            local target=$(echo "$cmd" | sed 's/^cd //')
            target=$(eval echo "$target") # Expand variables

            # Get absolute path
            if [[ "$target" = /* ]]; then
                abs_path="$target"
            else
                abs_path="$(pwd)/$target"
            fi

            # Normalize path
            abs_path=$(readlink -f "$abs_path" 2>/dev/null || echo "$abs_path")

            # Check if within workspace
            if [[ ! "$abs_path" =~ ^"$WORKSPACE_DIR" ]]; then
                print_error "Cannot cd outside workspace: $abs_path"
                print_info "Workspace restricted to: $WORKSPACE_DIR"
                return 1
            fi
        fi
    fi

    # Log command execution
    log_security_event "ALLOWED: $cmd (from $(pwd))"

    # Execute the command
    eval "$cmd"
    return $?
}

# Main shell loop
main() {
    print_info "StackCodeSy Restricted Terminal"
    print_info "Mode: WORKSPACE_ONLY=$WORKSPACE_ONLY, BLOCK_NETWORK=$BLOCK_NETWORK"

    if [ "$WORKSPACE_ONLY" = "true" ]; then
        print_warning "You are restricted to workspace directory: $WORKSPACE_DIR"
        cd "$WORKSPACE_DIR" 2>/dev/null || print_error "Workspace directory not found"
    fi

    if [ "$ALLOWED_COMMANDS" != "*" ]; then
        print_warning "Only allowed commands: $ALLOWED_COMMANDS"
    fi

    # If called with -c (command mode), execute single command
    if [ "$1" = "-c" ]; then
        shift
        execute_command "$@"
        exit $?
    fi

    # Interactive mode
    while true; do
        # Show prompt
        if [ "$WORKSPACE_ONLY" = "true" ]; then
            # Show relative path from workspace
            rel_path="${PWD#$WORKSPACE_DIR}"
            rel_path="${rel_path:-/}"
            echo -n "stackcodesy:$rel_path\$ "
        else
            echo -n "stackcodesy:\w\$ "
        fi

        # Read command
        read -r cmd

        # Exit on Ctrl+D or exit command
        if [ $? -ne 0 ] || [ "$cmd" = "exit" ] || [ "$cmd" = "logout" ]; then
            print_info "Goodbye!"
            break
        fi

        # Execute command
        execute_command "$cmd"
    done
}

# Run main function
main "$@"
