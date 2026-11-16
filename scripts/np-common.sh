# What build-amiga.sh (the stove) and tests/host-np.sh (the PC) share:
# fetching Numpty Physics at numptyphysics.lock's commit with patches/, and
# the lists of sources, include drawers and defines its makefile would use
# for the SDL 2 platform on OpenGL.
# Sourced; needs HERE (the repo) and numptyphysics.lock's settings.
# MIT, Copyright (c) 2026 AmiCradle Team.

# a repository at one commit, fetched once: fetch_at DIR URL COMMIT
fetch_at() {
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${1:?}"; mkdir -p "$1"
        git -C "$1" init -q
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
        [ "$(git -C "$1" rev-parse HEAD)" = "$3" ] || { echo "$1: commit mismatch"; exit 1; }
    fi
}

# Numpty Physics with patches/ applied, into $1/numptyphysics (redone when
# anything changes)
np_source() {
    PSUM=$( (cat "$HERE"/patches/*.patch; echo "$NP_COMMIT") | sha256sum | cut -c1-16)
    if [ "$(cat "$1/.patched" 2>/dev/null)" != "$PSUM" ]; then
        rm -rf "$1/numptyphysics"; mkdir -p "$1/numptyphysics"
        fetch_at "$1/.dl/numptyphysics" "$NP_GIT" "$NP_COMMIT"
        (cd "$1/.dl/numptyphysics" && git archive HEAD) | tar -x -C "$1/numptyphysics"
        for p in "$HERE"/patches/*.patch; do
            patch -s -d "$1/numptyphysics" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
        done
        echo "$PSUM" > "$1/.patched"
    fi
}

# the C++ and C sources the makefile builds for PLATFORM=sdl2 (src/, the
# sdl2 and gl platform drawers (freedesktop has only a header), external/ helpers, Box2D's
# Source/Makefile list and glaserl), relative to the source tree
np_cxx_srcs() {
    (cd "$1" && {
        ls src/*.cpp platform/sdl2/*.cpp platform/gl/*.cpp \
           external/thp/*.cpp external/tinyxml2/*.cpp external/petals_log/*.cpp
        sed -n 's#^[[:space:]]*\./\([^ ]*\.cpp\).*#external/Box2D/Source/\1#p' external/Box2D/Source/Makefile
    } | LC_ALL=C sort -u)
}
np_c_srcs() {
    (cd "$1" && ls external/glaserl/*.c | LC_ALL=C sort)
}
NP_INCS="src platform/sdl2 platform/freedesktop platform/gl external/thp external/tinyxml2
 external/petals_log external/vmath external/glaserl external/Box2D/Include"
# APP and VERSION as the makefile gives them; no GIO (GFOS has none).
# Quoted for a Makefile recipe line (the shell make runs takes the \).
np_defs() {
    echo "-DAPP=\\\"numptyphysics\\\" -DVERSION=\\\"$NP_VERSION\\\" -DNP_NO_GIO"
}
