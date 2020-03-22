#!/bin/sh

set -e
set -o xtrace

BUILDROOT=$(realpath $1)
STREAM=$2
if [ "$STREAM" = "" ]; then
    STREAM=master
fi

# First argument is the name of the component
build_component() {
    SUDO=sudo
    if [ ! -d $BUILDROOT/$1 ]; then
        echo "Component $1 not found, skipping ..."
        return
    else
        PREFIX=$(meson configure ./build | grep "Installation prefix" | awk '{print $2}')
        if [ -w $PREFIX ]; then
            SUDO=
        fi
    fi

    cd $BUILDROOT/$1
    git fetch origin
    git checkout origin/${STREAM}
    git submodule update --init
    ninja -C build
    $SUDO ninja -C build install
}

build_component wayfire
build_component wf-shell
build_component wcm
