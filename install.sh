#!/usr/bin/env bash
set -e
print_help() {
    echo "Usage:"
    echo "  -v, --verbose          Verbose output."
    echo "  -c, --clean            Force clean build, i.e. delete previously downloaded sources and start from scratch."
    echo "  -s, --stream=<stream>  Build a particular branch of Wayfire and other components. Usually master or a release like X.Y.Z"
    echo "                           Default is master"
    echo "  -p, --prefix=<prefix>  Prefix where to install Wayfire. Default: /opt/wayfire"
    echo "  --system-wlroots       Use the system-wide installation of wlroots instead of the bundled one."
    echo "  -o, --optimize	   Enables build optimizations."
    echo "  -d, --debug		   Enables debug build."
    exit 1
}


# Parse arguments
VERBOSE=0
CLEANBUILD=0
PREFIX=/opt/wayfire
STREAM=master
USE_SYSTEM_WLROOTS=disabled
BUILDPARAMS="-Dbuildtype=debugoptimized"

# Temporarily disable exit on error
set +e
options="$(getopt -o hvcs:p:do --long verbose --long clean --long stream: --long prefix: --long system-wlroots --long debug --long optimize -- "$@")"
ERROR_CODE="$?"
set -e

if [ "$ERROR_CODE" != 0 ]; then
    print_help
    exit 1
fi

eval set -- "$options"
while true; do
    case $1 in
        -v|--verbose)
            VERBOSE=1
            ;;
        -c|--clean)
            CLEANBUILD=1
            ;;
        -s|--stream)
            shift
            STREAM="$1"
            ;;
        -p|--prefix)
            shift
            PREFIX="$1"
            ;;
    	-d|--debug)
	    BUILDPARAMS="-Dbuildtype=debug -Db_sanitize=address,undefined"
	    ;;
	-o|--optimize)
	    BUILDPARAMS="-Dbuildtype=release -Db_lto=true"
	    ;;
        --system-wlroots)
            USE_SYSTEM_WLROOTS=enabled
            ;;
        -h|--help)
            print_help
            exit;;
        --)
            shift
            break;;
    esac
    shift
done

if [ "$VERBOSE" = 1 ]; then
    set -x
fi

echo "Building Wayfire $STREAM"
echo "Installation prefix: $PREFIX"

BUILDROOT="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
function ask_confirmation {
    while true; do
        read -p "$1" yn
        case "$yn" in
            [Yy]* ) yn=Y; break;;
            [Nn]* ) yn=N; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Check if we have doas, if we do, use it instead of sudo.
if [[ -n "$(command -v doas)" ]]; then
	SUDO=doas
else
	SUDO=sudo
fi

# Usually we use sudo, but if prefix is somewhere in ~/, we don't need sudo
if [ -w "$PREFIX" ] || ! which sudo > /dev/null; then
    SUDO=
fi

if [ "${USE_SYSTEM_WLROOTS}" = disabled ] && [ "$PREFIX" = /usr ]; then
    ask_confirmation 'The installation of Wayfire may overwrite any system-wide wlroots installation. Continue[y/n]? '
    if [ "${yn}" = N ]; then
        exit
    fi
fi

# First step, clone necessary repositories

# First argument: name of the repository to clone
check_download() {
    cd "$BUILDROOT"
    if [ ! -d "$1" ] || [ "$CLEANBUILD" = 1 ]; then
        rm -rf "$1"
        git clone "https://github.com/WayfireWM/$1"
    fi

    # Checkout the correct stream
    cd "$1"
    git checkout "origin/${STREAM}"
}

check_download wayfire
check_download wf-shell

cd "$BUILDROOT/wayfire"

meson build --prefix="${PREFIX}" $BUILDPARAMS -Duse_system_wfconfig=disabled -Duse_system_wlroots="${USE_SYSTEM_WLROOTS}"
ninja -C build
$SUDO ninja -C build install
DEST_LIBDIR="$(meson configure | grep "\<libdir\>" | awk '{print $2}')"

cd "$BUILDROOT/wf-shell"
PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${PREFIX}/${DEST_LIBDIR}/pkgconfig" meson build --prefix="${PREFIX}" $BUILDPARAMS
ninja -C build
$SUDO ninja -C build install

