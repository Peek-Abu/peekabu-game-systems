#!/bin/bash
rokit add rojo
rokit add wally
rokit add wally-package-types

rojo sourcemap
wally install
wally-package-types -s sourcemap.json Packages/

rojo build -o peekabu-game-systems.rbxl default.project.json