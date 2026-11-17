/* PC smoke test: the real game (its SDL 2 main built as np_game_main) on
 * OpenGL under a virtual X display. An SDL timer plays it: the title level
 * is captured, a stroke is drawn across it with the mouse (it becomes a
 * physics body that falls), the scene is captured again, and the game is
 * told to quit. SDL_GL_SwapWindow is wrapped (-Wl,--wrap) to count frames
 * and read back the pixels of the two captures.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <SDL.h>
#include <GL/gl.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>
#include <vector>

int np_game_main(int argc, char **argv);
extern "C" void __real_SDL_GL_SwapWindow(SDL_Window *w);

static int frames, want_capture;
static int colours[2];
static unsigned long sums[2];
static int captures;

static void capture(SDL_Window *w)
{
    int ww, hh;
    SDL_GL_GetDrawableSize(w, &ww, &hh);
    std::vector<unsigned char> px((size_t)ww * hh * 4);
    glReadPixels(0, 0, ww, hh, GL_RGBA, GL_UNSIGNED_BYTE, px.data());
    std::set<unsigned> seen;
    unsigned long sum = 0;
    for (size_t i = 0; i < px.size(); i += 4) {
        unsigned c = px[i] << 16 | px[i + 1] << 8 | px[i + 2];
        seen.insert(c);
        sum = sum * 31 + c;
    }
    colours[captures] = (int)seen.size();
    sums[captures] = sum;
    captures++;
}

extern "C" void __wrap_SDL_GL_SwapWindow(SDL_Window *w)
{
    frames++;
    if (want_capture && captures < 2) {
        want_capture = 0;
        capture(w);
    }
    __real_SDL_GL_SwapWindow(w);
}

static void push_mouse(Uint32 type, int x, int y)
{
    SDL_Event e;
    memset(&e, 0, sizeof e);
    e.type = type;
    if (type == SDL_MOUSEMOTION) {
        e.motion.x = x; e.motion.y = y; e.motion.state = SDL_BUTTON_LMASK;
        e.motion.windowID = 1;
    } else {
        e.button.x = x; e.button.y = y; e.button.button = SDL_BUTTON_LEFT;
        e.button.state = type == SDL_MOUSEBUTTONDOWN ? SDL_PRESSED : SDL_RELEASED;
        e.button.windowID = 1;
    }
    SDL_PushEvent(&e);
}

static int step;
static Uint32 play(Uint32, void *)
{
    step++;
    if (step == 30) want_capture = 1;                  /* 1.5 s: the title */
    if (step == 40) push_mouse(SDL_MOUSEBUTTONDOWN, 200, 100);
    if (step > 40 && step < 60) push_mouse(SDL_MOUSEMOTION, 200 + (step - 40) * 15, 100);
    if (step == 60) push_mouse(SDL_MOUSEBUTTONUP, 500, 100);
    if (step == 100) want_capture = 1;                 /* 2 s on: stroke fallen */
    if (step == 110) {
        SDL_Event e; memset(&e, 0, sizeof e); e.type = SDL_QUIT; SDL_PushEvent(&e);
    }
    return step < 400 ? 50 : 0;
}

int main(int argc, char **argv)
{
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER);
    SDL_AddTimer(50, play, NULL);
    int rc = np_game_main(argc, argv);
    int fail = 0;
    printf("smoke: %d frames, %d captures; title %d colours, after stroke %d\n",
           frames, captures, colours[0], colours[1]);
    if (rc != 0) { printf("FAIL: game returned %d\n", rc); fail = 1; }
    if (step >= 400) { printf("FAIL: the game did not quit\n"); fail = 1; }
    if (frames < 20) { printf("FAIL: too few frames\n"); fail = 1; }
    if (captures != 2) { printf("FAIL: captures\n"); fail = 1; }
    if (colours[0] < 8) { printf("FAIL: title frame looks empty\n"); fail = 1; }
    if (captures == 2 && sums[0] == sums[1]) { printf("FAIL: the stroke changed nothing\n"); fail = 1; }
    if (!fail) printf("smoke: all checks passed\n");
    return fail;
}
