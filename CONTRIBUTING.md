# Contributing

LeanBlog is a private repository. Contributors need GitHub read access to this repository and to
the private `precommit-lean` repository used by CI.

## Local checks

```text
lake build LeanBlog LeanBlog.Properties tests readme demo leanblog
./.lake/build/bin/tests
npm ci --prefix theme
npm run build:css --prefix theme
./.lake/build/bin/leanblog init .lake/build/init-test
./.lake/build/bin/leanblog check examples/posts/starter.lean.md --targets examples/targets.tsv
./.lake/build/bin/leanblog build examples/posts/starter.lean.md --targets examples/targets.tsv
pre-commit run --all-files
```

The LeanBlog foundation uses the public Verso dependency pinned in `lake-manifest.json`. The theme
uses the locked npm dependencies in `theme/package-lock.json`.

## CI access

CI requires a fine-grained GitHub token stored as the repository secret
`ECOSYSTEM_READ_TOKEN`. It needs `Contents: read` access to `precommit-lean` and any other private
ecosystem dependency added later.

Set it from an environment variable or file; never put the token in a command line, commit, issue,
or workflow file:

```text
gh secret set ECOSYSTEM_READ_TOKEN --repo jonaprieto/lean-blog < token.txt
gh secret list --repo jonaprieto/lean-blog
```

The second command lists names only.
