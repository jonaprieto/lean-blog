# LeanBlog theme

This is the first visual prototype for LeanBlog. It uses Tailwind CSS and daisyUI to produce a
static CSS artifact consumed by generated HTML. Playwright is included as a development
dependency for generated-site browser smoke tests.

```text
npm ci
npm run build:css
```

The theme keeps the class vocabulary in source files so Tailwind can discover every class during
the build. LeanBlog itself does not require Node.js at runtime.
