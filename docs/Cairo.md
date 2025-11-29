# Cairo

Cairo is a library for drawing graphics. It is a core part of many Gtk apps, as Gtk uses Cairo for much of its drawing. Cairo is thus an important part of any Gtk app, but Cairo is also not built on GObject and thus is not introspectable through GObject-Introspection which causes significant problems for any binding based on GObject-Introspection, including LuaGObject. To alleviate this, LuaGObject provides its own bindings to some Cairo features.

## Basic Cairo Bindings

Although the implementation of the Cairo binding is different from other GObject—Introspection-based bindings, the difference is not noticeable when using LuaGObject. Cairo is imported the same way as other libraries:

	local LuaGObject = require "LuaGObject"
	local cairo = LuaGObject.cairo

As with GObject-based libraries which are implemented in C, Cairo's library is internally organized using an object-oriented style, with structs (e.g.: `cairo_t`, `cairo_surface_t`) acting as objects and functions being as methods which act on the objects. LuaGObject exports these within a namespace named `cairo` (e.g.: `cairo.Context`, `cairo.Surface`). To create a new object instance, Cairo has built-in `_create` methods for its classes, and these are mapped to `cairo.Surface.create` for `cairo_surface_create`, etc. It is also possible to invoke them using the constructor syntax LuaGObject makes available for GObject-based libraries by calling the namespace table directly, making the following lines equivalent:

	local cr = cairo.Context.create(surface)

	local cr = cairo.Context(surface)

### Version Checking

The fields `cairo.version` and `cairo.version_string` contain the runtime's current cairo library version as returned by the C functions `cairo_version()` and `cairo_version_string()`. The C-side `CAIRO_VERSION_ENCODE()` macro is reimplemented as `cairo.version_encode(major, minor, micro)`, and can be used to compare against the contents of `cairo.version` for version-specific functionality. To run separate code with Cairo 1.12 or later:

	if cairo.version >= cairo.version_encode(1, 12, 0) then
		-- Cairo 1.12-specific code
	else
		-- Fallback to older cairo version code
	end

### Synthetic Properties

Each Cairo object has many getter and setter methods associated with them. LuaGObject exports them in the form of method calls just as the native C interface does, and it also provides property-like access. It is possible to query and assigned to named properties on a Cairo object as with those based on GObject. Here are two identical ways of setting the line width of a `cairo.Context` instance:

	local cr = cairo.Context(surface)
	cr:set_line_width(10)
	print("line width ", cr:get_line_width())

	local cr = cairo.Context(surface)
	cr.line_width = 10
	print("line width ", cr.line_width)

Generally speaking, any pair of `get_<name>()` and `set_<name>()` functions will be accessible as a property in Cairo through LuaGObject.

### cairo.Surface Hierarchy

Cairo's fundamental rendering object is `cairo.Surface`. It also implements many more specialized surfaces which implement rendering to specific targets (e.g.: `cairo.ImageSurface`, `cairo.PdfSurface`, etc) each providing their own class which is logically inherited from `cairo.Surface`. LuaGObject fully implements this inheritance, so calling `cairo.ImageSurface()` returns instance providing all methods and properties from both `cairo.Surface` and `cairo.ImageSurface`.

Additionally, LuaGObject always tracks the real type of a surface, so that even when a method like `cairo.Context.get_target()` (or its associated property, `cairo.Context.target`) will return a `cairo.Surface` instance which LuaGObject will query to determine which precise surface type is actually returned. The following example demonstrates querying a property `.width` of the `cairo.ImageSurface` class from a property which is supposed to return an instance of the generic `cairo.Surface` class:

	-- Assumes `cr` is a cairo.Context instance with an assigned surface
	print("width of the surface" cr.target.width)

It is also possible to use LuaGObject's typechecking mechanism to check a
surface's underlying type:

	if cairo.ImageSurface:is_type_of(cr.target) then
		print("width of the surface" cr.target.width)
	else
		print("unsupported type of the surface")
	end

### cairo.Pattern Hierarchy

Cairo's pattern API hides the inheritance of assorted pattern types. LuaGObject's binding exposes this hierarchy in the same way as it does for surface types, described in the previous section. The pattern hierarchy is as follows:

- cairo.Pattern
	- cairo.SolidPattern
- cairo.SurfacePattern
- cairo.GradientPattern
	- cairo.LinearPattern
	- cairo.RadialPattern
- cairo.MeshPattern

Patterns can be created using static factory methods on `cairo.Pattern` as described in Cairo's documentation, but LuaGObject additionally maps creation methods to subclass constructors as it does with GObject-based libraries. The following snippets are thus equivalent:

	local pattern = cairo.Pattern.create_linear(0, 0, 10, 10)

	local pattern = cairo.LinearPattern(0, 0, 10, 10)

### cairo.Context Path Iteration

The Cairo library offers iteration over drawing paths returned by the `cairo.Context.copy_path()` method. The resulting path can be iterated using the `:pairs()` method added to the `cairo.Path` class by LuaGObject. It returns an iterator suitable for use in Lua's for loop. For each item to be iterated on, it returns the type and an array table of either 0, 1, or 3 points. See this example of how to iterate on a path:

	local path = cr:copy_path()
	for kind, points in path:pairs() do
		io.write(kind .. ":")
		for pt in ipairs(points) do
			io.write((" { %g, %g }"):format(pt.x, pt.y))
		end
	end

## Impact of Cairo on Other Libraries

In addition to Cairo itself, there are many Cairo-specific methods inside Gtk, Gdk, and Pango. LuaGObject wires them up in such a way that these libraries' cairo functions can be called naturally as if they were built into the Cairo core itself.

### Gdk and Gtk

`Gdk.Rectangle` is just a link to `cairo.RectangleInt` (similar to C, where `GdkRectangle` is just a typedef of `cairo_rectangle_int_t`). LuaGObject wires up `gdk_rectangle_union` and `gdk_rectangle_intersect` as methods of the `Gdk.Rectangle` class as expected.

`Gdk.cairo_create()` is aliased to `Gdk.Window.cairo_create()`. `Gdk.cairo_region_create_from_surface()` is aliased to `cairo.Region.create_from_surface()`.

`cairo.Context.set_source_rgba()` is overriden so that it also accepts a `Gdk.RGBA` instance as an argument. Similarly, `cairo.Context.rectangle()` alternatively accepts `Gdk.Rectangle` as an argument.

`cairo.Context` has a few additional methods, namely `get_clip_rectangle()`, `set_source_color()`, `set_source_pixbuf()`, `set_source_window()` and `set_source_region()`, implemented as calls to appropriate `Gdk.cairo_xxx` functions.

Since all of these extensions are implemented inside Gdk and Gtk libraries, they are present only when `LuaGObject.Gdk` is loaded. When loading just pure `LuaGObject.cairo`, they are not available.

### PangoCairo

The Pango font rendering library contains a namespace called `PangoCairo` which implements many Cairo-specific helper functions to integrate Pango with Cairo. It is possible to call them a global methods of the `PangoCairo` namespace, but LuaGObject also overrides these functions to make them available on Pango classes to which these methods logically belong.
