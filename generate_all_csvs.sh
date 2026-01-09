#!/bin/bash

echo "Generating all CSV reports..."

# 1. Team summary
echo "metric,value" > team_summary.csv
echo "total_prs,$(jq 'length' all_prs_2025.json)" >> team_summary.csv
echo "unique_repos,$(jq '[.[].repository.nameWithOwner] | unique | length' all_prs_2025.json)" >> team_summary.csv
echo "total_additions,$(tail -n +2 pr_stats.csv | awk -F, '{sum+=$3} END {print sum}')" >> team_summary.csv
echo "total_deletions,$(tail -n +2 pr_stats.csv | awk -F, '{sum+=$4} END {print sum}')" >> team_summary.csv
echo "net_change,$(tail -n +2 pr_stats.csv | awk -F, '{add+=$3; del+=$4} END {print add-del}')" >> team_summary.csv
echo "average_pr_size,$(tail -n +2 pr_stats.csv | awk -F, '{sum+=$3+$4; count++} END {printf "%.1f", sum/count}')" >> team_summary.csv
echo "median_time_to_merge_hours,$(jq 'def h: ((.closedAt|fromdateiso8601) - (.createdAt|fromdateiso8601)) / 3600; map(h) | sort | .[length/2]' all_prs_2025.json)" >> team_summary.csv
echo "✅ Created team_summary.csv"

# 2. Per-author stats
echo "author,total_prs,total_additions,total_deletions,net_change" > author_stats.csv
jq -r '.[] | "\(.author.login),\(.repository.nameWithOwner),\(.number)"' all_prs_2025.json > temp_author_prs.txt

for AUTHOR in $(cut -d, -f1 temp_author_prs.txt | sort -u); do
  prs=$(grep "^$AUTHOR," temp_author_prs.txt | wc -l | tr -d ' ')
  stats=$(grep "^$AUTHOR," temp_author_prs.txt | while IFS=, read auth repo prnum; do
    grep "\"$repo\",$prnum," pr_stats.csv
  done | awk -F, '{add+=$3; del+=$4} END {printf "%d,%d,%d", add, del, add-del}')
  echo "$AUTHOR,$prs,$stats" >> author_stats.csv
done
rm temp_author_prs.txt
echo "✅ Created author_stats.csv"

# 3. Repository stats
jq -r 'group_by(.repository.nameWithOwner) | map({repo: .[0].repository.nameWithOwner, prs: length}) | sort_by(-.prs) | .[] | "\(.repo),\(.prs)"' all_prs_2025.json > temp_repo_counts.txt

echo "repository,total_prs,total_additions,total_deletions,net_change" > repo_stats.csv
while IFS=, read REPO PR_COUNT; do
  stats=$(grep "\"$REPO\"," pr_stats.csv | awk -F, '{add+=$3; del+=$4} END {printf "%d,%d,%d", add, del, add-del}')
  echo "$REPO,$PR_COUNT,$stats" >> repo_stats.csv
done < temp_repo_counts.txt
rm temp_repo_counts.txt
echo "✅ Created repo_stats.csv"

# 4. PR size distribution
echo "size_category,min_lines,max_lines,count,percentage" > pr_size_distribution.csv
tail -n +2 pr_stats.csv | awk -F, '
{
  total = $3 + $4
  if (total <= 10) tiny++
  else if (total <= 50) small++
  else if (total <= 200) medium++
  else if (total <= 500) large++
  else xlarge++
  count++
}
END {
  printf "Tiny,0,10,%d,%.1f\n", tiny, (tiny/count)*100
  printf "Small,11,50,%d,%.1f\n", small, (small/count)*100
  printf "Medium,51,200,%d,%.1f\n", medium, (medium/count)*100
  printf "Large,201,500,%d,%.1f\n", large, (large/count)*100
  printf "X-Large,501,999999,%d,%.1f\n", xlarge, (xlarge/count)*100
}' >> pr_size_distribution.csv
echo "✅ Created pr_size_distribution.csv"

# 5. Language breakdown
echo "language,total_bytes" > language_stats.csv
awk -F, '{lang[$1]+=$2} END {for (l in lang) print l "," lang[l]}' languages_raw.csv | sort -t, -k2 -nr >> language_stats.csv
echo "✅ Created language_stats.csv"

# 6. Top 20 largest PRs
echo "repository,pr_number,lines_changed,additions,deletions" > top_largest_prs.csv
tail -n +2 pr_stats.csv | awk -F, '{print $0 "," ($3+$4)}' | sort -t, -k5 -nr | head -20 | awk -F, '{print $1 "," $2 "," $5 "," $3 "," $4}' >> top_largest_prs.csv
echo "✅ Created top_largest_prs.csv"

# 7. Daily activity
echo "date,prs_created,prs_merged" > daily_activity.csv
jq -r '.[] | "\(.createdAt[0:10])"' all_prs_2025.json | sort | uniq -c | awk '{printf "%s,%d,0\n", $2, $1}' > temp_created.txt
jq -r '.[] | "\(.closedAt[0:10])"' all_prs_2025.json | sort | uniq -c | awk '{printf "%s,0,%d\n", $2, $1}' > temp_merged.txt
cat temp_created.txt temp_merged.txt | awk -F, '{created[$1]+=$2; merged[$1]+=$3} END {for (d in created) print d "," created[d] "," merged[d]}' | sort >> daily_activity.csv
rm temp_created.txt temp_merged.txt
echo "✅ Created daily_activity.csv"

echo ""
echo "🎉 All CSV files generated successfully!"
echo "Files created:"
echo "  - team_summary.csv"
echo "  - author_stats.csv"
echo "  - repo_stats.csv"
echo "  - pr_size_distribution.csv"
echo "  - language_stats.csv"
echo "  - top_largest_prs.csv"
echo "  - daily_activity.csv"
echo "  - pr_stats.csv (already existed)"
