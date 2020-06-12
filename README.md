# wf-install

## `install.sh`
`install.sh` is a script to install and configure [Wayfire](https://wayfire.org) and related programs like [wf-shell](https://github.com/WayfireWM/wf-shell).

The general usage is:

```
git clone https://github.com/WayfireWM/wf-install
cd wf-install

./install.sh --prefix /opt/wayfire --stream 0.4.0
```

The last script will download all necessary components and install them to the given prefix.
If you want to build the latest versions, use `--stream master`.
For Wayfire and wf-shell, default configuration files will also be installed to `$XDG_CONFIG_HOME/wayfire.ini` or `~/.config/wayfire.ini`

The script also has a few other options, which you can see by calling `./install.sh --help`

## `update_build.sh`

`update_build.sh` is a script similar to `install.sh`, but assumes you have already built and installed Wayfire.
It will simply update the downloaded code, recompile and install it to the same prefix as configured with `install.sh`.

```
./update_build.sh . 0.4.0
```

The first parameter is the toplevel directory where you started the build (i.e the folder with `wayfire`, `wf-shell` and `wcm` source), and the second one is the version of Wayfire to build.
