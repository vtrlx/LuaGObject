# LuaGObject Overview

LuaGObject is Lua binding to GObject-based libraries, in particular the GNOME
platform. It is implemented as dynamic binding using GObject-Introspection. This
means that all libraries with support for GObject-Introspection can be used in
Lua by means of LuaGObject without the need for LuaGObject to explicitly add
support.

## Installation

### Dependencies

LuaGObject depends on `GIRepository >= 2.80`. To build, GIRepository's
development package must also be installed. Note that required GIRepository
version is still somewhat new as of 2025.

In order to be able to use assorted GObject-based libraries through
LuaGObject, these libraries must have properly installed `.typelib` files.
Most, if not all distributions already do this automatically. These typelibs
should also be available in GNOME's Flatpak SDKs, and this is the recommended
way to use LuaGObject.

### Supported Platforms

LuaGObject is currently tested on Linux (all sane Linux distributions should
work fine) and Cygwin. There is no principal obstacle for supporting other
platforms, as long as GIRepository and Lua are ported and working there.

### Installing with GNU Make

The recommended way to install LuaGObject is to build from source with GNU Make.

    make [LUA_VERSION=version]
    sudo make install [LUA_VERSION=version] [PREFIX=prefix-path] [DESTDIR=destir-path]

The default arguments are `LUA_VERSION=5.1`, `PREFIX=/usr/local` and `DESTDIR`
is empty.

Note that LuaGObject may not build with Lua if installed using your system's
package manager. If so, you should install PUC-Rio Lua from source, and then
specify the `LUA_VERSION` variable in both the `make` command and the
`sudo make install` command.

If building LuaGObject for use in a Flatpak, be sure to set `PREFIX=/app`.

## Quick Overview

All LuaGObject functionality is available in the Lua module named `LuaGObject`,
which is loaded by using Lua's `require` function:

    local LuaGObject = require 'LuaGObject'

Any installed library supporting GObject-Introspection will automatically be
made available on the returned LuaGObject table.

    local Adw = LuaGObject.Adw
    local Gtk = LuaGObject.Gtk
    local Gio = LuaGObject.Gio
    local GLib = LuaGObject.GLib

To create an instance of the class, simply 'call' the class in the namespace as
if it were a function:

    local header_bar = Adw.HeaderBar()

Certain classes have specific constructors which must be called by name and
given specific parameters:

    local window_title = Adw.WindowTitle.new('Window', 'made with LuaGObject')

To access object properties, use normal Lua table access notation:

    header_bar.title_widget = window_title

Note that properties often have a `-` (dash) character in them. This naming
is inconvenient in Lua, so LuaGObject translates dashes to underscores (`_`).

It is also possible to assign properties during construction by calling with a
table parameter:

    local window = Adw.ApplicationWindow {
        title = 'Window made using LuaGObject',
    }

Constructors may even be nested where appropriate:

    local view = Adw.ToolbarView {
        content = Adw.StatusPage {
            description = "Hello, LuaGObject!",
        },
    }
    window.content = view

If a property or parameter takes an enum value, it can be retrieved directly...

    view.top_bar_style = Adw.ToolbarStyle.FLAT

...or by using the value's nickname:

    view.top_bar_style = 'FLAT' -- Same as Adw.ToolbarStyle.FLAT

Methods can be called on an existing object using Lua's colon syntax:

    view:add_top_bar(header_bar)

Note that structures and unions are handled similarly to classes, but
structure fields are accessed instead of properties.

Bit flags are handled similarly to enums, but to combine multiple flags you may
also use a table containing a list of flag nicknames:

    local app = Adw.Application {
        application_id = 'org.example.LuaGObject',
        flags = { 'DEFAULT_FLAGS', 'HANDLES_OPEN' },
    }

(Note that this example does not actually handle opening files—the flags are
included here simply to illustrate LuaGObject's flags handling.)

To handle signals emitted by an object, assign an event handler to the
`on_<signalname>` object slot:

    app.on_startup = function(object)
        window.application = object
    end

    app.on_activate = function(object)
        object.active_window:present()
    end

When a GObject emits a signal, the first parameter in the called function is
always the GObject emitting the signal. Note that Lua's syntactic sugar for
defining methods is also an option here, which would bind the emitting object
to the variable `self`. The previous example can thus be rewritten as (where
`self` is `app`):

    local app = Adw.Application { application_id = 'org.example.LuaGObject' }

    function app:on_startup()
        window.application = self
    end

    function app:on_activate()
        self.active_window:present()
    end

It is recommended to use this syntax when connecting anonymous functions to
signals. Note however that it is not possible to disconnect signal handlers
which have been defined with anonymous functions, so use named functions when
that's necessary.

Finally, to finish this example, one needs to start the Adwaita application in
order to actually display the window.

    app:run()

Which will display a window with a short description. Close the window to stop
the application.

The full example should look like this:

```
#!/usr/bin/env lua

local LuaGObject = require 'LuaGObject'

local Adw = LuaGObject.Adw

local headerbar = Adw.HeaderBar()

local windowtitle = Adw.WindowTitle.new('Window', 'made using LuaGObject')

headerbar.title_widget = windowtitle

local window = Adw.ApplicationWindow {
	title = 'Made using LuaGObject',
}

local view = Adw.ToolbarView {
	content = Adw.StatusPage {
		description = 'Hello, LuaGObject!',
	},
}
window.content = view

view.top_bar_style = 'FLAT'

view:add_top_bar(headerbar)

local app = Adw.Application {
	application_id = 'org.example.LuaGObject',
	flags = { 'DEFAULT_FLAGS', 'HANDLES_OPEN' },
}

function app:on_startup()
	window.application = app
end

function app:on_activate()
	window:present()
end

app:run()
```

## Further Information

Note that as with properties, LuaGObject translates the dashes in signal names
to underscores to make it easier to connect to signal handlers. Note also that
class documentation will provide signal names without the `on_` prefix used by
LuaGObject to denote a signal, and you will need to always add `on_` yourself
whenever you wish to handle a signal in the way shown.

There is no need to handle any kind of memory management; LuaGObject handles
all reference counting internally in cooperation with Lua's garbage collector.

For APIs which use callbacks, you can pass a Lua function which will be called
when the callback is invoked. It is also possible to pass coroutine instance as
callback argument, in this case, coroutine is resumed and returning
`coroutine.yield()` returns all arguments passed to the callback. The callback
returns when coroutine yields again or finishes. Arguments passed to
`coroutine.yield()`, or the coroutine's exit status are then used as return
value from the callback.

The `samples` directory contains many examples, but note that these are older
and may not work without modifications.

For examples of complete GNOME apps built using LuaGObject, see
[Tally](https://github.com/vtrlx/tally) and
[Parchment](https://github.com/vtrlx/parchment).
