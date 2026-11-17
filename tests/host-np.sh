#!/bin/sh
# PC tests: Numpty Physics built from the same patched sources as the stove
# build (desktop OpenGL, SDL 2 with SDL2_image and SDL2_ttf, no GIO), played
# by tests/smoke.cpp under a virtual X display (xvfb-run, Mesa's software
# GL), then the user-data test and the Part file test.
# Exit 2 when the PC lacks what it needs (the reason is the last line).
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/numptyphysics.lock"
. "$HERE/scripts/np-common.sh"
WORK=${WORK:-$HOME/.cache/amiganumptyphysics/host}
CXX=${HOST_CXX:-c++}; CC=${HOST_CC:-cc}
command -v "$CXX" > /dev/null || { echo "no C++ compiler"; exit 2; }
command -v sdl2-config > /dev/null || { echo "no SDL 2 (sdl2-config)"; exit 2; }
for m in SDL2_image SDL2_ttf gl; do
    pkg-config --exists "$m" || { echo "no $m (pkg-config)"; exit 2; }
done
command -v xvfb-run > /dev/null || { echo "no xvfb-run"; exit 2; }
mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
np_source "$WORK"
S="$WORK/numptyphysics"
O="$WORK/obj"; mkdir -p "$O"
INC=""; for d in $NP_INCS; do INC="$INC -I$S/$d"; done
# shellcheck disable=SC2046
CF="-O1 -w $INC $(sdl2-config --cflags) $(pkg-config --cflags SDL2_image SDL2_ttf gl)"
DEFS=$(np_defs)
M="$O/Makefile"
{
    A=""
    for f in $(np_cxx_srcs "$S"); do
        o=$(echo "$f" | tr / _ | sed 's/\.cpp$/.o/'); A="$A $o"
        extra=""; [ "$f" = platform/sdl2/OsSDL2.cpp ] && extra="-Dmain=np_game_main"
        printf '%s: %s\n\t%s -std=c++11 %s %s %s -c $< -o $@\n' "$o" "$S/$f" "$CXX" "$CF" "$extra" "$DEFS"
    done
    for f in $(np_c_srcs "$S"); do
        o=$(echo "$f" | tr / _ | sed 's/\.c$/.o/'); A="$A $o"
        printf '%s: %s\n\t%s %s -c $< -o $@\n' "$o" "$S/$f" "$CC" "$CF"
    done
    echo "OBJS =$A"
    echo "all: \$(OBJS)"
} > "$M"
(cd "$O" && make -j"${JOBS:-8}" all > make.log 2>&1) || { grep -E 'error' "$O/make.log" | head -40; exit 1; }
# shellcheck disable=SC2046
"$CXX" -std=c++11 -O1 $(sdl2-config --cflags) -o "$WORK/np-smoke" "$HERE/tests/smoke.cpp" \
    $(cd "$O" && for f in $(sed -n 's/^OBJS =//p' Makefile); do echo "$O/$f"; done) \
    -Wl,--wrap=SDL_GL_SwapWindow $(pkg-config --libs SDL2_image SDL2_ttf gl) $(sdl2-config --libs) -lm
# the game finds data/ beside its program (OsFreeDesktop: the source checkout)
rm -f "$WORK/data"; ln -s "$S/data" "$WORK/data"
H="$WORK/home"; rm -rf "$H"; mkdir -p "$H"
(cd "$WORK" && HOME=$H SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 1024x768x24" ./np-smoke)
# the game made its user drawer under HOME (NP_NO_GIO: $HOME/.numptyphysics)
[ -d "$H/.numptyphysics" ] && echo "user data: HOME/.numptyphysics made: all checks passed" \
    || { echo "FAIL: no HOME/.numptyphysics"; exit 1; }
sh "$HERE/tests/test-part.sh"
