#! /bin/bash

# This script has been originally created by TheAssassin
# Minor modifications made by MrARM

# build in a temporary directory to make sure the files won't be re-used and will be cleaned up after build
BUILD_DIR=$(mktemp -d /tmp/mcp-build-XXXXX)
OLD_CWD=$(pwd)

function _cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

# install cleanup function as exit hook, i.e., before the script exits, the directory will be removed (even on build errors)
trap _cleanup EXIT

# make sure the script terminates if a command fails
set -e

# show commands which are run
set -x

# build MSA, then mcpelauncher, then mcpelauncher-ui

pushd "$BUILD_DIR"

# build MSA
git clone --recursive https://github.com/minecraft-linux/msa-manifest.git msa
pushd msa

mkdir build
pushd build
cmake .. -DENABLE_MSA_QT_UI=ON -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)  # build on all available cores

# use make install to have CMake install all the binaries and resources in the right place
# use DESTDIR to install into some different directory, not the system ones
# this way, a valid AppDir is created almost automatically by CMake, and we can just use linuxdeploy on it later
make install DESTDIR="$BUILD_DIR"/AppDir
popd

# go back into build dir
popd

# build mcpelauncher
git clone --recursive https://github.com/minecraft-linux/mcpelauncher-manifest.git mcpelauncher
pushd mcpelauncher

mkdir build
pushd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DUSE_OWN_CURL=ON -DOPENSSL_ROOT_DIR=/usr/lib/i386-linux-gnu/
make -j$(nproc)

make install DESTDIR="$BUILD_DIR"/AppDir
popd

# go back into build dir
popd

git clone --recursive https://github.com/minecraft-linux/mcpelauncher-ui-manifest.git ui
pushd ui

mkdir build
pushd build

cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DGAME_LAUNCHER_PATH=.
make -j $(nproc)

make install DESTDIR="$BUILD_DIR"/AppDir

popd

popd

# now, all apps required for the client are set up
# to be able to inspect the result of the script so far, we can copy the AppDir into the original working directory, as the temporary directory will be cleaned up
if [ -d "$OLD_CWD"/AppDir ]; then rm -rf "$OLD_CWD"/AppDir; fi
cp -R AppDir "$OLD_CWD"/

# additional resources

# convert the icon to 512x512
convert ui/mcpelauncher-ui-qt/Resources/proprietary/mcpelauncher-icon.png -resize 512x512 mcpelauncher-icon.png
# get the .desktop file
cp /home/paul/appimage/mcpelauncher.desktop mcpelauncher.desktop

# download linuxdeploy and make it executable
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage

# also download Qt plugin, which is needed for the Qt UI
wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage

chmod +x linuxdeploy*-x86_64.AppImage

export ARCH=x86_64

./linuxdeploy-x86_64.AppImage --appdir AppDir -i mcpelauncher-icon.png -d mcpelauncher.desktop

export QML_SOURCES_PATHS=ui/mcpelauncher-ui-qt/qml/
./linuxdeploy-plugin-qt-x86_64.AppImage --appdir AppDir

./linuxdeploy-x86_64.AppImage --appdir AppDir --output appimage

cp Minecraft_*.AppImage "$OLD_CWD"
