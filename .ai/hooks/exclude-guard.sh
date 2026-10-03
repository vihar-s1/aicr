#!/usr/bin/env bash
# exclude-guard.sh — enforce .ai/exclusions.md at the tool layer.
#
# Claude Code PreToolUse hook. Receives the tool call as JSON on stdin,
# extracts the target path, and blocks the call if it matches any pattern
# in .ai/exclusions.md.
#
# Exit codes: 0 = allow, 2 = block (stderr is shown to the assistant).
#
# Wire it up in .claude/settings.json — see docs/hooks.md.

set -uo pipefail

AI_DIR="${AICR_DIR:-.ai}"
EXCLUSIONS="$AI_DIR/exclusions.md"

[ -f "$EXCLUSIONS" ] || exit 0

payload=$(cat)

# Extract the path the tool wants to touch.
if command -v jq >/dev/null 2>&1; then
  file=$(printf '%s' "$payload" | jq -r '
    .tool_input.file_path // .tool_input.path // .tool_input.notebook_path // empty
  ')
else
  # Fail open, loudly: a missing jq must not silently disable the guard.
  echo "[aicr] exclude-guard: jq not found — exclusions are NOT enforced" >&2
  exit 0
fi

[ -n "$file" ] || exit 0

# Compare repo-relative paths so patterns don't depend on where the repo lives.
#
# Patterns in exclusions.md are project-relative, so they only have meaning for
# paths inside the project. An absolute path elsewhere on the machine is out of
# scope and must be allowed through: stripping $PWD from it is a no-op, which
# would leave `rel` absolute and let a pattern like **/*.png match any file on
# the disk — including ones the user deliberately handed to the assistant.
# Guarding paths outside the project is a user-settings concern, not this hook's.
case "$file" in
  "$PWD"/*) rel="${file#"$PWD"/}" ;;
  /*)       exit 0 ;;                 # absolute, outside the project
  *)        rel="${file#./}" ;;       # already relative
esac
rel="${rel#./}"

# A relative path that climbs out of the project is out of scope too.
case "$rel" in
  ../*) exit 0 ;;
esac

# Translate a gitignore-style glob into an anchored regex.
#   **/  -> (.*/)? (any depth, including none)    **  -> .*
#   *    -> [^/]*                                 ?   -> [^/]
glob_to_regex() {
  local p="$1" out=""
  local -i i=0 n=${#p}
  while (( i < n )); do
    local c="${p:i:1}"
    case "$c" in
      '*')
        if [[ "${p:i:3}" == '**/' ]]; then out+='(.*/)?'; i+=3; continue; fi
        if [[ "${p:i:2}" == '**'  ]]; then out+='.*';      i+=2; continue; fi
        out+='[^/]*'; i+=1 ;;
      '?')  out+='[^/]'; i+=1 ;;
      '/')  out+='/';    i+=1 ;;
      *)    out+=$(printf '%s' "$c" | sed 's/[][\.^$(){}+|]/\\&/g'); i+=1 ;;
    esac
  done
  printf '%s' "$out"
}

# No pipeline here: a `while read` in a pipeline runs in a subshell, so an
# exit inside it would only kill the subshell and the guard would never fire.
while IFS= read -r line; do
  line="${line%%#*}"                       # strip inline comments
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -n "$line" ] || continue

  pattern="$line"
  [[ "$pattern" == */ ]] && pattern="${pattern}**"   # `dir/` means its contents

  regex="^$(glob_to_regex "$pattern")$"
  if [[ "$rel" =~ $regex ]]; then
    echo "[aicr] Blocked by $EXCLUSIONS (pattern: $line): $rel" >&2
    exit 2
  fi
done < "$EXCLUSIONS"

exit 0
