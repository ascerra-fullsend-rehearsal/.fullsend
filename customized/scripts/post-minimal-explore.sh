#!/usr/bin/env bash
# post-minimal-explore.sh — Post a short exploration summary to the GitHub issue.
#
# Runs on the host after sandbox cleanup. Treats agent output as untrusted.
#
# Required env vars:
#   SOURCE_REPO   — owner/repo
#   ISSUE_NUMBER  — GitHub issue number
#   GH_TOKEN      — GitHub token with issues:write
#
# Optional:
#   DRY_RUN       — "true" to skip the issue comment (default: false)

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"

if [[ -z "${SOURCE_REPO:-}" || -z "${ISSUE_NUMBER:-}" ]]; then
  echo "ERROR: SOURCE_REPO and ISSUE_NUMBER are required"
  exit 1
fi

if [[ ! "${SOURCE_REPO}" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: SOURCE_REPO format invalid"
  exit 1
fi

if [[ ! "${ISSUE_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: ISSUE_NUMBER must be numeric"
  exit 1
fi

RESULT_FILE=""
for dir in iteration-*/output; do
  if [[ -f "${dir}/agent-result.json" ]]; then
    RESULT_FILE="${dir}/agent-result.json"
  fi
done

if [[ -z "${RESULT_FILE}" ]]; then
  echo "ERROR: agent-result.json not found in any iteration output directory"
  exit 1
fi

echo "Reading minimal-explore result from: ${RESULT_FILE}"

if ! jq empty "${RESULT_FILE}" 2>/dev/null; then
  echo "ERROR: ${RESULT_FILE} is not valid JSON"
  exit 1
fi

STATUS=$(jq -r '.status // empty' "${RESULT_FILE}")
case "${STATUS}" in
  complete|needs_input|error) ;;
  *)
    echo "ERROR: Unknown or missing status '${STATUS}'"
    exit 1
    ;;
esac

SUMMARY=$(jq -r '.summary // empty' "${RESULT_FILE}")
CONFIDENCE=$(jq -r '.confidence // 0' "${RESULT_FILE}")
# Bound agent-controlled strings before any write (output is untrusted).
SUMMARY="${SUMMARY:0:500}"
FINDINGS=$(jq -r '(.findings // [])[:8][] | "- \(.[0:500])"' "${RESULT_FILE}" 2>/dev/null || true)
RELATED=$(jq -r '(.related_issues // [])[:5][] | "- #\(.number): \(.title[0:200]) — \(.relevance[0:300])"' "${RESULT_FILE}" 2>/dev/null || true)

{
  echo "## Minimal Explore"
  echo
  echo "${SUMMARY}"
  echo
  echo "**Status:** \`${STATUS}\` · **Confidence:** ${CONFIDENCE}/100"
  if [[ -n "${FINDINGS}" ]]; then
    echo
    echo "### Findings"
    echo "${FINDINGS}"
  fi
  if [[ -n "${RELATED}" ]]; then
    echo
    echo "### Related issues"
    echo "${RELATED}"
  fi
  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
    echo
    echo "---"
    echo "[Workflow run](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
  fi
} > /tmp/minimal-explore-comment.md

# GitHub Actions step summary (always)
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat /tmp/minimal-explore-comment.md >> "${GITHUB_STEP_SUMMARY}"
fi

echo "::notice::minimal-explore status=${STATUS} confidence=${CONFIDENCE}"

if [[ "${STATUS}" == "error" ]]; then
  echo "::warning::Agent reported status=error — skipping issue comment"
  cat /tmp/minimal-explore-comment.md
  exit 0
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "::notice::DRY_RUN=true — skipping issue comment"
  cat /tmp/minimal-explore-comment.md
  exit 0
fi

gh issue comment "${ISSUE_NUMBER}" \
  --repo "${SOURCE_REPO}" \
  --body-file /tmp/minimal-explore-comment.md

echo "::notice::Posted minimal-explore comment on ${SOURCE_REPO}#${ISSUE_NUMBER}"
