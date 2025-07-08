#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Default values
readonly DEFAULT_LOCAL_PORT=22
readonly DEFAULT_TARGET_HOST="springboard"
readonly SERVICE_PREFIX="remote_forwarding"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Display usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} -p <remote_port> [OPTIONS]

Automatically creates a systemd service for persistent SSH remote port forwarding.

Required:
  -p <remote_port>   Remote port number for forwarding (e.g., 9898)

Options:
  -t <target_host>   Target SSH host (default: ${DEFAULT_TARGET_HOST})
  -l <local_port>    Local port to forward (default: ${DEFAULT_LOCAL_PORT})
  -s <service_name>  Custom systemd service name
                     (default: ${SERVICE_PREFIX}_<host>_<local>_to_<remote>)
  -h                 Display this help message and exit

Examples:
  ${SCRIPT_NAME} -p 9898
  ${SCRIPT_NAME} -p 9898 -l 8080 -t myserver.example.com
  ${SCRIPT_NAME} -p 9898 -s my_custom_tunnel

EOF
    exit 1
}

# Validate port number
validate_port() {
    local port=$1
    local port_type=$2
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "${port_type} port must be a number: $port"
        exit 1
    fi
    
    if ((port < 1 || port > 65535)); then
        log_error "${port_type} port must be between 1 and 65535: $port"
        exit 1
    fi
}

# Validate hostname
validate_hostname() {
    local host=$1
    
    if [[ -z "$host" ]]; then
        log_error "Target host cannot be empty"
        exit 1
    fi
}

# Check if service already exists
check_service_exists() {
    local service_name=$1
    
    if systemctl list-unit-files | grep -q "^${service_name}.service"; then
        log_warning "Service ${service_name} already exists"
        read -p "Do you want to recreate it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
}

# Install autossh if not present
install_autossh() {
    if ! command -v autossh &> /dev/null; then
        log_info "Installing autossh..."
        if ! sudo apt-get update && sudo apt-get install -y autossh; then
            log_error "Failed to install autossh"
            exit 1
        fi
        log_info "autossh installed successfully"
    fi
}

# Initialize variables
LOCAL_PORT=$DEFAULT_LOCAL_PORT
TARGET_HOST=$DEFAULT_TARGET_HOST
REMOTE_PORT=""
CUSTOM_SERVICE_NAME=""

# Parse command line arguments
while getopts ":p:t:l:s:h" opt; do
    case ${opt} in
        p)
            REMOTE_PORT="$OPTARG"
            ;;
        t)
            TARGET_HOST="$OPTARG"
            ;;
        l)
            LOCAL_PORT="$OPTARG"
            ;;
        s)
            CUSTOM_SERVICE_NAME="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            log_error "Invalid option: -$OPTARG"
            usage
            ;;
        :)
            log_error "Option -$OPTARG requires an argument"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "${REMOTE_PORT}" ]]; then
    log_error "Remote port (-p) is required"
    usage
fi

# Validate inputs
validate_port "$LOCAL_PORT" "Local"
validate_port "$REMOTE_PORT" "Remote"
validate_hostname "$TARGET_HOST"

# Determine service name
if [[ -z "${CUSTOM_SERVICE_NAME}" ]]; then
    # Replace dots and special characters in hostname for valid service name
    SAFE_TARGET_HOST=$(echo "$TARGET_HOST" | sed 's/[^a-zA-Z0-9_-]/_/g')
    SERVICE_NAME="${SERVICE_PREFIX}_${SAFE_TARGET_HOST}_${LOCAL_PORT}_to_${REMOTE_PORT}"
else
    SERVICE_NAME="$CUSTOM_SERVICE_NAME"
fi

# Validate service name
if ! [[ "$SERVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Service name must contain only alphanumeric characters, underscores, and hyphens"
    exit 1
fi

# Check for existing service
check_service_exists "$SERVICE_NAME"

# Install dependencies
install_autossh

# Test SSH connection
log_info "Testing SSH connection to ${TARGET_HOST}..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_HOST" exit 2>/dev/null; then
    log_error "Cannot connect to ${TARGET_HOST}. Please ensure:"
    log_error "  1. SSH key authentication is configured"
    log_error "  2. The host is reachable"
    log_error "  3. The hostname is correct"
    exit 1
fi
log_info "SSH connection test successful"

# Create systemd service file
log_info "Creating systemd service: ${SERVICE_NAME}"

readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly CURRENT_USER="$(whoami)"
readonly CURRENT_GROUP="$(id -gn)"

# Generate service file content
cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=SSH Remote Port Forwarding - ${TARGET_HOST}:${REMOTE_PORT} <- localhost:${LOCAL_PORT}
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=${CURRENT_USER}
Group=${CURRENT_GROUP}
Restart=always
RestartSec=10
StartLimitBurst=0

# Environment
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_PORT=0"

# Main process
ExecStartPre=/bin/sleep 1
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" -NR ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${TARGET_HOST}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f "$SERVICE_FILE" ]]; then
    log_error "Failed to create service file"
    exit 1
fi

# Reload systemd and enable service
log_info "Enabling and starting service..."

if ! sudo systemctl daemon-reload; then
    log_error "Failed to reload systemd"
    exit 1
fi

if ! sudo systemctl enable "$SERVICE_NAME"; then
    log_error "Failed to enable service"
    exit 1
fi

if ! sudo systemctl restart "$SERVICE_NAME"; then
    log_error "Failed to start service"
    exit 1
fi

# Wait a moment for service to stabilize
sleep 2

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_info "Service created and started successfully!"
    echo
    echo "Service Details:"
    echo "  Name:        ${SERVICE_NAME}"
    echo "  Target:      ${TARGET_HOST}"
    echo "  Remote Port: ${REMOTE_PORT} (on ${TARGET_HOST})"
    echo "  Local Port:  ${LOCAL_PORT} (on localhost)"
    echo
    echo "Useful commands:"
    echo "  Check status:  sudo systemctl status ${SERVICE_NAME}"
    echo "  View logs:     sudo journalctl -u ${SERVICE_NAME} -f"
    echo "  Stop service:  sudo systemctl stop ${SERVICE_NAME}"
    echo "  Disable:       sudo systemctl disable ${SERVICE_NAME}"
else
    log_error "Service failed to start. Check logs with:"
    log_error "  sudo journalctl -u ${SERVICE_NAME} -xe"
    exit 1
fi

