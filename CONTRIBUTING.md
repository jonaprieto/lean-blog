# Contributing

All contributions are welcome and will be considered when they are reasonably scoped for review:
short, focused, appropriate to the library, and solving a real problem.

AI-assisted work is welcome. What matters is clear ownership, purpose, and effort from the
contributor. AI will increasingly be part of software development; the goal here is to use it
responsibly to grow and improve the Lean 4 ecosystem.

This work is maintained in my spare time, so reviews and responses may take time.

Everything can improve incrementally. Useful forms of collaboration include focused pull requests,
well-documented issues, bug reports, examples, documentation improvements, and design discussion.

## Local checks

```text
lake build LeanBlog LeanBlog.Properties tests readme demo leanblog
lake build :literateHtml
./.lake/build/bin/tests
npm ci --prefix theme
npm run build:css --prefix theme
./.lake/build/bin/leanblog init .lake/build/init-test
./.lake/build/bin/leanblog check site/posts
./.lake/build/bin/leanblog build site/posts
pre-commit run --all-files
```

The LeanBlog foundation uses the public Verso dependency pinned in `lake-manifest.json`. The theme
uses the locked npm dependencies in `theme/package-lock.json`. CI uses the public
`pre-commit/action` and the repository's local Lean source checks; no repository secret is required
to build or deploy the template.
