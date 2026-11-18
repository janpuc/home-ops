---
name: review-focus
description: How far a review of this repository goes. Every question the review chases starts from a changed line, the checkout answers questions about this repository, and the review submits once the change's questions are answered. Given whole to every review.
---

# Stay on the change

A review here runs on a step and token budget, and every step sends the
whole conversation again. A step spent off the change makes every later
step dearer and leaves less for the change itself.

- Work from the diff. Each command answers a question a changed line
  raises: what changed upstream, what here depends on it, whether the
  values still fit. A question no changed line raises is not the review's.
- This repository is checked out. Read it with `read_file`, `grep` and
  `list_files`, not through the GitHub API. The pull request's title,
  body, labels and diff are in the prompt, so `gh pr view` on it adds
  nothing.
- Upstream, read the releases, the pull requests they cite and the source
  at the two versions. Search a large upstream repository's code
  (`gh search code`, `search/code`) only for a name that a release note or
  a diff gives you, never to explore.
- Binaries and checksums for platforms nothing here runs on, such as
  Windows, are not the review's.
- Run a command once. When it fails or comes back empty, say so and move
  on: change the question, not the flags.
- Submit when every question the change raises has an answer or a stated
  reason it has none. Running out of new questions is the signal to
  submit, not running out of budget. What could not be verified goes in
  the take as a check to do after the merge.
