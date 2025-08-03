#!/bin/bash

# OpenCode PR Analysis Script
# Analyzes all open PRs and categorizes them for easier management

set -e

echo "🔍 Analyzing open PRs..."

# Create output directory
mkdir -p pr-analysis

# Get all open PRs with detailed information
echo "📊 Fetching PR data..."
curl -s "https://api.github.com/repos/sst/opencode/pulls?state=open&per_page=100&page=1" > pr-analysis/prs-page1.json
curl -s "https://api.github.com/repos/sst/opencode/pulls?state=open&per_page=100&page=2" > pr-analysis/prs-page2.json

# Combine all PRs into one file
jq -s 'add' pr-analysis/prs-page*.json > pr-analysis/all-prs.json

# Generate PR summary report
cat > pr-analysis/pr-summary.md << 'EOF'
# OpenCode PRs Analysis Report

## Summary Statistics
EOF

echo "- Total Open PRs: $(jq 'length' pr-analysis/all-prs.json)" >> pr-analysis/pr-summary.md
echo "- Generated on: $(date)" >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Categorize PRs by type (based on title keywords)
echo "## PR Categories" >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Bug fixes
echo "### 🐛 Bug Fixes" >> pr-analysis/pr-summary.md
jq -r '.[] | select(.title | test("fix|bug|error|issue"; "i")) | "- [#\(.number)](\(.html_url)) \(.title) (@\(.user.login))"' pr-analysis/all-prs.json >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Features  
echo "### ✨ Features" >> pr-analysis/pr-summary.md
jq -r '.[] | select(.title | test("feat|feature|add|support"; "i")) | "- [#\(.number)](\(.html_url)) \(.title) (@\(.user.login))"' pr-analysis/all-prs.json >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Documentation
echo "### 📚 Documentation" >> pr-analysis/pr-summary.md
jq -r '.[] | select(.title | test("doc|readme|docs"; "i")) | "- [#\(.number)](\(.html_url)) \(.title) (@\(.user.login))"' pr-analysis/all-prs.json >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Refactoring/Improvements
echo "### 🔧 Refactoring & Improvements" >> pr-analysis/pr-summary.md
jq -r '.[] | select(.title | test("refactor|improve|optimize|update|upgrade"; "i")) | "- [#\(.number)](\(.html_url)) \(.title) (@\(.user.login))"' pr-analysis/all-prs.json >> pr-analysis/pr-summary.md
echo "" >> pr-analysis/pr-summary.md

# Others
echo "### 🔄 Other Changes" >> pr-analysis/pr-summary.md
jq -r '.[] | select(.title | test("fix|bug|error|issue|feat|feature|add|support|doc|readme|docs|refactor|improve|optimize|update|upgrade"; "i") | not) | "- [#\(.number)](\(.html_url)) \(.title) (@\(.user.login))"' pr-analysis/all-prs.json >> pr-analysis/pr-summary.md

# Generate machine-readable PR list for processing
jq -r '.[] | "\(.number),\(.title),\(.user.login),\(.created_at),\(.html_url)"' pr-analysis/all-prs.json > pr-analysis/pr-list.csv

echo "✅ PR analysis complete!"
echo "📋 Summary report: pr-analysis/pr-summary.md"
echo "📊 Raw data: pr-analysis/all-prs.json"
echo "📄 CSV list: pr-analysis/pr-list.csv"
