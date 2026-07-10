# .fullsend

fullsend configuration for ascerra-fullsend-rehearsal.

## Custom agents

### minimal-explore

Lightweight GitHub exploration agent for rehearsing agent-pipeline changes.
Inspired by the [konflux-ci/refinement](https://github.com/konflux-ci/refinement)
explore agent, but stripped down to:

1. Fetch a GitHub issue (pre-script)
2. Inspect the target repo via the GitHub API (agent)
3. Post a short summary comment (post-script)

**Trigger (manual):**

```bash
gh workflow run minimal-explore.yml \
  --repo ascerra-fullsend-rehearsal/.fullsend \
  -f source_repo=ascerra-fullsend-rehearsal/fullsend \
  -f issue_number=1 \
  -f dry_run=false
```

Or: Actions → Minimal Explore → Run workflow.

Use `dry_run=true` to exercise the agent without posting an issue comment.
