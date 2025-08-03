#!/bin/bash

# OpenCode Fork Report Generator
# Generates detailed reports about merged, failed, and skipped PRs

set -euo pipefail

TRACKING_FILE="pr-tracking.json"
REPORT_FILE="INTEGRATION_REPORT.md"

if [ ! -f "$TRACKING_FILE" ]; then
    echo "❌ Tracking file not found. Run merge-prs.sh first."
    exit 1
fi

echo "📊 Generating integration report..."

# Generate markdown report
cat > "$REPORT_FILE" << EOF
# OpenCode Fork Integration Report

Generated on: $(date)

## Summary

EOF

MERGED_COUNT=$(jq '.merged_prs | length' "$TRACKING_FILE")
FAILED_COUNT=$(jq '.failed_prs | map(.pr_number) | unique | length' "$TRACKING_FILE")
SKIPPED_COUNT=$(jq '.skipped_prs | length' "$TRACKING_FILE")
TOTAL_COUNT=$((MERGED_COUNT + FAILED_COUNT))

cat >> "$REPORT_FILE" << EOF
- **Total PRs Processed**: 104
- **✅ Successfully Merged**: $MERGED_COUNT PRs
- **❌ Failed (Conflicts)**: $FAILED_COUNT PRs  
- **⏭️ Skipped**: $SKIPPED_COUNT PRs
- **Success Rate**: $(( (MERGED_COUNT * 100) / TOTAL_COUNT ))% (of attempted merges)

## Successfully Merged PRs

EOF

# Add merged PRs
jq -r '.merged_prs[] | "- [#\(.pr_number)](https://github.com/sst/opencode/pull/\(.pr_number)) - Merged on \(.merged_at[:10]) (commit: `\(.commit_hash)`)"' "$TRACKING_FILE" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << EOF

## Failed PRs (Merge Conflicts)

These PRs failed to merge automatically due to conflicts and may require manual resolution:

EOF

# Add failed PRs (unique only)
jq -r '.failed_prs | map(.pr_number) | unique[] | "- [#\(.)](https://github.com/sst/opencode/pull/\(.))"' "$TRACKING_FILE" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << EOF

## Repository Information

- **Fork URL**: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')
- **Integration Branch**: \`integration-branch\`
- **Original Repository**: https://github.com/sst/opencode
- **Last Updated**: $(jq -r '.last_updated' "$TRACKING_FILE")

## Next Steps

1. **Use the integrated version**: The \`integration-branch\` contains all successfully merged PRs
2. **Handle conflicts**: Review failed PRs for manual conflict resolution
3. **Stay updated**: Run update scripts periodically to fetch new PRs
4. **Build and test**: Ensure the integrated version builds and works correctly

## Files in this Fork

- \`pr-tracking.json\` - Complete tracking data of all PR merge attempts
- \`merge-log.txt\` - Detailed log of the merge process  
- \`pr-analysis/\` - Analysis data of all open PRs
- \`analyze-prs.sh\` - Script to analyze new PRs
- \`merge-prs.sh\` - Script to merge PRs automatically
- \`generate-report.sh\` - This report generator
- \`update-fork.sh\` - Script to update with new PRs (coming soon)

EOF

echo "✅ Report generated: $REPORT_FILE"

# Also generate a compact terminal-friendly summary
echo ""
echo "🎯 Quick Summary:"
echo "  ✅ $MERGED_COUNT merged"
echo "  ❌ $FAILED_COUNT failed" 
echo "  ⏭️  $SKIPPED_COUNT skipped"
echo "  📊 Success rate: $(( (MERGED_COUNT * 100) / TOTAL_COUNT ))%"
echo ""
echo "📄 Full report: $REPORT_FILE"
echo "🔗 Fork: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')"
