# LuaGObject Internal Core Reference

## Core

Core LuaGObject functionality is accessible through the `LuaGObject` module, loaded by calling `require 'LuaGObject'`. LuaGObject does not install itself into the global namespace and instead the caller has to use the return value from `require` call.

- `LuaGObject."module"`
	- `module` string with module name, e.g. "Adw", "Gtk", "WebKit", etc...

Loads the requested module of the latest version found into LuaGObject's repository.

- `LuaGObject.require(module, version)`
	- `module` string with module name, e.g. "Gtk" or "WebKit".
	- `version` string with exact required version of the module

Loads the requested module with specified version into LuaGObject's repository.

- `LuaGObject.log.domain(name)`
	- `name` is string denoting logging area name, usually identifying  the application or the library
	- returns a table containing
		- `message`
		- `warning`
		- `critical`
		- `error`
		- `debug`

The returned functions are for logging messages. They accept a format string and inserts, which are formatted according to Lua's `string.format` conventions.

- `LuaGObject.yield()`

When called, unlocks LuaGObject's state lock, thus allowing potentially blocked callbacks or signals to enter the Lua state. When using LuaGObject with GLib's MainLoop (which is automatically started when intializing Gtk or Adw), this call is not needed at all.

## GObject Basic Constructs

### GObject.Type

- `NONE`, `INTERFACE`, `CHAR`, `UCHAR`, `BOOLEAN`, `INT`, `UINT`, `LONG`, `ULONG`, `INT64`, `UINT64`, `ENUM`, `FLAGS`, `FLOAT`, `DOUBLE`, `STRING`, `POINTER`, `BOXED`, `PARAM`, `OBJECT`, `VARIANT`

Constants containing type names of fundamental GObject types.

- `parent`, `depth`, `next_base`, `is_a`, `children`, `interfaces`, `query`, `fundamental_next`, `fundamental`

Functions for manipulating and querying `GType`. They are direct mappings of `g_type_xxx()` APIs, e.g. `GObject.Type.parent()` behaves in the same way as `g_type_parent()` in C.

### GObject.Value

- `GObject.Value([gtype [, val]])`
	- `gtype` type of the value to create, if not specified, defaults to `GObject.Type.NONE`.
	- `val` Lua value to initialize GValue with.

Creates new GObject.Value of specified type, optionally assigns a Lua value to it. For example, `local val = GObject.Value(GObject.Type.INT, 42)` creates a GValue of type `G_TYPE_INT` and initializes it to value `42`.

- `GObject.Value.gtype`
	- reading yields the gtype of the value
	- writing changes the type of the value. Note that if the GValue is already initialized with some value, a `g_value_transform` is called to attempt to convert the value to the target type.

- `GObject.Value.value`
	- reading retrieves Lua-native contents of the referenced Value (i.e. GValue unboxing is performed).
	- writing stores Lua-native contents to the Value (boxing is performed).

### GObject.Closure

- `GObject.Glosure(target)`
	- `target` is a Lua function or anything else that is Lua-callable.

Creates a new GClosure instance wrapping the given Lua callable. When the closure is emitted, the `target` callable is invoked, getting GObject.Value instances as arguments, and expecting a single GObject.Value to be returned.
