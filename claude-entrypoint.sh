#!/bin/sh
set -e

# Handle user permissions - match container user to host user
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# Modify appuser UID/GID to match host user if needed
if [ "$(id -u appuser)" != "$USER_UID" ] || [ "$(id -g appuser)" != "$USER_GID" ]; then
    echo "Adjusting user permissions to UID=$USER_UID, GID=$USER_GID..."

    # Modify group
    groupmod -o -g "$USER_GID" appuser 2>/dev/null || true

    # Modify user
    usermod -o -u "$USER_UID" appuser 2>/dev/null || true

    echo "✓ User permissions adjusted"
fi

# Ensure /app is owned by appuser
chown -R appuser:appuser /app

# Ensure appuser home directory is owned by appuser
chown -R appuser:appuser /home/appuser

# Claude configuration paths
CLAUDE_CONFIG="/home/appuser/.claude.json"
PROJECT_CLAUDE_CONFIG="/app/.claude.json"
CLAUDE_DIR="/home/appuser/.claude"
PROJECT_CLAUDE_DIR="/app/.claude"

# Create project .claude directory if it doesn't exist
mkdir -p "$PROJECT_CLAUDE_DIR"

# Symlink .claude directory to persist authentication and session data
if [ -L "$CLAUDE_DIR" ]; then
    # If it's already a symlink, remove it
    rm -f "$CLAUDE_DIR"
fi

if [ -d "$CLAUDE_DIR" ] && [ ! -L "$CLAUDE_DIR" ]; then
    # Move existing .claude directory contents to project directory
    echo "Migrating Claude data to project directory..."
    cp -rn "$CLAUDE_DIR"/* "$PROJECT_CLAUDE_DIR"/ 2>/dev/null || true
    rm -rf "$CLAUDE_DIR"
fi

# Create symlink from /home/appuser/.claude to /app/.claude
ln -sf "$PROJECT_CLAUDE_DIR" "$CLAUDE_DIR"
echo "✓ Using Claude directory from project ($PROJECT_CLAUDE_DIR)"

# Handle .claude.json file
# Remove default .claude.json if it exists and isn't a symlink
if [ -f "$CLAUDE_CONFIG" ] && [ ! -L "$CLAUDE_CONFIG" ]; then
    rm -f "$CLAUDE_CONFIG"
fi

# Create or use existing project .claude.json
if [ -f "$PROJECT_CLAUDE_CONFIG" ]; then
    echo "✓ Using Claude configuration from project..."
else
    echo "Creating Claude configuration file in project..."
    echo '{}' > "$PROJECT_CLAUDE_CONFIG"
    echo "✓ Claude configuration file created at $PROJECT_CLAUDE_CONFIG"
fi

# Symlink .claude.json to project config
ln -sf "$PROJECT_CLAUDE_CONFIG" "$CLAUDE_CONFIG"

# Setup git excludes if enabled and .git exists
if [ "$SETUP_GIT_EXCLUDES" = "true" ] && [ -d "/app/.git" ]; then
    echo "Setting up git excludes for Claude files..."
    mkdir -p /app/.git/info
    
    # Add Claude-specific excludes (only if not already present)
    grep -qxF ".claude.json" /app/.git/info/exclude 2>/dev/null || echo ".claude.json" >> /app/.git/info/exclude
    grep -qxF ".claude/" /app/.git/info/exclude 2>/dev/null || echo ".claude/" >> /app/.git/info/exclude
    grep -qxF "CLAUDE.md" /app/.git/info/exclude 2>/dev/null || echo "CLAUDE.md" >> /app/.git/info/exclude
    
    echo "✓ Git excludes configured for Claude development environment."
fi

# If we're still root, switch to appuser for the main command
if [ "$(id -u)" -eq 0 ]; then
    # Fix ownership one more time before switching
    chown -R appuser:appuser /app 2>/dev/null || true

    # Check if we're running php-fpm - if so, don't switch users
    # PHP-FPM needs to start as root to initialize, then drops privileges internally
    if [ "$1" = "php-fpm" ]; then
        # Run PHP-FPM as root (it will drop privileges to www-data/nobody internally)
        exec "$@"
    else
        # Execute other commands as appuser
        exec su-exec appuser "$@"
    fi
else
    # Already not root, execute normally
    exec "$@"
fi
