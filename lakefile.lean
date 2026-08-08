import Lake
open Lake DSL

package «leanblog» where
  version := v!"0.1.0"
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩
  ]

-- Verso v4.32.0 is the last upstream snapshot aligned with the workspace toolchain.
require verso from git
  "https://github.com/leanprover/verso" @ "v4.32.0"

-- The CLI uses Argus for typed options, help, completions, and terminal diagnostics. Keep this
-- at the application boundary so the Markdown and theme libraries remain pure.
require argus from git
  "https://github.com/jonaprieto/lean-argus.git" @ "v0.4.8"

@[default_target]
lean_lib «LeanBlog» where
  srcDir := "src"
  globs := #[
    .one `LeanBlog,
    .one `LeanBlog.Links,
    .one `LeanBlog.Markdown,
    .one `LeanBlog.Theme
  ]

lean_lib «LeanBlog.Properties» where
  srcDir := "src"
  globs := #[.one `LeanBlog.Properties]

lean_exe «tests» where
  root := `Tests
  srcDir := "test"

lean_exe «readme» where
  root := `Readme
  srcDir := "test"

lean_exe «demo» where
  root := `Demo
  srcDir := "examples"

lean_exe «leanblog» where
  root := `LeanBlogCli
  srcDir := "cli"
