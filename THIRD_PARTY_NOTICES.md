# Third-party notices

LeanBlog currently depends on the following projects through Lake:

- Verso — Apache-2.0 — <https://github.com/leanprover/verso>
- SubVerso — Apache-2.0 — <https://github.com/leanprover/subverso>
- MD4Lean — MIT — <https://github.com/acmepjz/md4lean>
- Plausible — Apache-2.0 — <https://github.com/leanprover-community/plausible>
- Illuminate — MIT — <https://github.com/leanprover/illuminate>

The exact dependency revisions are recorded in `lake-manifest.json`. Dependencies that are not
imported by the LeanBlog foundation are retained here because they are part of the resolved Verso
package closure; this list must be revisited when the dependency boundary is reduced.

The first visual prototype also uses Tailwind CSS and daisyUI through the locked dependencies in
`theme/package-lock.json`. Their exact package metadata and licenses must be checked again at each
theme dependency update.
