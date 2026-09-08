import Lake
open Lake DSL

package «leanblog» where
  version := v!"0.1.1"
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩
  ]

-- Verso v4.33.0 is compatible with the workspace Lean toolchain.
require verso from git
  "https://github.com/leanprover/verso" @ "v4.33.0"

@[default_target]
lean_lib «LeanBlog» where
  srcDir := "src"
  globs := #[
    .one `LeanBlog,
    .one `LeanBlog.Config,
    .one `LeanBlog.Icons,
    .one `LeanBlog.Links,
    .one `LeanBlog.Markdown,
    .one `LeanBlog.Theme
  ]

lean_lib «LeanBlog.Properties» where
  srcDir := "src"
  globs := #[.one `LeanBlog.Properties]

-- Export the public CLI as a small library so an initialized site can own its executable wrapper.
lean_lib «LeanBlog.Cli» where
  srcDir := "src"
  globs := #[.one `LeanBlog.Cli]

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
