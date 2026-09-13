# Contributing to AI Talking Head Pipeline

Issues and PRs are welcome.

## Proposing Changes

1. **Fork** the repository on GitHub.
2. **Create a branch** for your change:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**, then **push** to your fork.
4. **Open a pull request** to `main`.

## PR Guidelines

Describe what changed and why:

- For fixes: explain the issue and how the fix addresses it.
- For features: explain the use case and how the change adds value.
- For design-system updates: keep typography, spacing, and color harmony consistent with `public/index.html`.

## What to Know About This Project

- No build step or test suite. `npx hyperframes check public` lints the composition, and visual verification happens via screenshot or render.
- The design system lives in `public/index.html`. All CSS, typography, colors, and component markup are in one file.
- The GSAP timeline sits in the trailing `<script>` block. Motion timing and easing logic is inline, not in an external file.
- Hedra API calls go through Bash. `generate-hedra-video.sh` uses `curl` and `jq`. If you modify it, test against Hedra's `/v3/` endpoints (see the script comments for details).

## Questions?

Open an issue first to discuss larger changes before investing time in a PR.
