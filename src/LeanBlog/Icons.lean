/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Verso.Output.Html

/-!
# LeanBlog icons

The SVG paths are from Heroicons, used under its MIT license. Keeping the small set of icons inline
means generated sites have no icon package or network dependency at runtime.
-/

namespace LeanBlog

open Verso Output Html

/-- The Heroicons used by the default LeanBlog theme. -/
inductive Icon where
  /-- Share the current page. -/
  | share
  /-- Open the page actions menu. -/
  | ellipsisHorizontal
  /-- Copy a code block. -/
  | clipboardDocument
  /-- Show raw source code. -/
  | codeBracket
  /-- Print the current page. -/
  | printer
  /-- Use the light theme. -/
  | sun
  /-- Use the dark theme. -/
  | moon
deriving Repr, BEq

private def pathElement (d : String) : Html :=
  Html.tag "path" #[
    ("stroke-linecap", "round"),
    ("stroke-linejoin", "round"),
    ("d", d)
  ] Html.empty

private def path : Icon → Html
  | .share => pathElement <|
      "M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186 " ++
      "c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 " ++
      "9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 " ++
      "3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 " ++
      "0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
  | .ellipsisHorizontal => pathElement <|
      "M6.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM12.75 12 " ++
      "a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM18.75 12a.75.75 0 1 1-1.5 " ++
      "0 .75.75 0 0 1 1.5 0Z"
  | .clipboardDocument => pathElement <|
      "M8.25 7.5V6.108c0-1.135.845-2.098 1.976-2.192.373-.03 " ++
      ".748-.057 1.123-.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25 " ++
      "V6.108c0-1.081-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08 " ++
      "M15.75 18.75v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5 " ++
      "a1.125 1.125 0 0 1-1.125-1.125v-1.5A3.375 3.375 0 0 0 6.375 7.5H5.25 " ++
      "m11.9-3.664A2.251 2.251 0 0 0 15 2.25h-1.5a2.251 2.251 0 0 0-2.15 " ++
      "1.586m5.8 0c.065.21.1.433.1.664v.75h-6V4.5c0-.231.035-.454.1-.664 " ++
      "M6.75 7.5H4.875c-.621 0-1.125.504-1.125 1.125v12c0 .621.504 1.125 " ++
      "1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V16.5a9 9 0 0 0-9-9Z"
  | .codeBracket => pathElement <|
      "M17.25 6.75 22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25 " ++
      "m7.5-3-4.5 16.5"
  | .printer => pathElement <|
      "M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0 1 " ++
      "10.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096 " ++
      "L17.66 18m0 0 .229 2.523a1.125 1.125 0 0 1-1.12 1.227H7.231 " ++
      "c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0 0 " ++
      "21 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 0 0 " ++
      "-1.913-.247M6.34 18H5.25A2.25 2.25 0 0 1 3 15.75V9.456 " ++
      "c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 0 1 1.913-.247m10.5 " ++
      "0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 " ++
      "1.125v3.659M18 10.5h.008v.008H18V10.5Zm-3 0h.008v.008H15V10.5Z"
  | .sun => pathElement <|
      "M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591 " ++
      "M12 18.75V21m-4.773-2.318-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636 " ++
      "M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"
  | .moon => pathElement <|
      "M21.752 15.002A9.718 9.718 0 0 1 18 15.75 9.75 9.75 0 0 1 8.25 6 " ++
      "c0-1.33.266-2.598.748-3.752A9.753 9.753 0 1 0 21.752 15.002Z"

/-- Render an inline Heroicon with a caller-provided CSS class. -/
def Icon.toHtml (icon : Icon) (classes : String := "leanblog-icon") : Html :=
  {{<svg class={{classes}} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"
    stroke-width="1.5" stroke="currentColor" aria-hidden="true" data-slot="icon">
    {{path icon}}
  </svg>}}

end LeanBlog
