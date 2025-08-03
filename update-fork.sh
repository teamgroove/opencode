#!/bin/bash

# OpenCode Fork Update Script
# Updates the fork with new PRs from the upstream repository

set -euo pipefail

echo "🔄 Updating OpenCode fork..."

# Step 1: Fetch latest changes from upstream
echo "📡 Fetching latest changes from upstream..."
git fetch upstream
git fetch upstream "+refs/pull/*/head:refs/remotes/upstream/pr/*"

# Step 2: Update integration branch with upstream changes
echo "🔀 Updating integration branch..."
git checkout integration-branch
git merge upstream/dev --no-edit || echo "⚠️  Manual merge may be required"

# Step 3: Analyze new PRs
echo "🔍 Analyzing PRs (including any new ones)..."
if [ -f "./analyze-prs.sh" ]; then
    ./analyze-prs.sh
else
    echo "❌ analyze-prs.sh not found"
    exit 1
fi

# Step 4: Show summary of current state
if [ -f "./generate-report.sh" ]; then
    echo "📊 Generating updated report..."
    ./generate-report.sh
fi

echo ""
echo "✅ Fork update complete!"
echo ""
echo "Next steps:"
echo "1. Review pr-analysis/pr-summary.md for new PRs"
echo "2. Run 'AUTO_MERGE=true ./merge-prs.sh' to merge new PRs"
echo "3. Push changes: 'git push origin integration-branch'"
echo ""
echo "Current status:"
git status --short
