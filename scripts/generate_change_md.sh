#!/bin/bash

set -e

TAG=$1

if [ -z "$TAG" ]; then
    echo "No tag provided"
    exit 1
fi

# Get previous tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "")

if [ -z "$PREV_TAG" ]; then
    # First tag, get all commits
    LOG_CMD="git log --pretty=format:\"- %s\" --reverse"
else
    LOG_CMD="git log --pretty=format:\"- %s\" --reverse $PREV_TAG..HEAD"
fi

# Generate markdown
{
    echo "# Changes for $TAG"
    echo ""
    eval $LOG_CMD
} > change.md

echo "Generated change.md"