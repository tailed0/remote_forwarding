# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Remote SSH Port Forwarding Setup Tool that automates the creation of persistent SSH tunnels using systemd services on Linux systems. It enables remote access to local services through a springboard server.

## Key Commands

### Running the Script
```bash
# Basic usage - forward local SSH (port 22) to remote port
./enable.sh -p <remote_port>

# Advanced usage - specify local port and service name
./enable.sh -p <remote_port> -l <local_port> -s <service_name>

# Show help
./enable.sh -h
```

### Service Management
```bash
# Check service status
sudo systemctl status remote_forwarding_*

# View service logs
sudo journalctl -u remote_forwarding_* -f

# Stop/disable a service
sudo systemctl stop <service_name>
sudo systemctl disable <service_name>
```

## Architecture

The tool consists of one main component:

**enable.sh**: Main script that handles:
   - Command-line argument parsing
   - Dynamic systemd service file generation in /etc/systemd/system/
   - Service enablement and startup

The script creates systemd services that use `autossh` to maintain persistent SSH connections with remote port forwarding (`-R` flag).

## Development Notes

- The script uses strict error handling (`set -eu` and `set -o pipefail`)
- Comments are primarily in Japanese
- Service names follow the pattern: `remote_forwarding_<local_port>_to_<remote_port>`
- Services run under the current user context, not root
- The springboard server requires SSH key authentication
