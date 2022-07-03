#!/bin/bash

echo "------------------------"
echo "---Removing old Files---"
echo "------------------------"

rm -rf ./minetest
rm -rf ./minetest_game

echo "-----------------------"
echo "---Cloning Minetest---"
echo "-----------------------"

git clone --depth 1 https://github.com/minetest/minetest.git


echo "----------------------------"
echo "---Cloning Minetest Game---"
echo "----------------------------"

git clone --depth 1 https://github.com/minetest/minetest_game.git && ln -s ./minetest_game ./minetest/games/minetest_game

echo "-------------------------"
echo "---Cloning IrrlichtMt---"
echo "-------------------------"

git clone --depth 1 https://github.com/minetest/irrlicht.git ./minetest/lib/irrlichtmt && cd ./minetest

echo "-----------------------"
echo "---Building Minetest---"
echo "-----------------------"

cmake . -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=TRUE -DBUILD_CLIENT=FALSE -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

echo "----------------------------"
echo "---Linking mods directory---"
echo "----------------------------"

rm -rf ./minetest/mods

echo "Link mods folder"

#ln -s ./mods ./minetest/mods