if ! pkg-config --exists libsystemd && ! pkg-config --exists libelogind && pkg-config --exists libcap; then
    $SUDO setcap cap_sys_admin=eip "$PREFIX/bin/wayfire"
fi

# Install a minimalistic, but still usable configuration
# First argument is the name of the file
# Second argument is the name of the template
function install_config {
    CONFIG_FILE="$BUILDROOT/$1"
    cp "$2" "$CONFIG_FILE"

    DEFAULT_CONFIG_PATH="${HOME}/.config/$1"
    if [ "${XDG_CONFIG_HOME}" != "" ]; then
        DEFAULT_CONFIG_PATH="${XDG_CONFIG_HOME}/$1"
    fi

    if [ -f "${DEFAULT_CONFIG_PATH}" ]; then
        ask_confirmation "Do you want to override the existing config file ${DEFAULT_CONFIG_PATH} [y/n]? "
    else
        yn=Y
    fi

    if [ "$yn" = Y ]; then
        mkdir -p "$(dirname "${DEFAULT_CONFIG_PATH}")"
        cp "${CONFIG_FILE}" "${DEFAULT_CONFIG_PATH}" --backup=t
    fi
}

install_config wayfire.ini "$BUILDROOT/wayfire/wayfire.ini"
install_config wf-shell.ini "$BUILDROOT/wf-shell/wf-shell.ini.example"

# Generate a startup script, setting necessary env vars.
cp "$BUILDROOT/start_wayfire.sh.in" "$BUILDROOT/start_wayfire.sh"
if [ "${PREFIX}" != '/usr' ]; then
    sed -i "s@^LD_.*@export LD_LIBRARY_PATH=${PREFIX}/${DEST_LIBDIR}:\$LD_LIBRARY_PATH@g" "$BUILDROOT/start_wayfire.sh"
    sed -i "s@^PATH.*@export PATH=${PREFIX}/bin:\$PATH@g" "$BUILDROOT/start_wayfire.sh"
    sed -i "s@^XDG_.*@export XDG_DATA_DIRS=${PREFIX}/share:\$XDG_DATA_DIRS@g" "$BUILDROOT/start_wayfire.sh"
fi
$SUDO install -m 755 "$BUILDROOT/start_wayfire.sh" "$PREFIX/bin/startwayfire"

ask_confirmation "Do you want to install wayfire-plugins-extra? [y/n]? "
if [ "$yn" = Y ]; then
    check_download wayfire-plugins-extra
    cd "$BUILDROOT/wayfire-plugins-extra"
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${PREFIX}/${DEST_LIBDIR}/pkgconfig" meson setup build --prefix="${PREFIX}" $BUILDPARAMS
    ninja -C build
    $SUDO ninja -C build install
fi

ask_confirmation "Do you want to install WCM, a graphical configuration tool for Wayfire [y/n]? "
if [ "$yn" = Y ]; then
    check_download wcm
    cd "$BUILDROOT/wcm"
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${PREFIX}/${DEST_LIBDIR}/pkgconfig" meson setup build --prefix="${PREFIX}" $BUILDPARAMS
    ninja -C build
    $SUDO ninja -C build install
fi

SESSIONS_DIR=/usr/share/wayland-sessions/
SUDO_FOR_SESSIONS=sudo
if [ -w $SESSIONS_DIR ] || ! which sudo > /dev/null; then
  SUDO_FOR_SESSIONS=
fi
ask_confirmation "Do you want to install wayfire.desktop to $SESSIONS_DIR/ [y/n]? "
if [ "$yn" = Y ]; then
    cp "$BUILDROOT/wayfire.desktop.in" "$BUILDROOT/wayfire.desktop"
    sed -i "s@^Exec.*@Exec=$PREFIX/bin/startwayfire@g" "$BUILDROOT/wayfire.desktop"
    sed -i "s@^Icon.*@Icon=$PREFIX/share/wayfire/icons/wayfire.png@g" "$BUILDROOT/wayfire.desktop"
    $SUDO_FOR_SESSIONS mkdir -p "$SESSIONS_DIR"
    $SUDO_FOR_SESSIONS install -m 644 "$BUILDROOT/wayfire.desktop" "$SESSIONS_DIR"
fi

echo "Installation done. Run $PREFIX/bin/startwayfire to start wayfire."
