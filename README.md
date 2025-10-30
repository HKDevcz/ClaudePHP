# Claude Box with PHP runtime

A Docker container that combines PHP-FPM with Claude Code, enabling AI-assisted development for PHP projects directly within a containerized environment.

## Overview

When you run several PHP projects and want to keep Claude in a container but with PHP-FPM available for your Claude agent, this setup allows you to maintain isolated PHP environments while leveraging Claude Code's capabilities.

## Features

- PHP-FPM environment with Claude Code integrated (listens on port 9000)
- Support for multiple PHP versions
- Automatic user permission matching - files created in container belong to your host user (not root)
- Optional git exclude configuration for Claude-specific files
- Docker Compose integration support
- Isolated development environment per project

## Prerequisites

- Docker installed on your system
- Docker Compose (optional, for compose integration)

## Quick Start

The pre-built image is available from GitHub Container Registry:

```bash
docker pull ghcr.io/hkdevcz/claudephp:8.4
```

Then run Claude in your project:

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  ghcr.io/hkdevcz/claudephp:8.4 claude
```

## Build with PHP version you need

Build the container with your desired PHP and Node versions using build arguments.

### PHP 8.4 with Node 24 (default):

```bash
docker build -f Dockerfile.claude -t claudephp:8.4 .
```

### PHP 7.4 with Node 20:

```bash
docker build -f Dockerfile.claude --build-arg PHP_VERSION=7.4 --build-arg NODE_VERSION=20 -t claudephp:7.4-node20 .
```

### Other PHP versions:

You can specify any PHP version available as an official PHP FPM Alpine image:

```bash
# PHP 8.3 with Node 22
docker build -f Dockerfile.claude --build-arg PHP_VERSION=8.3 --build-arg NODE_VERSION=22 -t claudephp:8.3 .

# PHP 8.2 with default Node
docker build -f Dockerfile.claude --build-arg PHP_VERSION=8.2 -t claudephp:8.2 .
```

### Available Build Arguments:

| Argument | Description | Default |
|----------|-------------|---------|
| `PHP_VERSION` | PHP version (e.g., 7.4, 8.2, 8.3, 8.4) | `8.4` |
| `NODE_VERSION` | Node.js version (e.g., 18, 20, 22, 24) | `24` |
| `INSTALL_CLAUDE` | Whether to install Claude Code CLI | `true` |

## Usage

### File Ownership

The container automatically matches the internal user's UID/GID to your host user, ensuring all files created belong to you (not root).

**Recommended usage** (automatically detect your UID/GID):

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  ghcr.io/hkdevcz/claudephp:8.4 claude
```

If you don't pass `USER_UID` and `USER_GID`, the container defaults to `1000:1000`, which works for most single-user systems.

### Run Claude with project

Run Claude Code in your project directory.

**Important:** Do not commit `.claude.json` and `.claude/` directory - add them to `.gitignore`:
```gitignore
.claude.json
.claude/
```

**Basic usage:**
```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  ghcr.io/hkdevcz/claudephp:8.4 claude
```

The `.claude/` directory stores authentication credentials and session data, which will persist across container runs thanks to the volume mount.

### Run Claude with automatic git excludes

Use the `SETUP_GIT_EXCLUDES` environment variable to automatically exclude Claude-specific folders without modifying `.gitignore`:

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  -e SETUP_GIT_EXCLUDES=true \
  claudephp:8.4 claude
```

### Using with Docker Compose

You can either override your existing PHP service or add a new `claudephp` service.

**compose.override.yml**

```yaml
services:
  claudephp:
    image: ghcr.io/hkdevcz/claudephp:8.4
    environment:
      USER_UID: ${USER_UID:-1000}
      USER_GID: ${USER_GID:-1000}
    volumes:
      - .:/app
    ports:
      - "9000:9000"
```

Then run:

```bash
# Set your UID/GID in environment
export USER_UID=$(id -u)
export USER_GID=$(id -g)

# Run Claude
docker compose run --rm claudephp claude
```

Or create a `.env` file in your project root:
```bash
USER_UID=1000
USER_GID=1000
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `USER_UID` | User ID to match host user permissions | `1000` |
| `USER_GID` | Group ID to match host user permissions | `1000` |
| `SETUP_GIT_EXCLUDES` | Automatically add Claude files to `.git/info/exclude` | `false` |

## Bash Shortcut

To make it easier to use, add an alias to your `~/.bashrc` or `~/.zshrc`:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias claudephp='docker run -it --rm -v $(pwd):/app -e USER_UID=$(id -u) -e USER_GID=$(id -g) ghcr.io/hkdevcz/claudephp:8.4 claude'
```

Then reload your shell configuration:

```bash
source ~/.bashrc  # or source ~/.zshrc for zsh
```

Now you can run Claude from any project directory with just:

```bash
cd /path/to/your/project
claudephp
```

### With git excludes:

If you want to always setup git excludes, modify the alias:

```bash
alias claudephp='docker run -it --rm -v $(pwd):/app -e USER_UID=$(id -u) -e USER_GID=$(id -g) -e SETUP_GIT_EXCLUDES=true ghcr.io/hkdevcz/claudephp:8.4 claude'
```

### Alternative function for more flexibility:

For more control, add a function instead of an alias:

```bash
# Add to ~/.bashrc or ~/.zshrc
claudephp() {
    local setup_git_excludes=false
    local args=()

    # Parse custom arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-git-excludes)
                setup_git_excludes=true
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    docker run -it --rm \
        -v "$(pwd):/app" \
        -e USER_UID=$(id -u) \
        -e USER_GID=$(id -g) \
        -e SETUP_GIT_EXCLUDES=$setup_git_excludes \
        ghcr.io/hkdevcz/claudephp:8.4 claude "${args[@]}"
}
```

This allows you to pass arguments to Claude and control git excludes:

```bash
claudephp --help
claudephp --version
claudephp --setup-git-excludes  # Enable automatic git excludes for this run
```

## Project-Specific Containers

If you run a project-specific PHP container, it's better to get inspired by this setup and copy the Claude installation directly into your project's Dockerfile.
