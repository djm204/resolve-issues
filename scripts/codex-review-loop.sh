#!/usr/bin/env bash
#
# codex-review-loop.sh — drive the GitHub Codex (@codex) review loop on a PR.
#
# The mechanical half of the codex review loop (see docs/adr/003-codex-review-loop.md):
# detect the connector, trigger a review, poll the three GitHub channels Codex uses, and
# classify the outcome as clean / findings / working. The judgement half (is a finding a
# real issue, how to fix it) stays with the calling agent.
#
# Actions:
#   detect   --repo OWNER/NAME
#       Exit 0 and print {"available":true} if the Codex connector has reviewed in this
#       repo before (best-effort). Exit 0 and print {"available":false} otherwise.
#
#   trigger  --repo OWNER/NAME --pr N
#       Post an "@codex review" comment on PR N. Prints the trigger time (ISO8601 UTC).
#
#   poll     --repo OWNER/NAME --pr N --since ISO8601
#       Fetch the three channels and classify bot activity newer than --since.
#       Prints the classification JSON (see "classify" for the shape).
#
#   classify --input FILE   (or stdin)
#       Pure classifier — no network. Reads a JSON object:
#         {
#           "since":          "<ISO8601>",                 # trigger time
#           "botLogin":       "chatgpt-codex-connector",   # optional, default as shown
#           "issueComments":  [ {user:{login}, created_at, body}, ... ],
#           "reviews":        [ {user:{login}, submitted_at, state, body}, ... ],
#           "inlineComments": [ {user:{login}, created_at, body, path, line, id}, ... ]
#         }
#       Prints:
#         {
#           "status":   "clean" | "findings" | "working",
#           "respondedAt": "<ISO8601 or null>",
#           "findings": [ {source, path, line, id, body}, ... ]
#         }
#       Codex's "[bot]" suffix on user.login is tolerated.
#
# Exit codes: 0 ok, 2 usage error.
#
set -euo pipefail

DEFAULT_BOT="chatgpt-codex-connector"
# Terminal "clean pass" signals — Codex posts a top-level issue comment on no findings.
CLEAN_REGEX="didn't find any major issues|did not find any major issues|no major issues|no issues found|no actionable findings|looks good to me|no suggestions"

die() { echo "codex-review-loop.sh: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

# ---- pure classifier (shared by `classify` and `poll`) ----------------------
# Reads the channels JSON on stdin, writes classification JSON to stdout.
classify_json() {
  jq --arg cleanre "$CLEAN_REGEX" --arg defbot "$DEFAULT_BOT" '
    (.botLogin // $defbot)              as $bot
    | (.since // "")                    as $since
    # normalize a login like "chatgpt-codex-connector[bot]" -> base name
    | def base($l): ($l // "" | sub("\\[bot\\]$"; ""));
      def fromBot($u): (base($u.login) == $bot);
      def newer($ts): ($since == "" or (($ts // "") > $since));

      ([ .issueComments[]?  | select(fromBot(.user) and newer(.created_at)) ]) as $ic
    | ([ .reviews[]?        | select(fromBot(.user) and newer(.submitted_at))]) as $rv
    | ([ .inlineComments[]? | select(fromBot(.user) and newer(.created_at)) ]) as $il

    # clean if any bot issue-comment matches a terminal clean signal
    | ([ $ic[] | select((.body // "") | ascii_downcase | test($cleanre)) ]) as $clean

    | ([ $il[] | {source:"inline", path:(.path//null), line:(.line//null), id:(.id//null), body:(.body//"")} ]
        + [ $rv[] | select((.state//"") != "APPROVED" and (.body//"") != "")
              | {source:"review", path:null, line:null, id:(.id//null), body:(.body//"")} ]) as $findings

    | ([ $ic[].created_at, $rv[].submitted_at, $il[].created_at ] | map(select(. != null)) | sort | last) as $respondedAt

    | if ($clean | length) > 0 then
        {status:"clean",    respondedAt:$respondedAt, findings:[]}
      elif ($findings | length) > 0 then
        {status:"findings", respondedAt:$respondedAt, findings:$findings}
      else
        {status:"working",  respondedAt:($respondedAt // null), findings:[]}
      end
  '
}

# ---- arg parsing ------------------------------------------------------------
[ $# -ge 1 ] || die "no action; expected detect|trigger|poll|classify"
ACTION="$1"; shift

REPO=""; PR=""; SINCE=""; INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:?--repo needs a value}";  shift 2 ;;
    --pr)    PR="${2:?--pr needs a value}";       shift 2 ;;
    --since) SINCE="${2:?--since needs a value}"; shift 2 ;;
    --input) INPUT="${2:?--input needs a value}"; shift 2 ;;
    -h|--help) sed -n '3,55p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

need jq

case "$ACTION" in
  classify)
    if [ -n "$INPUT" ]; then cat "$INPUT"; else cat; fi | classify_json
    ;;

  detect)
    need gh
    [ -n "$REPO" ] || die "detect needs --repo"
    # Best-effort: has the connector ever commented in this repo?
    comments="$(gh api "repos/$REPO/issues/comments?per_page=100" 2>/dev/null || echo '[]')"
    hits="$(printf '%s' "$comments" | jq --arg bot "$DEFAULT_BOT" \
              '[ .[]? | select((.user.login // "" | sub("\\[bot\\]$"; "")) == $bot) ] | length' \
              2>/dev/null || echo 0)"
    if [ "${hits:-0}" -gt 0 ] 2>/dev/null; then
      echo '{"available":true}'
    else
      echo '{"available":false}'
    fi
    ;;

  trigger)
    need gh
    [ -n "$REPO" ] || die "trigger needs --repo"
    [ -n "$PR" ]   || die "trigger needs --pr"
    gh pr comment "$PR" --repo "$REPO" --body "@codex review" >/dev/null
    # trigger time from the server's clock (avoids local/remote skew)
    gh api "repos/$REPO" --jq 'now | todate' 2>/dev/null || gh api /octocat --jq 'now | todate'
    ;;

  poll)
    need gh
    [ -n "$REPO" ] || die "poll needs --repo"
    [ -n "$PR" ]   || die "poll needs --pr"
    ic="$(gh api "repos/$REPO/issues/$PR/comments?per_page=100" 2>/dev/null || echo '[]')"
    rv="$(gh api "repos/$REPO/pulls/$PR/reviews?per_page=100"   2>/dev/null || echo '[]')"
    il="$(gh api "repos/$REPO/pulls/$PR/comments?per_page=100"  2>/dev/null || echo '[]')"
    jq -n --argjson ic "$ic" --argjson rv "$rv" --argjson il "$il" --arg since "$SINCE" \
      '{since:$since, issueComments:$ic, reviews:$rv, inlineComments:$il}' \
      | classify_json
    ;;

  *) die "unknown action: $ACTION (expected detect|trigger|poll|classify)" ;;
esac
