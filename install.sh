set -e
set -o xtrace

BUILDROOT=$(pwd)

PREFIX=/opt/wayfire
#STREAM=0.4.0 # or master
STREAM=master
USE_SYSTEM_WLROOTS=disabled

function ask_confirmation {
    while true; do
        set +e
        read -p "$1" yn
        set -e
        case $yn in
            [Yy]* ) yn=Y; break;;
            [Nn]* ) yn=N; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

if [ ${USE_SYSTEM_WLROOTS} = disabled ] & [ $PREFIX = /usr ]; then
    ask_confirmation 'The installation of Wayfire may overwrite any system-wide wlroots installation. Continue[y/n]? '
    if [ ${yn} = N ]; then
        exit
    fi
fi

# First step, clone necessary repositories

#rm -rf $BUILDROOT/wayfire $BUILDROOT/wf-shell
#git clone https://github.com/WayfireWM/wayfire
#git clone https://github.com/WayfireWM/wf-shell

cd $BUILDROOT/wayfire
git checkout ${STREAM}

meson build --prefix=${PREFIX} -Duse_system_wfconfig=disabled -Duse_system_wlroots=${USE_SYSTEM_WLROOTS}
ninja -C build
sudo ninja -C build install

cd $BUILDROOT/wf-shell
PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PREFIX}/lib/x86_64-linux-gnu meson build --prefix=${PREFIX}
ninja -C build
sudo ninja -C build install

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
        ask_confirmation "Do you want to override the existing config file ${DEFAULT_CONFIG_PATH}?"
        # Create a backup if overwriting
        if [ $yn = Y ]; then
            cp ${DEFAULT_CONFIG_PATH} ${DEFAULT_CONFIG_PATH}.back
        fi
    else
        yn=Y
    fi

    if [ $yn = Y ]; then
        cp ${CONFIG_FILE} ${DEFAULT_CONFIG_PATH}
    fi
}

install_config wayfire.ini $BUILDROOT/wayfire/wayfire.ini
install_config wf-shell.ini $BUILDROOT/wf-shell/wf-shell.ini.example

# Generate a startup script, setting necessary env vars.
cp $BUILDROOT/start_wayfire.sh.in $BUILDROOT/start_wayfire.sh
if [ ${PREFIX} != '/usr' ]; then
    sed -i "s@^LD_.*@LD_LIBRARY_PATH = \$LD_LIBRARY_PATH:${PREFIX}/lib:${PREFIX}/lib64:${PREFIX}/lib/x86_64-linux-gnu@g" $BUILDROOT/start_wayfire.sh
    sed -i "s@^PATH.*@PATH = \$PATH:${PREFIX}/bin@g" $BUILDROOT/start_wayfire.sh
fi
chmod 755 $BUILDROOT/start_wayfire.sh

echo "Installation done. You can put start_wayfire.sh in your PATH and use it to start Wayfire."
