#!/bin/sh

set -e
set -o xtrace

BUILDROOT=$1
STREAM=$2
if [ "$STREAM" = "" ]; then
    STREAM=master
fi

# First argument is the name of the component
build_component() {
if [ ! -d $BUILDROOT/$1 ]; then
    echo "Component $1 not found, skipping ..."
    return
fi
cd $BUILDROOT/$1
git fetch origin
git checkout origin/${STREAM}
git submodule update --init
ninja -C build
sudo ninja -C build install
}

build_component wayfire
build_component wf-shell
build_component wcm
