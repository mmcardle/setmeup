#!/usr/bin/env bash
# Claude Code statusLine command — agnoster-inspired
# Receives Claude Code session JSON via stdin.

input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir=$(pwd)
# Shorten home prefix ($HOME must be quoted or bash won't match the pattern)
dir="${dir/#"$HOME"/\~}"

model=$(echo "$input" | jq -r '.model.display_name // empty')
# Shorten the "(1M context)" suffix some models carry to "(1M ctx)"
model="${model/context/ctx}"
# Reasoning effort (low/medium/high/xhigh/max); absent if model lacks the param
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Git branch (prefer worktree branch, then repo branch from git)
branch=$(echo "$input" | jq -r '.worktree.branch // empty')
if [ -z "$branch" ]; then
  branch=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir // empty')" \
    --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

# Context window (populated once there's been an API response this session)
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
size_tok=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Subscription rate limits (absent for non-subscribers; appear after first API response).
# Each window may be independently absent.
rl5_pct=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl7_pct=$(echo "$input"   | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl7_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Compact token formatter: 123456 -> 123k, 1000000 -> 1M
fmt_tokens() {
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) { v=n/1000000; if (v==int(v)) printf "%dM", v; else printf "%.1fM", v }
    else if (n >= 1000) { printf "%dk", int(n/1000) }
    else { printf "%d", n }
  }'
}

# ANSI color by fullness percent: blue <20, green 20–39, yellow 40–59, orange 60–79, red >=80
pct_color() {
  if   [ "$1" -ge 80 ]; then printf '\033[0;31m'      # red
  elif [ "$1" -ge 60 ]; then printf '\033[38;5;208m'  # orange
  elif [ "$1" -ge 40 ]; then printf '\033[0;33m'      # yellow
  elif [ "$1" -ge 20 ]; then printf '\033[0;32m'      # green
  else                       printf '\033[0;34m'; fi  # blue
}

# Countdown to a unix-epoch reset time: 1750000000 -> "2h13m" / "4d6h" / "9m"
fmt_eta() {
  local now delta d h m
  now=$(date +%s)
  delta=$(( $1 - now ))
  [ "$delta" -lt 0 ] && delta=0
  d=$(( delta / 86400 )); h=$(( (delta % 86400) / 3600 )); m=$(( (delta % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
  else                      printf '%dm' "$m"; fi
}

# Build segments
# Colors: yellow for dir, cyan for branch, dim for model
SEG_DIR=$(printf '\033[0;33m%s\033[0m' "$dir")

line="${SEG_DIR}"

if [ -n "$branch" ]; then
  # \xee\x82\xa0 is the powerline branch glyph (U+E0A0, needs a Nerd Font)
  SEG_BRANCH=$(printf '\033[0;36m\xee\x82\xa0 %s\033[0m' "$branch")
  line="${line} \033[2m|\033[0m ${SEG_BRANCH}"
fi

if [ -n "$model" ]; then
  ai="${model}"
  [ -n "$effort" ] && ai="${ai} · ${effort}"
  line="${line} \033[2m| ${ai}\033[0m"
fi

if [ -n "$used" ]; then
  ctx_int=$(printf '%.0f' "$used")

  # 10-cell fullness bar, rounded to nearest cell
  filled=$(( (ctx_int + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = filled; i < 10; i++)); do bar+="░"; done

  color=$(pct_color "$ctx_int")

  SEG_CTX=$(printf '%b▕%s▏ %s%%\033[0m' "$color" "$bar" "$ctx_int")
  # Optional token count, e.g. 123k/1M
  if [ -n "$used_tok" ] && [ -n "$size_tok" ]; then
    SEG_CTX="${SEG_CTX} \033[2m$(fmt_tokens "$used_tok")/$(fmt_tokens "$size_tok")\033[0m"
  fi

  line="${line} \033[2m|\033[0m ${SEG_CTX}"
fi

# Rate limits: 5h and 7d windows, each "<used>% <reset-countdown>"
if [ -n "$rl5_pct" ] || [ -n "$rl7_pct" ]; then
  rl=""

  if [ -n "$rl5_pct" ]; then
    p5=$(printf '%.0f' "$rl5_pct")
    seg=$(printf '%b5h %s%%\033[0m' "$(pct_color "$p5")" "$p5")
    if [ -n "$rl5_reset" ]; then
      seg="${seg}$(printf ' \033[2m%s\033[0m' "$(fmt_eta "$(printf '%.0f' "$rl5_reset")")")"
    fi
    rl="$seg"
  fi

  if [ -n "$rl7_pct" ]; then
    p7=$(printf '%.0f' "$rl7_pct")
    seg=$(printf '%b7d %s%%\033[0m' "$(pct_color "$p7")" "$p7")
    if [ -n "$rl7_reset" ]; then
      seg="${seg}$(printf ' \033[2m%s\033[0m' "$(fmt_eta "$(printf '%.0f' "$rl7_reset")")")"
    fi
    if [ -n "$rl" ]; then rl="${rl} \033[2m·\033[0m ${seg}"; else rl="$seg"; fi
  fi

  line="${line} \033[2m|\033[0m ${rl}"
fi

printf '%b\n' "$line"
