#!/usr/bin/env bash
# pre-minimal-explore.sh — Fetch GitHub issue + repo context on the host.
#
# All GitHub reads happen here so the sandbox needs no api.github.com access
# (rehearsal pins fullsend@v0 / v0.28, which has no provider-profile network
# composition — network must be declared inline, and we keep the sandbox
# Vertex-only).
#
# Required env vars:
#   SOURCE_REPO   — owner/repo
#   ISSUE_NUMBER  — GitHub issue number
#   GH_TOKEN      — GitHub token with issues:read / contents:read

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
  > "${WORKSPACE}/issue.json"

gh api "repos/${SOURCE_REPO}" \
  --jq '{full_name, description, language, default_branch, open_issues_count, html_url, topics}' \
  > "${WORKSPACE}/repo.json"

gh api "repos/${SOURCE_REPO}/languages" > "${WORKSPACE}/languages.json"

gh api "repos/${SOURCE_REPO}/contents/" \
  --jq '[.[] | {name, type, path, size}]' \
  > "${WORKSPACE}/top-level.json"

gh issue list --repo "${SOURCE_REPO}" --state open --limit 15 \
  --json number,title,labels,state,updatedAt \
  > "${WORKSPACE}/open-issues.json"

# Best-effort README (may be missing).
if gh api "repos/${SOURCE_REPO}/readme" --jq '.content' 2>/dev/null \
  | base64 -d > "${WORKSPACE}/README.md" 2>/dev/null; then
  # Cap README size so the sandbox context stays small.
  if [[ $(wc -c < "${WORKSPACE}/README.md") -gt 20000 ]]; then
    head -c 20000 "${WORKSPACE}/README.md" > "${WORKSPACE}/README.md.tmp"
    echo -e "\n…(truncated)…" >> "${WORKSPACE}/README.md.tmp"
    mv "${WORKSPACE}/README.md.tmp" "${WORKSPACE}/README.md"
  fi
else
  echo "(no README)" > "${WORKSPACE}/README.md"
fi

jq -n \
  --slurpfile issue "${WORKSPACE}/issue.json" \
  --slurpfile repo "${WORKSPACE}/repo.json" \
  --slurpfile languages "${WORKSPACE}/languages.json" \
  --slurpfile top_level "${WORKSPACE}/top-level.json" \
  --slurpfile open_issues "${WORKSPACE}/open-issues.json" \
  --rawfile readme "${WORKSPACE}/README.md" \
  --arg source_repo "${SOURCE_REPO}" \
  '{
    source: "github",
    source_repo: $source_repo,
    issue: $issue[0],
    repo: $repo[0],
    languages: $languages[0],
    top_level_entries: $top_level[0],
    open_issues: $open_issues[0],
    readme: $readme
  }' > "${WORKSPACE}/issue-context.json"

rm -f "${WORKSPACE}/issue.json" "${WORKSPACE}/repo.json" \
  "${WORKSPACE}/languages.json" "${WORKSPACE}/top-level.json" \
  "${WORKSPACE}/open-issues.json" "${WORKSPACE}/README.md"

echo "::notice::Pre-minimal-explore complete — context written to issue-context.json"
