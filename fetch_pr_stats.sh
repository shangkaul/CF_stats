#!/bin/bash

# Get already fetched PRs to skip them
already_fetched=$(tail -n +2 pr_stats.csv 2>/dev/null | awk -F',' '{print $1 "#" $2}' | tr -d '"')

total=$(jq 'length' all_prs_2025.json)
current=0

jq -r '.[] | "\(.repository.nameWithOwner),\(.number)"' all_prs_2025.json | while IFS=, read REPO PR_NUM; do
  current=$((current + 1))
  
  # Skip if already fetched
  if echo "$already_fetched" | grep -q "^${REPO}#${PR_NUM}$"; then
    echo "[$current/$total] Skipping $REPO#$PR_NUM (already fetched)"
    continue
  fi
  
  echo "[$current/$total] Fetching stats for $REPO#$PR_NUM"
  gh api repos/$REPO/pulls/$PR_NUM --jq "[\"$REPO\", $PR_NUM, .additions, .deletions] | @csv" >> pr_stats.csv
  
  # Small delay to avoid rate limiting
  sleep 0.1
done

echo "Done! Total PRs fetched: $(tail -n +2 pr_stats.csv | wc -l)"
