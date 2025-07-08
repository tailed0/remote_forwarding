# Remote SSH Port Forwarding Setup Tool

A Linux utility that automates the creation of persistent SSH tunnels using systemd services, enabling remote access to local services through a springboard server.

## Overview

This tool simplifies the process of setting up remote SSH port forwarding by automatically:
- Creating systemd service files for persistent SSH tunnels
- Using autossh for automatic reconnection on network failures
- Managing service lifecycle through systemd

## Prerequisites

- Linux system with systemd
- SSH access to a springboard server
- SSH key authentication configured for the springboard server
- `autossh` (will be installed automatically if not present)

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd remote_forwarding
```

2. Make the script executable:
```bash
chmod +x enable.sh
```

## Usage

### Basic Usage

Forward local SSH (port 22) to a remote port:
```bash
./enable.sh -p 9898
```

### Advanced Usage

```bash
# Specify custom local port and target host
./enable.sh -p 9898 -l 8080 -t myserver.example.com

# Use a custom service name
./enable.sh -p 9898 -s my_custom_tunnel
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-p <remote_port>` | Remote port number for forwarding (required) | - |
| `-t <target_host>` | Target SSH host | `springboard` |
| `-l <local_port>` | Local port to forward | `22` |
| `-s <service_name>` | Custom systemd service name | `remote_forwarding_<host>_<local>_to_<remote>` |
| `-h` | Show help message | - |

## Service Management

### Check Service Status
```bash
sudo systemctl status remote_forwarding_*
```

### View Service Logs
```bash
sudo journalctl -u remote_forwarding_* -f
```

### Stop a Service
```bash
sudo systemctl stop <service_name>
```

### Disable a Service
```bash
sudo systemctl disable <service_name>
```

### List All Remote Forwarding Services
```bash
systemctl list-units --type=service | grep remote_forwarding
```

## How It Works

1. The script creates a systemd service file in `/etc/systemd/system/`
2. The service uses `autossh` to establish an SSH connection with the `-R` flag for remote port forwarding
3. `autossh` automatically monitors the connection and reconnects if it drops
4. The service runs under the current user context (not root)
5. systemd ensures the service starts automatically on boot

## Examples

### Example 1: Forward Local SSH to Remote Server

Make your local SSH server accessible on port 2222 of the springboard server:
```bash
./enable.sh -p 2222
```

Now you can SSH to your local machine from anywhere:
```bash
ssh -p 2222 user@springboard
```

### Example 2: Forward Local Web Server

Forward a local web server running on port 8080 to remote port 8888:
```bash
./enable.sh -p 8888 -l 8080
```

Access your local web server at:
```
http://springboard:8888
```

### Example 3: Multiple Services

You can create multiple forwarding services for different ports:
```bash
./enable.sh -p 2222 -l 22 -s ssh_tunnel
./enable.sh -p 8080 -l 80 -s http_tunnel
./enable.sh -p 3306 -l 3306 -s mysql_tunnel
```

## Troubleshooting

### Service Won't Start

1. Check SSH key authentication:
```bash
ssh springboard
```

2. View service logs:
```bash
sudo journalctl -u <service_name> -xe
```

### Port Already in Use

Check what's using the port on the remote server:
```bash
ssh springboard "sudo lsof -i :PORT"
```

### Service Keeps Restarting

This usually indicates SSH connection issues. Check:
- Network connectivity
- SSH server configuration
- Firewall rules

## Security Considerations

- Only forward ports for services you intend to expose
- Use SSH key authentication (password authentication is not recommended)
- Consider using firewall rules on the springboard server to limit access
- Regularly review active forwarding services

## License

This project is provided as-is without any specific license. Please add appropriate licensing information.

## Contributing

Contributions are welcome! Please submit issues and pull requests on the project repository.