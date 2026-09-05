# GB-LAMP

[English](README.md) | [Українська](README.ua.md)

A lightweight, fast LAMP stack (Linux, Apache, MariaDB, PHP) using Docker Compose. Designed for rapid local development with selectable PHP versions directly in the project root directory (optimized for OpenCart, custom websites, and other CMS platforms).

## Features

- **One-Command Setup**: Attach the Docker environment to any existing project via `curl | bash`
- **Multiple PHP Versions**: Seamless support for PHP 7.4, 8.0, and 8.2
- **Root-Level Serving**: Web root is mapped directly to the repository root directory
- **Automated Configuration**: Automatic template provisioning, config copying, and `.env` creation
- **Database Management**: Automated SQL dump importing with table cleanup
- **Container Lifecycle**: Simple commands to start, stop, clean up, and fix permissions
- **Flexible Environment**: Centralized configuration through `.env`
- **Reboot-Safe**: Containers do not autostart on system reboot (`restart: "no"`)

## Requirements

- Docker and Docker Compose
- Make (for running Makefile targets)
- Bash shell

## Installation & Quick Start

### 1. Attach to Any Existing Project (Recommended)

Navigate to your existing website/OpenCart project folder and run:

```bash
curl -sSL https://raw.githubusercontent.com/GregoryBiter/gb-lamp/main/lamp.sh | bash
```

The script will automatically:
- Download the required GB-LAMP components (`.docker/`, `Makefile`, `.env.example`, `.vscode/`)
- Update your project's `.gitignore` with environment and CMS cache/log rules
- Launch the interactive initialization wizard (`init.sh`) to select the PHP version and configure `.env`

---

### 2. Local Setup in Cloned gb-lamp Repository

If working directly within this repository:

1. **Quick Start**:
   ```bash
   make start
   ```
   *If `docker-compose.yml` or `.env` are missing, the command automatically triggers the initialization wizard.*

2. **Manual Initialization**:
   ```bash
   make init
   ```
   Select your desired PHP version (1 - PHP 7.4, 2 - PHP 8.0, 3 - PHP 8.2). This generates `docker-compose.yml`, prompts to create `.env`, and offers to import a database dump.

3. **Database Import**:
   ```bash
   make db-import
   ```
   Automatically locates a `.sql` file in the project root and imports it into MariaDB after cleaning existing tables.

---

## Configuration

### The .env File

After initialization, customize `.env` for your project needs:

```bash
VHOST_SERVER_NAME=myproject.local
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=myproject
MYSQL_USER=dev_user
MYSQL_PASSWORD=dev_password
```

### Adding Domain to Hosts

If `VHOST_SERVER_NAME` is anything other than `localhost`, add a mapping in `/etc/hosts`:

```bash
127.0.0.1 myproject.local
```

The `make start` command verifies this entry and offers to add it automatically.

---

## Service Access

Once containers are running:

- **Web Server**: [http://localhost](http://localhost) (or your configured `VHOST_SERVER_NAME`)
- **phpMyAdmin**: [http://localhost:8080](http://localhost:8080)
- **MariaDB / MySQL**: `localhost:3306`

---

## Makefile Commands

- `make help`: Display help and available commands
- `make init`: Initialize the environment, select PHP version, and configure `.env`
- `make start`: Validate configuration, register host domain, and launch Docker Compose
- `make db-import`: Import SQL dump from root into MariaDB with table cleanup
- `make clean`: Stop containers, remove volumes, and prune dangling images
- `make fix-permissions`: Set recursive project permissions for the current user

---

## Project Structure

```bash
.
├── .docker/
│   ├── configs/          # Service configurations (Apache, MySQL, PHP)
│   ├── example-config/   # CMS configuration templates (OpenCart)
│   ├── scripts/          # Initialization and management scripts
│   └── templates/        # docker-compose.yml templates for PHP versions
├── docker-compose.yml    # Active Docker Compose file (created during init)
├── .env                  # Environment variables (created from .env.example)
├── .env.example          # Example environment variable template
├── Makefile              # Project management commands
└── lamp.sh               # One-line installer script for any project
# Website / OpenCart files reside directly in the project root directory
```

---

## Troubleshooting

- **Missing Configuration Files**: Run `make init` or `make start`.
- **Permission Denied Errors**: Run `make fix-permissions`.
- **Containers Fail to Start**: Check logs with `docker compose logs` and verify that ports `80`, `3306`, or `8080` are not in use by other processes.
- **Database Connection Issues**: Verify database credentials in `.env`.
