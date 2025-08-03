#!/bin/bash

# OpenCode PR Merging Script
# Merges PRs systematically with conflict detection and resolution tracking

# set -e - commented out to continue processing after conflicts

# Configuration
INTEGRATION_BRANCH="integration-branch"
TRACKING_FILE="pr-tracking.json"
LOG_FILE="merge-log.txt"

# Initialize tracking file if it doesn't exist
if [ ! -f "$TRACKING_FILE" ]; then
    echo '{"merged_prs":[],"failed_prs":[],"skipped_prs":[],"last_updated":""}' > "$TRACKING_FILE"
fi

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to update tracking file
update_tracking() {
    local pr_number=$1
    local status=$2
    local message=$3
    local commit_hash=${4:-""}
    
    # Create temporary file with updated data
    jq --arg pr "$pr_number" \
       --arg status "$status" \
       --arg message "$message" \
       --arg commit "$commit_hash" \
       --arg timestamp "$(date -Iseconds)" \
       '.last_updated = $timestamp | 
        if $status == "merged" then
            .merged_prs += [{
                "pr_number": ($pr | tonumber),
                "commit_hash": $commit,
                "merged_at": $timestamp,
                "message": $message
            }]
        elif $status == "failed" then
            .failed_prs += [{
                "pr_number": ($pr | tonumber),
                "failed_at": $timestamp,
                "reason": $message
            }]
        elif $status == "skipped" then
            .skipped_prs += [{
                "pr_number": ($pr | tonumber),
                "skipped_at": $timestamp,
                "reason": $message
            }]
        else . end' "$TRACKING_FILE" > "${TRACKING_FILE}.tmp"
    
    mv "${TRACKING_FILE}.tmp" "$TRACKING_FILE"
}

# Function to check if PR is already processed
is_pr_processed() {
    local pr_number=$1
    jq -e --arg pr "$pr_number" '
        (.merged_prs[] | select(.pr_number == ($pr | tonumber))) or
        (.failed_prs[] | select(.pr_number == ($pr | tonumber))) or
        (.skipped_prs[] | select(.pr_number == ($pr | tonumber)))
    ' "$TRACKING_FILE" > /dev/null
}

# Function to merge a single PR
merge_pr() {
    local pr_number=$1
    local pr_title=$2
    local author=$3
    
    log_message "🔄 Processing PR #$pr_number: $pr_title (@$author)"
    
    # Check if already processed
    if is_pr_processed "$pr_number"; then
        log_message "⏭️  PR #$pr_number already processed, skipping"
        return 0
    fi
    
    # Switch to integration branch
    git checkout "$INTEGRATION_BRANCH"
    
    # Create a temporary branch for this PR
    local temp_branch="temp-pr-$pr_number"
    git branch -D "$temp_branch" 2>/dev/null || true
    git checkout -b "$temp_branch"
    
    # Try to merge the PR
    if git merge "upstream/pr/$pr_number" --no-edit -m "Merge PR #$pr_number: $pr_title

Merged from: https://github.com/sst/opencode/pull/$pr_number
Author: @$author
Auto-merged by opencode-fork integration system"; then
        
        # Merge successful, switch back to integration branch and merge
        git checkout "$INTEGRATION_BRANCH"
        local commit_hash=$(git merge "$temp_branch" --no-edit | grep -o '[a-f0-9]\{7,\}' | head -1)
        
        # Clean up temp branch
        git branch -D "$temp_branch"
        
        log_message "✅ Successfully merged PR #$pr_number (commit: $commit_hash)"
        update_tracking "$pr_number" "merged" "Successfully merged" "$commit_hash"
        
        return 0
    else
        # Merge failed due to conflicts
        git merge --abort 2>/dev/null || true
        git checkout "$INTEGRATION_BRANCH"
        git branch -D "$temp_branch" 2>/dev/null || true
        
        log_message "❌ Failed to merge PR #$pr_number due to conflicts"
        update_tracking "$pr_number" "failed" "Merge conflicts detected"
        
        return 1
    fi
}

# Main execution
echo "🚀 Starting PR merge process..."
log_message "Starting new merge session"

# Ensure we're in the right directory and branch exists
if ! git show-ref --verify --quiet "refs/heads/$INTEGRATION_BRANCH"; then
    log_message "❌ Integration branch '$INTEGRATION_BRANCH' not found. Run setup-fork.sh first."
    exit 1
fi

# Fetch latest changes
log_message "📡 Fetching latest changes..."
git fetch upstream
git fetch upstream "+refs/pull/*/head:refs/remotes/upstream/pr/*"

# Read PR list and process them
if [ ! -f "pr-analysis/pr-list.csv" ]; then
    log_message "❌ PR list not found. Run analyze-prs.sh first."
    exit 1
fi

# Process PRs (skip header if exists)
TOTAL_PRS=$(wc -l < pr-analysis/pr-list.csv)
CURRENT=0

while IFS=',' read -r pr_number title author created_at url || [ -n "$pr_number" ]; do
    # Skip empty lines
    [ -z "$pr_number" ] && continue
    
    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TOTAL_PRS] Processing PR #$pr_number"
    
    # Ask user for confirmation (optional - can be automated)
    if [ "${AUTO_MERGE:-}" != "true" ]; then
        echo "PR #$pr_number: $title (@$author)"
        echo "URL: $url"
        read -p "Merge this PR? [y/N/s(kip)/q(uit)]: " -r response
        case $response in
            [yY]*)
                merge_pr "$pr_number" "$title" "$author"
                ;;
            [sS]*)
                log_message "⏭️  Skipping PR #$pr_number by user request"
                update_tracking "$pr_number" "skipped" "Skipped by user"
                ;;
            [qQ]*)
                log_message "🛑 Merge process stopped by user"
                exit 0
                ;;
            *)
                log_message "⏭️  Skipping PR #$pr_number (default action)"
                update_tracking "$pr_number" "skipped" "Skipped by user (default)"
                ;;
        esac
    else
        # Automatic mode - merge all
        merge_pr "$pr_number" "$title" "$author"
    fi
    
    # Optional: Add delay to avoid overwhelming the system
    sleep 1
    
done < pr-analysis/pr-list.csv

log_message "🎉 Merge process completed!"

# Generate summary report
MERGED_COUNT=$(jq '.merged_prs | length' "$TRACKING_FILE")
FAILED_COUNT=$(jq '.failed_prs | length' "$TRACKING_FILE")
SKIPPED_COUNT=$(jq '.skipped_prs | length' "$TRACKING_FILE")

log_message "📊 Summary: $MERGED_COUNT merged, $FAILED_COUNT failed, $SKIPPED_COUNT skipped"

echo "
🎯 Merge Summary:
- ✅ Merged: $MERGED_COUNT PRs  
- ❌ Failed: $FAILED_COUNT PRs
- ⏭️  Skipped: $SKIPPED_COUNT PRs
- 📄 Tracking file: $TRACKING_FILE
- 📋 Log file: $LOG_FILE
"
