# LuaGObject

LuaGObject is a library which dynamically generates Lua bindings to libraries which support GObject-Introspection such as Adwaita, GTK, GLib, Gio, Pango, and many more. It also generates bindings to Cairo, necessary for certain Gtk functionality.

This library is licensed under an [MIT-style](http://www.opensource.org/licenses/mit-license.php) license. See the LICENSE file for the full text.

LuaGObject is tested and compatible with PUC-Rio Lua (versions 5.1, 5.2, 5.3, 5.4, and 5.5) as well as LuaJIT2. Other Lua implementations are not officially supported.

This project is forked from [LGI](http://github.com/lgi-devs/lgi) and shares many of its internals, quirks, and overall structure.

## Installation

In order to be able to compile the native part of LuaGObject, GIRepository-2 >= 2.80.0 development package must be installed. The development package is called `libgirepository-2.0-dev` on Debian-based systems (Debian, Ubuntu, Mint, etc) and `glib2-devel` on RedHat-based systems (RHEL, Fedora, etc).

### Using GNU Make

Building LuaGObject using GNU Make is relatively straightforward:

	make
	[sudo] make install [PREFIX=<prefix>] [DESTDIR=<destdir>]

Please note that on BSD-systems you may need to use the 'gmake' command.

By default, building with GNU Make does not support using pkg-config to detect a system-installed Lua. For installing a development version of GObject with GNU Make, it is recommended to install PUC-Rio Lua [from source](https://www.lua.org/download.html).

### Using Meson

Building via Meson is also supported using Meson and Ninja as build tools, also requiring GIRepository-2 >= 2.80.0 as noted above.

	cd $(builddir)
	meson $(lua_gobject_srcroot) [--prefix=<prefix>] [--buildtype=<buildtype>] [--pkg-config-path=<pkgconfigpath>] [-Dlua-pc=...] [-Dlua-bin=...]
	ninja
	ninja test
	[sudo] ninja install

Building LuaGObject with Visual Studio 2013 and later is also supported via Meson. It is recommended in this case that CMake is also installed to make finding Lua or LuaJIT easier, since Lua and LuaJIT support Visual Studio builds via batch files or manual compilation of sources. Ensure that `%INCLUDE%` includes the path to the Lua or LuaJIT headers, and `%LIB%` includes the path where the `lua5x.lib` from Lua or LuaJIT can be found, and ensure that `lua5x.dll` and `lua.exe` or `luajit.exe` can be found in `%PATH%` and run correctly. For building with LuaJIT, please do not pass in `-Dlua-pc=luajit`, but do pass in `-Dlua-bin=luajit` in the Meson command line so that the LuaJIT interpreter can be found correctly.

## Usage

Documentation for LuaGObject is available in the `doc/` folder, formatted using Markdown. To read the documentation using HTML, process the docs using your preferred Markdown processor.

For developing a modern GNOME app, it is recommended to use Flatpak to ensure stability of dynamically generated bindings. See [Tally](https://github.com/vtrlx/tally) and [Parchment](https://github.com/vtrlx/parchment) for examples of complete applications developed using LuaGObject.

Older LGI-era examples are in the `samples/` directory. Please note that certain examples—especially for Gtk—are quite dated and may no longer be accurate.

### Migrating from LGI

Simply changing any instance of `require('lgi')` to `require('LuaGObject')` in source code should suffice for most applications, assuming LuaGObject is installed.

For more complex apps and especially for CI pipelines, it should be noted that `corelgilua51.{so,dll}` was renamed to `lua_gobject_core.{so,dll}`, and all `lgi/` paths have been renamed to `LuaGObject/`.

## Contributing

LuaGObject accepts bug reports and pull requests at [its GitHub repository](https://github.com/vtrlx/LuaGObject). Please only open an issue for behaviour which you yourself have observed; do not spam it with unverified claims. Likewise when submitting a pull request, please only submit code which you yourself have written.

Contributions to LuaGObject will not be accepted if they are found to contain any changes, in whole or in part, by any product branded as "AI", any LLM, any software "agent", or any other machine learning model. Machine leaning models include, but are not limited to: ChatGPT, Copilot, Claude, Ollama, and any other generative application. If a contribution is found to have been generated in whole or in part by a machine learning model, no further contributions from the same contributor will be accepted. Contributions are accepted at the sole discretion of LuaGObject's maintainer. There is no process to appeal the decision to reject a contribution, nor is there a process to appeal the decision to reject a contributor.

If you are experiencing any difficulty with understanding LuaGObject's code without the use of the aforementioned machine learning models, it is recommended to instead get in contact with the maintainer by sending an email to `victoria AT vtrlx DOT ca` with a subject line indicating you'd like assistance understanding LuaGObject's internals.

## Credits

LuaGObject would not be possible without the work of Christian Hergert, who did the initial work on porting LGI to GIRepository 2.80.

LuaGObject is also built on the work of LGI's developers, listed below in no particular order.

- Pavel Holejsovsky
- Uli Schlachter
- Jasper Lievisse Adriaanse
- Ildar Mulyukov
- Nils Nordman
- Ignas Anikevicius
- Craig Barnes
- Nicola Fontana
- Andreas Stührk
- Aaron Faanes
- Jiří Klimeš
- Garrett Regier
- Kenneth Zhou
- Travis Hoppe
- Tobias Jakobs
- Heiko Becker
- Vincent Bermel
- Szunti

## History

### 0.10.1 (2025-09-04)

- Can now add children directly to many GTK 4 and Adwaita widgets when constructing them

### 0.10.0 (2025-07-28)

- First version under the name "LuaGObject"
- Supports PUC-Rio Lua 5.4
- Supports PUC-Rio Lua 5.5
- Compatible with GTK 4 and libadwaita (a.k.a. "Adw")
- The `Gio.Async` override now supports additional styles of async methods, where functions are named `<name>` and `<name>_finish` without any `_async` labels
- Enum and flag parameters in functions are now optional, defaulting to a 0 value when omitted
- Core GI code is based on GIRepository-2.0, allowing use of LuaGObject with GNOME 49 and later
- Can now be built with Meson

### Older Pre-Fork Versions

LuaGObject was forked from LGI after it stopped receiving new releases. To see the version history of its older versions, see the "History" subheading in LGI's [README](http://github.com/lgi-devs/lgi#history).
