# Tests (not part of the addon)

A simulator of the WoW API (`wow_mock.lua`) and a scenario script (`run.lua`). Needs `texlua` (or Lua 5.3+).

- One run: `texlua tests/run.lua frFR 1 1 .` (locale, DialogueUI 0/1, Spoken 0/1, addon folder)
- Everything: `sh tests/run_all.sh` (352 runs)

`tools/` holds the Python scripts that generated the theme textures and previews. Neither folder is shipped in the release zip.
