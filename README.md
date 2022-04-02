# zecsi example

this is a small example utilizing my work-in-progress game framework [zecsi](https://github.com/ryupold/zecsi)

The project is in an early experimental state.

## USE

The main entry point is in src/game.zig.
Here you can setup your systems which essentially hold all the logic.
See the example `TreeSystem` for details on how to use the framework.

### Assets
All assets are placed in the `assets` folder and referenced in systems via `assets/...`.

## BUILD

### dependencies
- git
- zig
- [emscripten sdk](https://emscripten.org/)

```
git clone --recurse-submodules https://github.com/ryupold/zecsi-example
```

### run locally

```sh
zig build run
```

### build for host os and architecture

```sh
zig build -Drelease-small
```

The output files will be in `./zig-out/bin`

### html5 / emscripten

```sh
EMSDK=../emsdk #path to emscripten sdk

zig build -Drelease-small -Dtarget=wasm32-wasi --sysroot $EMSDK/upstream/emscripten/
```

The output files will be in `./zig-out/web/`

- game.html (entry point)
- game.js
- game.wasm
- game.data

The game data needs to be served with a webserver. Just opening the game.html in a browser won't work

You can utilize python as local http server:
```sh
python -m http.server
```
