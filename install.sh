set -e
print_help() {
    echo "Usage:"
    echo "  -v, --verbose          Verbose output."
    echo "  -c, --clean            Force clean build, i.e. delete previously downloaded sources and start from scratch."
    echo "  -s, --stream=<stream>  Build a particular branch of Wayfire and other components. Usually master or a release like X.Y.Z"
    echo "                           Default is 0.4.0"
    echo "  -p, --prefix=<prefix>  Prefix where to install Wayfire. Default: /opt/wayfire"
    echo "  --system-wlroots       Use the system-wide installation of wlroots instead of the bundled one."
    exit 1
}


# Parse arguments
VERBOSE=0
CLEANBUILD=0
PREFIX=/opt/wayfire
STREAM=master
USE_SYSTEM_WLROOTS=disabled

# Temporarily disable exit on error
set +e
options=$(getopt -o hvcs:p: --long verbose --long clean --long stream: --long prefix: --long system-wlroots -- $@)
ERROR_CODE=$?
set -e

if [ $ERROR_CODE != 0 ]; then
    print_help
    exit 1
fi

eval set -- $options
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
            STREAM=$1
            ;;
        -p|--prefix)
            shift
            PREFIX=$1
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

if [ $VERBOSE = 1 ]; then
    set -x
fi

echo "Building Wayfire $STREAM"
echo "Installation prefix: $PREFIX"

BUILDROOT="$(cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
function ask_confirmation {
    while true; do
        read -p "$1" yn
        case $yn in
            [Yy]* ) yn=Y; break;;
            [Nn]* ) yn=N; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Usually we use sudo, but if prefix is somewhere in ~/, we don't need sudo
SUDO=sudo
if [ -w $PREFIX ] || ! which sudo > /dev/null; then
    SUDO=
fi

if [ ${USE_SYSTEM_WLROOTS} = disabled ] && [ $PREFIX = /usr ]; then
    ask_confirmation 'The installation of Wayfire may overwrite any system-wide wlroots installation. Continue[y/n]? '
    if [ ${yn} = N ]; then
        exit
    fi
fi

# First step, clone necessary repositories

# First argument: name of the repository to clone
check_download() {
    cd $BUILDROOT
    if [ ! -d $1 ] || [ $CLEANBUILD = 1 ]; then
        rm -rf $1
        git clone https://github.com/WayfireWM/$1
    fi

    # Checkout the correct stream
    cd $1
    git checkout origin/${STREAM}
}

check_download wayfire
check_download wf-shell

cd $BUILDROOT/wayfire

meson build --prefix=${PREFIX} -Duse_system_wfconfig=disabled -Duse_system_wlroots=${USE_SYSTEM_WLROOTS}
ninja -C build
$SUDO ninja -C build install
DEST_LIBDIR=$(meson configure | grep libdir | awk '{print $2}')

cd $BUILDROOT/wf-shell
PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${PREFIX}/${DEST_LIBDIR}/pkgconfig meson build --prefix=${PREFIX}
ninja -C build
$SUDO ninja -C build install

if ! pkg-config --exists libsystemd && ! pkg-config --exists libelogind && pkg-config --exists libcap; then
    $SUDO setcap cap_sys_admin=eip "$PREFIX/bin/wayfire"
fi

# Install a minimalistic, but still usable configuration
# First argument is the name of the file
# Second argument is the name of the template
function install_config {
    CONFIG_FILE=$BUILDROOT/$1
    cp $2 $CONFIG_FILE

    DEFAULT_CONFIG_PATH=${HOME}/.config/$1
    if [ "${XDG_CONFIG_HOME}" != "" ]; then
        DEFAULT_CONFIG_PATH=${XDG_CONFIG_HOME}/$1
    fi

    if [ -f ${DEFAULT_CONFIG_PATH} ]; then
        ask_confirmation "Do you want to override the existing config file ${DEFAULT_CONFIG_PATH} [y/n]? "
    else
        yn=Y
    fi

    if [ $yn = Y ]; then
        mkdir -p $(dirname ${DEFAULT_CONFIG_PATH})
        cp ${CONFIG_FILE} ${DEFAULT_CONFIG_PATH} --backup=t
    fi
}

install_config wayfire.ini $BUILDROOT/wayfire/wayfire.ini
install_config wf-shell.ini $BUILDROOT/wf-shell/wf-shell.ini.example

# Generate a startup script, setting necessary env vars.
cp $BUILDROOT/start_wayfire.sh.in $BUILDROOT/start_wayfire.sh
if [ ${PREFIX} != '/usr' ]; then
    sed -i "s@^LD_.*@export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${PREFIX}/${DEST_LIBDIR}@g" $BUILDROOT/start_wayfire.sh
    sed -i "s@^PATH.*@export PATH=\$PATH:${PREFIX}/bin@g" $BUILDROOT/start_wayfire.sh
fi
chmod 755 $BUILDROOT/start_wayfire.sh
$SUDO cp $BUILDROOT/start_wayfire.sh $PREFIX/bin/startwayfire

echo "Installation done. Run $PREFIX/bin/startwayfire to start wayfire."

ask_confirmation "Do you want to install WCM, a graphical configuration tool for Wayfire [y/n]? "
if [ $yn = Y ]; then
    check_download wcm
    cd $BUILDROOT/wcm
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${PREFIX}/${DEST_LIBDIR}/pkgconfig meson build --prefix=${PREFIX}
    ninja -C build
    $SUDO ninja -C build install
fi
