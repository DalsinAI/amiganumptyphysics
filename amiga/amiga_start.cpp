/* Numpty Physics on GFOS: the stack and the $VER string; the game's own
 * main() (platform/sdl2/OsSDL2.cpp) is built as np_game_main, a C++
 * function (so this file is C++ too). The game
 * finds its data in PROGDIR:data and keeps levels you save and your
 * progress in PROGDIR:UserData (patches/0002, 0001), wherever the Shell is.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
extern "C" { unsigned long __stack = 256 * 1024; }
static const char version[] __attribute__((used)) =
	"$VER: NumptyPhysics " NP_VERSION " (" NP_DATE ") GFOS";

int np_game_main(int argc, char **argv);

int main(int argc, char **argv)
{
	return np_game_main(argc, argv);
}
