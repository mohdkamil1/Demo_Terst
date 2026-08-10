#!/usr/bin/env bash
#
# sonar-skip-tracker.sh
# ---------------------
# Maintains a per-user "SonarQube skip" counter in a GitHub repository variable
# (JSON: { "alice": 3, "bob": 0 }) and decides whether the current push should
# be scanned or is allowed to skip.
#
# Behaviour (THRESHOLD = 5 by default):
#   - Each commit containing "[skip sonar]" increments the pusher's counter.
#   - counts 1..4  -> skip allowed, silent.
#   - count  == 5  -> skip allowed, but warning email is sent (notify=true).
#   - count  >  5  -> skip IGNORED, scan is forced (should_scan=true, enforced=true, notify=true).
#   - A commit WITHOUT the flag runs a normal scan; the counter is reset to 0
#     afterwards by the workflow's reset step (RESET=true).
#
# Required env:
#   GH_TOKEN   PAT/App token with "Variables: read and write" on the repo
#   REPO       owner/repo  (github.repository)
#   ACTOR      github.actor (the pusher)
# Optional env:
#   COMMIT_MESSAGE, PUSHER_EMAIL, ADMIN_EMAIL, THRESHOLD (default 5),
#   VAR_NAME (default SONAR_SKIP_TRACKER), RESET (default false)

set -euo pipefail

VAR_NAME="${VAR_NAME:-SONAR_SKIP_TRACKER}"
THRESHOLD="${THRESHOLD:-5}"
RESET="${RESET:-false}"
ACTOR="${ACTOR:?ACTOR is required}"
REPO="${REPO:?REPO is required}"

out() { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

# --- Fail open when the tracker token is missing ----------------------------
# Without GH_TOKEN we cannot read or write the skip counter. Rather than break
# the whole pipeline, disable tracking and let the scan run -- the safe
# direction, since the worst case is "we scanned when we could have skipped".
if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN is not set -- skip tracking disabled, forcing a normal scan."
  echo "Add a SONAR_SKIP_PAT secret (Variables: read and write) to enable it."
  out should_scan true
  out notify     false
  out enforced   false
  out skip_count 0
  out recipients ""
  exit 0
fi

read_tracker() {
  gh api "repos/$REPO/actions/variables/$VAR_NAME" --jq '.value' 2>/dev/null || echo ""
}

save_tracker() {
  local value="$1"
  if gh api "repos/$REPO/actions/variables/$VAR_NAME" >/dev/null 2>&1; then
    gh api -X PATCH "repos/$REPO/actions/variables/$VAR_NAME" \
      -f name="$VAR_NAME" -f value="$value" >/dev/null
  else
    gh api -X POST "repos/$REPO/actions/variables" \
      -f name="$VAR_NAME" -f value="$value" >/dev/null
  fi
}

# --- Load + validate current state ------------------------------------------
raw="$(read_tracker)"
[ -z "$raw" ] && raw="{}"
echo "$raw" | jq empty 2>/dev/null || raw="{}"

# --- Reset mode (called after a successful scan) ----------------------------
if [ "$RESET" = "true" ]; then
  updated="$(jq -c --arg u "$ACTOR" 'del(.[$u])' <<<"$raw")"
  save_tracker "$updated"
  echo "Reset skip counter for $ACTOR"
  exit 0
fi

# --- Detect skip request ----------------------------------------------------
skip_requested=false
if printf '%s' "${COMMIT_MESSAGE:-}" | grep -qiE '\[skip[ -]sonar\]'; then
  skip_requested=true
fi

count="$(jq -r --arg u "$ACTOR" '.[$u] // 0' <<<"$raw")"
should_scan=true
notify=false
enforced=false

if [ "$skip_requested" = "true" ]; then
  count=$((count + 1))
  if   [ "$count" -gt "$THRESHOLD" ]; then
    should_scan=true;  notify=true;  enforced=true      # over limit: force the scan
  elif [ "$count" -eq "$THRESHOLD" ]; then
    should_scan=false; notify=true;  enforced=false     # at limit: last free skip + warn
  else
    should_scan=false; notify=false; enforced=false     # under limit: silent skip
  fi
  updated="$(jq -c --arg u "$ACTOR" --argjson c "$count" '.[$u]=$c' <<<"$raw")"
  save_tracker "$updated"
else
  should_scan=true                                       # normal scan; reset happens post-scan
fi

# --- Build email recipient list (admin + pusher, de-duplicated) -------------
recipients="${ADMIN_EMAIL:-}"
if [ -n "${PUSHER_EMAIL:-}" ] && [ "${PUSHER_EMAIL}" != "${ADMIN_EMAIL:-}" ]; then
  recipients="${recipients:+$recipients,}$PUSHER_EMAIL"
fi

# --- Outputs ----------------------------------------------------------------
out should_scan "$should_scan"
out notify      "$notify"
out enforced    "$enforced"
out skip_count  "$count"
out recipients  "$recipients"

echo "actor=$ACTOR skip_requested=$skip_requested count=$count/$THRESHOLD should_scan=$should_scan enforced=$enforced notify=$notify"
