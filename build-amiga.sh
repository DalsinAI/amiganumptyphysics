#!/bin/sh
# Builds Numpty Physics, the crayon physics puzzle game, for GFOS (AmigaOS
# 3.2.3 with GFOpenUp) with a stove: a 68040 or 68060 with its FPU, drawn
# with OpenGL through GFOpenGPU (its GL and SDL 2 with SDL2_image and
# SDL2_ttf: the stove's link stubs, SDL2.module at run time), hard float as
# that kit is.
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
# Numpty Physics (with its bundled Box2D 2.0, tinyxml2 and glaserl) is
# fetched at the commit numptyphysics.lock gives; nothing third-party is kept
# here. The PC tests (tests/host-np.sh: the same game played by a timed mouse
# under a virtual X display, and unit tests) run first when the PC has a C++
# compiler, SDL 2 with SDL2_image and SDL2_ttf, GL and xvfb-run;
# HOST_TESTS=0 skips them.
# OUT gets Parts/NumptyPhysics: a GFOpenUp part (its Part file and the drawer
# it puts in SYS:Games/NumptyPhysics; it needs the GFOpenGPU part),
# installed with
#   GFOpenUpTool INSTALL Parts/NumptyPhysics
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/numptyphysics.lock"
. "$HERE/scripts/np-common.sh"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK="${WORK:-$HOME/.cache/amiganumptyphysics/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-8}
# the PC tests run on the PC's own PATH: the stove has an sdl2-config too (GFOS's)
HOST_PATH=$PATH
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)

# --- the PC tests first: the same sources, played by a timed mouse -------------
if [ "${HOST_TESTS:-1}" != 0 ] && (PATH=$HOST_PATH; command -v "${HOST_CXX:-c++}") > /dev/null 2>&1; then
    rc=0; PATH=$HOST_PATH WORK="$WORK/host" sh "$HERE/tests/host-np.sh" > "$WORK/host-tests.log" 2>&1 || rc=$?
    case $rc in
        0) grep -E "checks passed" "$WORK/host-tests.log" ;;
        2) echo "PC tests skipped: $(tail -1 "$WORK/host-tests.log")" ;;
        *) tail -30 "$WORK/host-tests.log"; exit 1 ;;
    esac
fi

# --- GL, SDL 2, SDL2_image and SDL2_ttf from the stove's SDK ------------------
SDK="$TC/m68k-amigaos"
for f in include/GL/gl.h include/GL/glext.h include/SDL2/SDL.h include/SDL2/SDL_image.h \
         include/SDL2/SDL_ttf.h lib/libGL.a lib/libSDL2.a lib/libSDL2_image.a lib/libSDL2_ttf.a; do
    [ -f "$SDK/$f" ] || { echo "the stove has no $f"; exit 2; }
done

# --- Numpty Physics at its pinned commit, patches/ -------------------------------
SRC="$WORK/src"
np_source "$SRC"
S="$SRC/numptyphysics"

# --- compile -------------------------------------------------------------------
LATE=""
if m68k-amigaos-gcc -fno-late-combine-instructions -S -o /dev/null -x c /dev/null 2>/dev/null; then LATE="-fno-late-combine-instructions"; fi
CPU="-m68040 -m68881"
INC=""; for d in $NP_INCS; do INC="$INC -I$S/$d"; done
# no loops turned into memset/memcpy calls (GCC 16), address 0 is memory
CF="-noixemul $CPU -O2 -fomit-frame-pointer -fno-tree-loop-distribute-patterns -fno-delete-null-pointer-checks $LATE \
 $INC -I$SDK/include/SDL2 -I$SDK/include"
DEFS=$(np_defs)
O="$WORK/obj"
# objects are remade when the sources or the flags change
STAMP="$(cat "$SRC/.patched") $( (echo "$CF $DEFS"; cat "$HERE/build-amiga.sh") | sha256sum | cut -c1-16)"
[ "$(cat "$O/.src" 2>/dev/null)" = "$STAMP" ] || { rm -rf "$O"; mkdir -p "$O"; echo "$STAMP" > "$O/.src"; }
M="$O/Makefile"
{
    echo "CF = $CF"
    A=""
    for f in $(np_cxx_srcs "$S"); do
        o=$(echo "$f" | tr / _ | sed 's/\.cpp$/.o/'); A="$A $o"
        extra=""; [ "$f" = platform/sdl2/OsSDL2.cpp ] && extra="-Dmain=np_game_main"
        printf '%s: %s\n\tm68k-amigaos-g++ -std=gnu++11 $(CF) %s %s -w -MMD -c $< -o $@\n' "$o" "$S/$f" "$extra" "$DEFS"
    done
    for f in $(np_c_srcs "$S"); do
        o=$(echo "$f" | tr / _ | sed 's/\.c$/.o/'); A="$A $o"
        printf '%s: %s\n\tm68k-amigaos-gcc -std=gnu99 $(CF) -w -MMD -c $< -o $@\n' "$o" "$S/$f"
    done
    A="$A amiga_start.o"
    printf 'amiga_start.o: %s\n\tm68k-amigaos-g++ -std=gnu++11 $(CF) -Wall -DNP_VERSION=\\"%s\\" -DNP_DATE=\\"%s\\" -MMD -c $< -o $@\n' \
        "$HERE/amiga/amiga_start.cpp" "$NP_VERSION" "$(date -u +%d.%m.%Y)"
    echo "OBJS =$A"
    echo "all: \$(OBJS)"
    echo "-include *.d"
} > "$M"
(cd "$O" && nice -n 19 make -k -j"$JOBS" all > make.log 2>&1) || { grep -E 'error:|\*\*\*' "$O/make.log" | sed 's#^.*/##' | sort | uniq -c | sort -rn | head -100; exit 1; }
echo "compile: $(( $(date +%s) - t0 )) s"

# --- link ------------------------------------------------------------------------
# -lpthread: the stove's libstdc++ and libgcc lock with its pthreads
# shellcheck disable=SC2046
m68k-amigaos-g++ -noixemul $CPU -o "$O/NumptyPhysics.debug" \
    $(cd "$O" && for f in $(sed -n 's/^OBJS =//p' Makefile); do echo "$O/$f"; done) \
    -L"$SDK/lib" -lSDL2_ttf -lSDL2_image -lSDL2 -lGL -lm -lpthread > "$O/link.log" 2>&1 || { grep -E 'undefined|error' "$O/link.log" | sed 's#^.*/##' | sort | uniq -c | sort -rn | head -60; exit 1; }

# --- the GFOpenUp part: Parts/NumptyPhysics ----------------------------------------
P="$OUT/Parts/NumptyPhysics"; D="$P/Games/NumptyPhysics"; rm -rf "$P"; mkdir -p "$D"
m68k-amigaos-strip -o "$D/NumptyPhysics" "$O/NumptyPhysics.debug"
cp -R "$S/data" "$D/data"
cp "$HERE/README.md" "$D/ReadMe"
cp "$S/COPYING" "$D/COPYING"
cp "$S/AUTHORS" "$D/AUTHORS"
sh "$HERE/scripts/write-part.sh" "$P" "$NP_VERSION"
ls -l "$D/NumptyPhysics"
echo "part: $(grep -c '^copy' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "total: $(( $(date +%s) - t0 )) s"
