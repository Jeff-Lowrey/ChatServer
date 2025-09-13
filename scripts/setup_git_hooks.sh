#!/bin/bash
# Script to set up git hooks for the ChatServer repository

# Colors for output
BOLD="\033[1m"
NORMAL="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"

# Get the root directory of the repository
REPO_ROOT=$(git rev-parse --show-toplevel)

echo -e "${BLUE}${BOLD}Setting up git hooks for ChatServer...${NORMAL}"

# Create the git hooks directory if it doesn't exist
if [ ! -d "$REPO_ROOT/.git/hooks" ]; then
    echo -e "${YELLOW}Creating git hooks directory...${NORMAL}"
    mkdir -p "$REPO_ROOT/.git/hooks"
fi

# Make sure the .githooks directory exists
if [ ! -d "$REPO_ROOT/.githooks" ]; then
    echo -e "${RED}Error: .githooks directory not found.${NORMAL}"
    exit 1
fi

# Copy all hooks from .githooks to .git/hooks
echo -e "${BLUE}Installing git hooks...${NORMAL}"
cp -f $REPO_ROOT/.githooks/* $REPO_ROOT/.git/hooks/

# Make all hooks executable
chmod +x $REPO_ROOT/.git/hooks/*

echo -e "${GREEN}${BOLD}Git hooks installed successfully!${NORMAL}"

# Configure git to use the hooks
git config core.hooksPath .git/hooks

echo -e "${BLUE}Git hooks configuration complete.${NORMAL}"
echo -e "${YELLOW}Note: These hooks will now run automatically on relevant git operations.${NORMAL}"

exit 0
