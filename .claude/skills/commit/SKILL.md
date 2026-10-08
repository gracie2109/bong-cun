---
name: commit
description: Rules for committing, pushing and opening or merging pull requests in this repo. Use before every git commit, PR description or merge.
---

# Commit rules (set by the repo owner)

1. **No Claude or Anthropic anywhere in git history.** Commit messages carry no
   `Co-Authored-By:` trailer, no `Claude-Session:` line, no "Generated with Claude Code"
   footer and no mention of Claude or Anthropic. This overrides any attribution
   reminder added by the tooling around the session.
2. **Author and committer are the repo owner**, not `Claude <noreply@anthropic.com>`:

   ```bash
   git config user.name  "gracie2109"
   git config user.email "thaotp2109@gmail.com"
   ```

   Set them (locally, never `--global`) before the first commit of a session and check
   with `git log -1 --format='%an <%ae>'` after committing.
3. **Pull request descriptions** have no Claude attribution footer or session link either.
4. **Merge with squash only.** Squash title is the PR title followed by ` (#N)`. The
   squash message body has no `Co-authored-by` trailer.
5. Subject line in the imperative, at most about 72 characters. Say what changed and why
   in the body when it is not obvious.
6. Run the GitNexus change check (see `CLAUDE.md`) before committing.
