#!/usr/bin/env bash
# pre-minimal-explore.sh — Fetch a GitHub issue for the minimal-explore agent.
#
# Runs on the host before the sandbox starts. Credentials never enter the sandbox.
#
# Required env vars:
#   SOURCE_REPO   — owner/repo
#   ISSUE_NUMBER  — GitHub issue number
#   GH_TOKEN      — GitHub token with issues:read

set -euo pipefail

WORKSPACE="/tmp/workspace"
mkdir -p "$WORKSPACE"

if [[ -z "${SOURCE_REPO:-}" ]]; then
  echo "ERROR: SOURCE_REPO is required (owner/repo)"
  exit 1
fi

if [[ ! "${SOURCE_REPO}" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: SOURCE_REPO format invalid: must be owner/repo"
  exit 1
fi

if [[ -z "${ISSUE_NUMBER:-}" || ! "${ISSUE_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: ISSUE_NUMBER must be a positive integer"
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "ERROR: GH_TOKEN is required"
  exit 1
fi

echo "::notice::Pre-minimal-explore: fetching ${SOURCE_REPO}#${ISSUE_NUMBER}"

gh issue view "${ISSUE_NUMBER}" --repo "${SOURCE_REPO}" \
  --json number,title,body,author,labels,state,createdAt,updatedAt,url,comments \
  > "${WORKSPACE}/issue-context.json"

# Attach lightweight repo metadata so the agent has a starting point even if
# later API calls are rate-limited.
gh api "repos/${SOURCE_REPO}" \
  --jq '{full_name, description, language, default_branch, open_issues_count, html_url}' \
  > "${WORKSPACE}/repo-meta.json"

jq -n \
  --slurpfile issue "${WORKSPACE}/issue-context.json" \
  --slurpfile repo "${WORKSPACE}/repo-meta.json" \
  --arg source_repo "${SOURCE_REPO}" \
  '{
    source: "github",
    source_repo: $source_repo,
    issue: $issue[0],
    repo: $repo[0]
  }' > "${WORKSPACE}/issue-context.json.tmp"

mv "${WORKSPACE}/issue-context.json.tmp" "${WORKSPACE}/issue-context.json"
rm -f "${WORKSPACE}/repo-meta.json"

echo "::notice::Pre-minimal-explore complete"
