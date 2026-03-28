#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
short_cwd=$(echo "$cwd" | awk -F/ '{if (NF>=2) print $(NF-1)"/"$NF; else print $NF}')
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
branch=$(cd "$cwd" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m" "$(whoami)" "$(hostname -s)" "$short_cwd"
printf " \033[33m[%s]\033[00m \033[36m%s%%\033[00m" "$model" "$ctx"
[ -n "$branch" ] && printf " \033[35m(%s)\033[00m" "$branch"
