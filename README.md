# Numpty Physics for GFOS

Numpty Physics is a drawing puzzle game: whatever you draw with the mouse
becomes a solid thing that falls, rolls and swings under real physics
(Box2D). Draw ramps, levers and ropes to get the red token to the yellow
star. It comes with 112 levels, a tutorial among them, and an editor for your own.

This repository builds it for GFOS (AmigaOS 3.2.3 with GFOpenUp) as a
GFOpenUp part. Nothing third-party is kept here: the build fetches Numpty
Physics at the commit `numptyphysics.lock` names and applies `patches/`.

## Playing

Install the part and start `SYS:Games/NumptyPhysics/NumptyPhysics` from
Workbench or the Shell. It needs a 68040 or 68060 with its FPU and the
GFOpenGPU part, which draws the game through OpenGL and SDL 2.

| Mouse or key | What it does |
| --- | --- |
| Left button, drag | Draw a stroke (it comes alive when you let go) |
| Space, Return | Pause or go on |
| Esc, Backspace, U, Down | Undo the last stroke |
| R, Up | Start the level again |
| N, Right / P, Left | Next / previous level |
| E, F6 | Edit the level |
| S | Save the level |
| M | Menu |
| Q | Quit |

The game reads its levels and fonts from `PROGDIR:data` and keeps the levels
you save and the levels you have solved in `PROGDIR:UserData`, so it runs
the same from any Shell directory. Menus and help come in English (German,
Italian and Russian texts are in `data/i18n`).

## What the patches do

* `0001-userdata-without-gio.patch`: the user drawer without GLib's GIO
  (`NP_NO_GIO`; GFOS has no GLib): `PROGDIR:UserData` on GFOS,
  `$HOME/.numptyphysics` elsewhere.
* `0002-amiga-program-drawer.patch`: on GFOS the program's drawer is
  `PROGDIR:` (argv[0] may have no path when started from Workbench), the
  data drawer is `PROGDIR:data` and the language is English.

* `0003-format-without-vasprintf.patch`: thp::format sizes its text with
  `vsnprintf` instead of `vasprintf`, a GNU and BSD call that libnix does not
  have (on every platform, so the PC tests run the same code).

`amiga/amiga_start.c` sets the stack and the `$VER` string and calls the
game's own SDL 2 `main()`, built as `np_game_main`.

## Building

    STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh

The output is `out/Parts/NumptyPhysics` (the Part file, the program, data,
the licence and authors), installed with

    GFOpenUpTool INSTALL Parts/NumptyPhysics

## Tests

`tests/host-np.sh` builds the same patched sources on the PC (desktop
OpenGL, SDL 2, SDL2_image, SDL2_ttf) and runs `tests/smoke.cpp`: the real
game under a virtual X display, where a timer captures the title level,
draws a stroke across it with the mouse, captures again and quits. It
checks the frames, that the title is drawn and that the stroke changed the
scene, then that the user drawer was made, and runs the Part file test
(`tests/test-part.sh`). `build-amiga.sh` runs them first when the PC has
what they need.

## Licences

Numpty Physics is GPL-3 (`COPYING` in the part, with `AUTHORS`); its levels
and fonts carry the licences the upstream `data/` gives. The scripts, tests
and start code here are MIT, Copyright (c) 2026 AmiCradle Team.

Designed, tested and delivered by The AmiCradle Team.
