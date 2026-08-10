# Contributing

LeanBlog is designed to build with public dependencies and standard GitHub Actions.

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
