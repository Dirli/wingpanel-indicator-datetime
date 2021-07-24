# Wingpanel Date &amp; Time Indicator

This package is a fork of the upstream package, and if possible completely repeats its functionality. But the implementation has been rewritten almost completely. Most of the bugs have been fixed. It does not make sense to use the package together with the upstream, respectively, the name is left the same as the file structure. By installing it you are overwriting the upstream

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

### You'll need the following dependencies:
* gobject-introspection
* libecal1.2-dev
* libedataserver1.2-dev
* libical-dev
* libgranite-dev
* libgtk-3-dev
* libhandy-1-dev
* libwingpanel-2.0-dev
* meson
* valac >= 0.40.3

### How To Build
    meson build --prefix=/usr
    ninja -C build
    sudo ninja install -C build
