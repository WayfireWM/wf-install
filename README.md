# wf-install
This contains an install script called `install.sh`. It is a script to install and configure [Wayfire](https://wayfire.org) and related programs like [wf-shell](https://github.com/WayfireWM/wf-shell).

## Dependencies

The following is a list of dependencies needed on Ubuntu, similar lists are required on other distributions. The last one is only needed if you want to install WCM.

`sudo apt install git meson python3-pip pkg-config libwayland-dev autoconf libtool libffi-dev libxml2-dev libegl1-mesa-dev libgles2-mesa-dev libgbm-dev libinput-dev libxkbcommon-dev libpixman-1-dev xutils-dev xcb-proto python3-xcbgen libcairo2-dev libglm-dev libjpeg-dev libgtkmm-3.0-dev xwayland libdrm-dev libgirepository1.0-dev libsystemd-dev policykit-1 libx11-xcb-dev libxcb-xinput-dev libxcb-composite0-dev xwayland libasound2-dev libpulse-dev libseat-dev valac libdbusmenu-gtk3-dev libxkbregistry-dev libdisplay-info-dev hwdata`

Dependency list for ArchLinux

`pacman -Syu autoconf pkgconf sudo which alsa-lib cairo clang cmake egl-gbm git glib2-devel glm gtk-layer-shell gtkmm3 libc++ libdbusmenu-gtk3 libdisplay-info libdrm libgirepository libglvnd libinput libpulse libxkbcommon lld meson ninja nlohmann-json pango pixman scdoc seatd vala wayland wayland-protocols xorg-server-devel xorg-utils-macros xorg-xwayland scour doxygen doctest libliftoff`

These packages are part of the base-devel package (autoconf pkgconf sudo which).

Suggested packages that are useful after initial install:  alacritty wlr-randr alsa-utils nano thunar xdg-desktop-portal xdg-dekstop-portal-gtk xdg-desktop-portal-wlr

## `install.sh`

The general usage is:

```
git clone https://github.com/WayfireWM/wf-install
cd wf-install

./install.sh --prefix /opt/wayfire --stream 0.8.x
```

The last script will download all necessary components and install them to the given prefix.
If you want to build the latest versions, use `--stream master`.
For Wayfire and wf-shell, default configuration files will also be installed to `$XDG_CONFIG_HOME/wayfire.ini` or `~/.config/wayfire.ini`

The script also has a few other options, which you can see by calling `./install.sh --help`

## `update_build.sh`

`update_build.sh` is a script similar to `install.sh`, but assumes you have already built and installed Wayfire.
It will simply update the downloaded code, recompile and install it to the same prefix as configured with `install.sh`.

```
./update_build.sh . 0.8.x
```

The first parameter is the toplevel directory where you started the build (i.e the folder with `wayfire`, `wf-shell` and `wcm` source), and the second one is the version of Wayfire to build.
