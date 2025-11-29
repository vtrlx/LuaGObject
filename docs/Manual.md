# LuaGObject User's Guide

All LuaGObject functionality is exported through the `LuaGObject` module. To access it, call `require "LuaGObject"`:

	local LuaGObject = require "LuaGObject"

## 1. Importing libraries

To use any GObject library which enables GObject-Introspection, it has to be imported first. The easiest way to do this is by simply referencing its namespace on the LuaGObject table like so:

	local GLib = LuaGObject.GLib
	local GObject = LuaGObject.GObject
	local Gtk = LuaGObject.Gtk

This imports the latest version of the module which can be found. To import a specific version of a given module, call `LuaGObject.require(name, version)`:

	local Gst = LuaGObject.require("Gst", "0.10")

### 1.1. Repository Structure

Importing a library creates a table containing all elements present in that library's namespace—all classes, structures, global functions, constants etc. All of these elements are directly accessible, for instance:

	assert(GLib.PRIORITY_DEFAULT == 0)

All elements in a namespace are lazy-loaded in order to prevent excessive memory use and greatly speed up the initial load time. LuaGObject adds a method called `_resolve(deep)` to each namespace to force eager loading (recursively, if `deep` is `true`), so:

	dump(Gtk.Widget:_resolve(true), 3)

This prints everything available in Gtk.Widget class, and

	dump(Gio:_resolve(true), 5)

dumps the entire contents of the Gio package.

Note: the `dump` function used in this manual is from `cli-debugger` and not LuaGObject. You can easily substitute for another similar function.

## 2. Mapping Types Between GLib and Lua

In order to call GObject methods and access GObject properties and fields from Lua, LuaGObject establishes a mapping between GLib types and Lua types.

- `void` is ignored, and does not produce any Lua value
- `gboolean` is mapped to Lua's `boolean` type, with `true` and `false` values
- All numeric types are mapped to Lua's `number` type
- Enumerations are primarily handled as strings with uppercased GType nicks, optionally the direct numeric values are also accepted.
- Bitflags are primarily handled as lists or sets of strings with uppercased GType nicks, optionally the direct numeric values are also accepted.
- `gchar *` string is mapped to Lua as `string` type, encoded in UTF-8
- C array types and `GArray` are mapped to Lua tables, using the array part of the table. Although in C the arrays are 0-based, when copied to Lua table, they are 1-based (as Lua uses 1-based arrays).
- `GList` and `GSList` are also mapped to the array part of Lua tables
- `GHashTable` is mapped to Lua table, fully utilizing key-value and GHashTable's key and value pairs.
- C arrays of 1-byte-sized elements (i.e. byte buffers) are mapped to Lua strings instead of tables, although when going from Lua to GLib, tables are also accepted for this type of array.
- GObject classes, structs, and unions are mapped to LuaGObject instances of each specific class, struct, or union. It is also possible to pass `nil`, in which case the `NULL` pointer is passed to C-side (but only if the parameter or property are given the annotation `(allow-none)` in the original C method to allow passing `NULL`).
- `gpointer` values are mapped to Lua's `lightuserdata` type. When passing from Lua to GLib, the following are acceptable for `gpointer` types:
	- Lua strings instances
	- Instances of LuaGObject classes, structs, or unions
	- Binary buffers (see below)

### 2.1. Calling Functions and Methods

When calling GLib functions, the following conventions apply:

- The parameters passed from the Lua side map to the function's `input` parameters
- The first value returned to Lua is the function's return value (if it exists)
- All parameters marked as `output` are returned as multiple-return values (after the function's native return value, if it exists)
- In/out parameters are accepted as parameters, and also returned as multiple-return values
- Functions which report errors through `GError **` pointer parameters instead use Lua's standard error reporting—they typically return a boolean value indicating success or failure, also returning an error message and error code as multiple-return values

#### 2.1.1. Phantom Boolean Return Values

GLib-based libraries often use a boolean return value to indicate whether an output argument has been filled or not. A typical example would be `gboolean gtk_tree_model_get_iter_first(GtkTreeModel *tree_model, GtkTreeIter *iter)` where the value pointed by `iter` is filled if the method is successful, but untouched if it fails. Binding functions in this way feels unnatural in Lua:

	local ok, iter = model:get_iter_first()
	-- Even in case of failure, iter contains new 0-initialized
	-- instance of the iterator, so the following line is necessary:
	if not ok then iter = nil end

For ease of usage of such methods, LuaGObject avoids returning the first boolean return value. If a C function returns `false` in this case, all other output arguments are returned as `nil` instead. This means that the previous example must be written as:

	local iter = model:get_iter_first()

If the returned `iter` is `nil`, then the function failed. Otherwise, it was successful.

### 2.2. Callbacks

If a GLib function requires a callback function, a Lua function should be passed (or alternatively, a userdata or table implementing the `__call` metamethod), and the position for the callback context (usually a `gpointer` called `user_data` in the C function signature) is ignored completely. Callbacks are invoked in the context of a Lua coroutine which invoked the original call, unless that coroutine is suspended—in this case, a new coroutine is automatically created and the callback is invoked within this new context.

Callback arguments and return values are governed by the same rules as other argument and type conversions noted above. If the Lua callback throws an error, the error is *not* caught by the site calling the callback. It is instead propagated out to the original caller (you) and will terminate your application unless `pcall` was called somewhere in the chain, as with any other Lua application.

It is also possible to provide a coroutine instance as a callback argument. If so, the coroutine is resumed at callback time, and callback parameters are provided to `coroutine.resume()` (which become the return values for a previous `coroutine.yield()` call that suspended the coroutine). The callback is considered to have returned either if the coroutine terminates (with the final return values are used as the callback's return values) or the coroutine is yielded a second time (in which case the parameters passed to `coroutine.yield()` are used as the callbacks return values).

While coroutines are very useful as callbacks when using Gio-style asynchronous calls, it is recommended to use LuaGObject's own `Gio.Async` override to call asynchronous functions as described in [its own documentation](Async.md) because it wraps many of the intricacies which may arise in the interaction between Lua coroutines and GLib's main loop.

## 3. Classes

To create a new class, it must be derived directly or indirectly from the `GObject` base class. Classes contain entities (properties, methods, and signals) while also providing a mechanism for inheritance—the ancestor's entities become part of a descendent class. LuaGObject supports Lua-like access to an object's entities using the dereference operators `.` and `[name]`, as well as through the method call operator `:`.

Manual memory management is unnecessary when using LuaGObject, as it handles all reference counting under the hood. Calling low-level `_ref` and `_unref` methods will usually lead to undesired behaviour, and is not recommended.

### 3.1. Creating instances

To create a new instance of a class (i.e.: a new object), call the class name as if it was a function:

    local window = Gtk.Window()

Optionally, if the class has an underlying constructor taking no arguments, LuaGObject will expose constructor semantics allowing properties to be initialized by passing a single table parameter:

	local window = Gtk.Window {
		title = "Made using LuaGObject",
	}

It is even possible to create an instance of a class for which GObject-Introspection typelib data is unavailable and only the GType is known by calling `GObject.Object.new()` as shown below:

	local gtype = "ForeignWidget"
	local widget = GObject.Object.new(gtype)
	local window = Adw.Window {
		title = "Contains a Foreign Widget",
		content = widget,
	}

### 3.2. Calling Methods

Methods are functions belonging to a class and intended to operate on a specific class instance. GObject achieves this by passing a pointer to an instance as the first argument, but in LuaGObject you are intended to use the `:` operator on an object such as calling `window:present()` (where `window` is a `Gtk.Window` object). As is the convention in Lua, this is identical to calling `window.present(window)`.

Methods are also available on the class itself and it is possible to invoke methods without using the object notation, so the previous examples may also be rewritten as `Gtk.Window.present(window)`. Doing this removes the dynamic lookup of a class' overridden methods, but it's worth noting that if `window` is an instance of a descendent type, this will avoid calling the descendant's overridden `:present()` method if it exists. In other words, this call convention ignores any potential `gtk_window_descendent_present()` method and instead calls directly to the underlying `gtk_window_present()` method. While this is usually not what you want, it is still sometimes desirable.

#### 3.2.1. Static Methods

Static methods (i.e.: class functions which do not take an instance as the first argument) are usually invoked from the class' namespace, e.g: `Gtk.Window.list_toplevels()`. A very common form of static methods are `new` constructors such as `Gtk.Window.new()`. In most cases, `new` constructors are provided only as a convenience for programmers who expect C-like object instantiation—in LuaGObject, it is preferable to use the construction syntax outlined in section 3.1 of this document.

### 3.3. Accessing Properties

An object's properties are accessed using Lua's `.` operator. So, to amend a `Gtk.Window`'s title, on can write `window.title = window.tile .. ' - new'`. Within GObject's system, property and signal names can contain a `-` character, which is cumbersome to use in Lua. For convenience, LuaGObject maps the dashes in property and signal names to underscore (`_`) characters. Therefore, one can access a window's `can-focus` property by using the name `can_focus` from Lua:

	window.can_focus = true

### 3.4. Signals

As with properties, dashes in signal names are mapped to underscores. Additionally LuaGObject adds a prefix `on_` to a signal's name when mapping it.

#### 3.4.1. Connecting to Signals

Assigning a Lua function to a signal will connect to the given signal as a new event handler. The event handler function receives the underlying object as its first parameter, followed by the signal's other parameters as defied. For instance:

	local window = Gtk.Window()
	window.on_destroy = function(w)
		assert(w == window)
		print("Destroyed", w)
	end

Note that Lua's syntactic sugar for method definition also applies for signals, so this is possible:

	local window = Gtk.Window()
	function window:on_destroy()
		assert(self == window)
		print("Destroyed", self)
	end

Reading a signal entity provides a table containing signal details—see GObject's documentation on signal details for more information on what this means—but this allows connecting signal handlers to signal details as well, which is particularly common for handling `notify` signals on properties. To be notified when a window becomes active or inactive, one can write this:

	local window = Gtk.Window()
	window.on_notify["is-active"] = function(self, pspec)
		assert(self == window)
		assert(pspec.name == "is-active")
		print("Window is active:", self.is_active)
	end

Both forms of signal connection will connect the handler to be called before the given signal's default handler. If it is desired to connect after a default signal handler (see documentation on `G_CONNECT_AFTER` for more details), the most generic possible connection call must be used e.g.: `object.on_<signalname>:connect(target, detail, after)`. The previous example rewritten using this connection style looks like:

	local window = Gtk.Window()
	local function notify_handler(self, pspec)
		assert(self == window)
		assert(pspec.name == "is-active")
		print("Window is active:", self.is_active)
	end
	window.on_notify:connect(notify_handler, "is-active", false)

#### 3.4.2 Emitting Signals

Emitting an existing signal is usually only necessary in the implementation of a subclass. The simplest method to do so is to "call" the signal on the object instance as if it where a function. For instance, for an object `window` which subclasses `Gtk.Window`, to emit the parent class' `destroy` signal one can write:

	window:on_destroy()

### 3.5. Dynamic Typing of GObjects

LuaGObject assigns real class types to instances dynamically by using runtime GObject-Introspection facilities. When a new class' instance is passed from C code into Lua, LuaGObject queries the underlying type of the object and finds the underlying type in its loaded repository then assigns this type to the Lua-side proxy for the created object. This means casting is unnecessary in LuaGObject, and it provides no facilities to do so.

See the following example. Assume `demo.ui` is a GtkBuilder XML UI file containing a definition for a `Gtk.Window` labelled `window1` and a `GtkAction` called `action1`:

	local builder = Gtk.Builder()
	builder:add_from_file("demo.ui")
	local window = builder:get_object("window1")
	-- Call Gtk.Window-specific method
	window:iconify()
	local action = builder:get_object("action1")
	-- Set Gtk.Action-specific property
	action.sensitive = false

Although the method `Gtk.Builder:get_object()` is marked as returning a `GObject *`, LuaGObject will actually check the real type of the returned object and assign a proper type to it, so the first call into `:get_object()` above will return a `Gtk.Window` while the second returns a `Gtk.Action`.

Another mechanism which allows LuaGObject to forgo casting is automatic interface discovery—if a given class implements some interface, the properties and methods of the interface are automatically made available on the object from Lua code.

### 3.6. Accessing an Object's Class Instance

On all GObject instances, LuaGObject implements a pseudo-property named `_class`, which can be used to query various pieces of information on an object's underlying class. As an example, one can list each of an object's properties by:

	function dump_props(obj)
		print("Dumping properties of ", obj)
		for _, pspec in pairs(obj._class:list_properties()) do
			print(pspec.name, pspec.value_type)
		end
	end

Calling `dump_props(Gtk.Window())` gives the following output:

	Dumping props of	LuaGObject.obj 0xe5c070:Gtk.Window(GtkWindow)
	name	    gchararray
	parent  GtkContainer
	width-request	gint
	height-request	gint
	visible gboolean
	sensitive   gboolean
	(etc ...)

### 3.7. Querying the Type of an Object Instance

To query whether any arbitrary value is actually an instance of a specified class or subclass, classes in LuaGObject define an `is_type_of` static method. This method takes one argument and checks whether the given argument is an object of the class on which `is_type_of` is being called.

	local window = Gtk.Window()
	print(Gtk.Window:is_type_of(window)) -- prints "true"
	print(Gtk.Widget:is_type_of(window)) -- prints "true"
	print(Gtk.Buildable:is_type_of(window)) -- prints "true"
	print(Gtk.Action:is_type_of(window)) -- prints "false"
	print(Gtk.Window:is_type_of("string")) -- prints "false"
	print(Gtk.Window:is_type_of(nil)) -- prints "false"

It is even possible to get an object's type table by using the `_type` pseudo-property:

	function same_type(template, unknown)
		local type = template._type
		return type:is_type_of(unknown)
	end

### 3.8. Defining and Implementing Subclasses

It is entirely possible to define and implement a child class of an existing class in LuaGObject entirely from Lua code, allowing you to implement different versions of the parent class' virtual methods as well as implementing new interfaces not implemented by a parent.

To create a subclass, LuaGObject first requires you to make a `package` which will contain a new namespace wherein your subclass will exist. To do so, call `LuaGObject.package(name)` like so:

	local MyApp = LuaGObject.package "MyApp"

Once a package has been created, it will exist on the `LuaGObject` table as any other namespace would:

	local Gtk = LuaGObject.Gtk
	local MyApp = LuaGObject.MyApp

To create a subclass, call `class(name, parent[, interface_list])` on your package namespace:

	MyApp:class("MyWidget", Gtk.Widget)
	MyApp:class("MyModel", GObject.Object, { Gio.ListModel })

Once created, a new class will behave exactly like other classes in namespaces discovered through GObject-Introspection.

	local widget = MyApp.MyWidget()

### 3.8.1. Defining New Methods

A subclass can be extended by defining and implementing new methods on it. To do so is quite simple.

	function MyApp.MyWidget:speak()
		print "I am a custom widget!"
	end

To make subclasses more useful, LuaGObject provides a `priv` table on each subclass, which can hold instance variables:

	function MyApp.MyWidget:set_invisible(invisible)
		self.priv.invisible = invisible
	end

### 3.8.2. Overriding Virtual Methods

A subclass is not very useful if it doesn't override any virtual methods inherited from its parent or interfaces. LuaGObject exposes each virtual method as `do_<name>`, which can be overridden by assigning it on the child class. For example, to override `Gtk.Widget`'s `show` function:

	function MyApp.MyWidget:do_show()
	        if not self.priv.invisible then
			-- Forward the call explicitly to a specific parent class
			Gtk.Widget.do_show(self)
			-- Query the class' parent and call the function
			MyApp.MyWidget._parent.do_show(self)
			-- Equivalent to super.do_show() in OOP languages
			self._type._parent.do_show(self)
		end
	end

**Please note** that virtual methods inherited from interfaces and the parent class must be overridden before constructing the first instance of your child class, so it's best to define them immediately after creating the subclass.

### 3.8.3. Installing New Properties

To install new properties on a derived class, assign new instances of `GObject.ParamSpec` to the `_property` table which LuaGObject makes available on all subclasses. Note that as with virtual methods, these must be installed before the first instance of the subclass is created.

	MyApp.MyWidget._property["my-label"] = GObject.ParamSpecString(
		"my-label", "Nick string", "Blurb string", "Default value",
		{ "READBLE", "WRITABLE", "CONSTRUCT" })

	function MyApp.MyWidget:speak()
		print(self.my_label)
	end

	local my_widget = MyApp.MyWidget {
		my_label = "A custom label",
	}

	my_widget:speak() -- Prints: "A custom label"
	my_widget.my_label = my_widget.my_label .. ", further customized!"
	my_widget:speak() -- Prints: "A custom label, further customized!"

Notice that as with all other classes, the dash (`-`) in the property's name is mapped to an underscore when accessing it in Lua. As the prior convention is to use dashes in property names, it is recommended to do so in your custom properties as well.

# 3.8.4. Custom Getters and Setters

It is possible to specify custom getter and setter methods by assigning to the class' `_property_get` and `_property_set` tables. By default, the value of a new property is mirrored to an instances's `priv` table, allowing for direct access from Lua without invoking a getter or setter. See this example of assigning a custom setter for `my-label`:

	function MyApp.MyWidget._property_set:my_label(new_value)
		-- Note that `self` here is correctly set to the object instance.
		print(("%s changed my-label from %s to %s"):format(
			self, self.priv.my_label, new_value))
			self.priv.my_label = new_value
	end
	local widget = MyApp.MyWidget()

	-- Access through GObject's property machinery
	widget.my_label = "label1"
	print(widget.my_label)

	-- Direct access to underlying storage
	print(widget.priv.my_label)

As noted before, LuaGObject automatically maps the dash to an underscore when accessing a property, and that includes defining custom getters or setters as well as direct access through `priv`.

## 4. Structures and Unions

LuaGObject supports structures and unions in a way similar to classes. Structs and unions can only have methods (as with classes) and fields, which are similar to properties.

### 4.1. Creating Instances

Instances of a struct are created by calling the struct's namespace as a function, e.g. `local color = Gdk.RGBA()`. For structures without constructors, newly-created instances are zero-initialized, but it is also possible to pass a table containing fields and values to assign to them, such as `local blue = Gdk.RGBA { blue = 1, alpha = 1 }`.

If a struct type defines a constructor named `new`, then it is automatically mapped by LuaGObject to the struct's callable, so calling `local main_loop = GLib.MainLoop(nil, false)` is identical to calling `local main_loop = GLib.MainLoop.new(nil, false)`.

### 4.2. Calling Methods and Accessing Fields

A struct's methods are called exactly as with class instances:

	local loop = GLib.MainLoop(nil, false)
	loop:run()
	-- ...which is equivalent to...
	GLib.MainLoop.run(loop)

Fields are accessed using Lua's `.` operator on a struct instance:

	local color = Gdk.RGBA { alpha = 1 }
	color.green = 0.5
	print(color.red, color.green, color.alpha)
	-- Prints: 0    0.5    1

## 5. Enumerations, Bitflags, and Constants

LuaGObject maps enumeration values to strings containing the the names of each given value, where values from a given enum are expected:

	local label = Gtk.Label()
	label.halign = "START" -- Sets halign to the value of GTK_ALIGN_START

LuaGObject creates tables for all enum and bitflag types in its repository, with names mapping to their underlying numeric values. The numeric value can thus be accessed by indexing its name on the type within the namespace. The previous example is equivalent to:

	label.halign = Gtk.Align.START

That said, accessing enum values in this way is seldom necessary.

Bitflags are handled similarly to enums:

	label:set_state_flags "INSENSITIVE"

To combine multiple bitflags, list all the names in the array part of a table:

	label:set_state_flags { "INSENSITIVE", "BACKDROP" }

This is equivalent to performing a bitwise OR on these values, except it's substantially more convenient and—for versions of Lua without bitwise operators—much easier to do.

You can even pass a numeric value instead if known, though it's not recommended:

	label:set_state_flags(32)

### 5.1. Optional Boolean, Enum and Bitflag Values

In the above example, only one parameter was passed to `Gtk.Widget:set_state_flags` even though it takes a second argument—a boolean value. If `nil` is given (or the parameter is elided), LuaGObject assumes `false`. The same applies to enums and bitflags—if `nil` is passed or a function parameter is elided, it will be treated as a value of 0 instead. Thus, these function calls are equivalent:

	label:set_state_flags(0, false)
	label:set_state_flags()

### 5.2. Getting Names from Numeric Values

LuaGObject also allows a reverse lookup of enum names from known values by indexing an enum type's table with a number:

	print(Gtk.Align[0]) -- Prints "FILL"

Note that enums are 0-indexed in order to map exact values to their names.

Indexing a bitflag type's table with a number will return a table containing value nicknames in the array part:

	for _, v in pairs(Gtk.StateFlags[3]) do
		print(v)
	end

This previous example prints "ACTIVE" and "PRELIGHT".

Using this technique, it is possible to check for the presence of a specified flag very easily:

	if Gtk.StateFlags[flags].SELECTED then
		-- Code handling selected case
	end

If ever a value cannot be cleanly decomposed into flags, the remaining bits are OR'd into a numeric value stored at index 1.

Occasionally, if a type definition contains inconsistent flags, simply passing an array table of nicknames may not produce correct results. For these cases, LuaGObject provides a pseudo-constructor for explicitly constructing bitflag values types accepting a table of nicknames and numeric values as its argument:

	label:set_state_flags(Gtk.StateFlags { 4, "FOCUSED", Gtk.StateFlags.LINK })

## 6. Threading and Synchronization

Lua does not allow for concurrency within a single Lua state, which rules out compatibility with GLib's threading API. Though concurrency can't be used from Lua, libraries wrapped by LuaGObject may still use threads internally. This can lead to situations where callbacks and signals are invoked from different threads. To avoid corrupting the Lua state, LuaGObject uses a single lock (mutex) preventing simultaneous access to Lua. LuaGObject will automatically acquire a lock when moving execution from C to Lua (such as by invoking a callback or returning from a C call) and will release the lock when moving from Lua to C (such as returning from a Lua callback or calling a C function).

In a typical GLib-based application, most of the runtime is spent inside of GLib's main loop. During the main loop, LuaGObject's lock is unlocked and mainloop can invoke Lua callbacks and signals as needed. This means that an application based on LuaGObject will automatically synchronize threads as needed.

The only situation requiring manual intervention is if GLib's main loop is not being used by your application (such as Copas scheduler or a QT GUI). In this case, LuaGObject's thread lock is locked at nearly all times which also prevents callbacks and signal event handlers from being called. To cope with this, LuaGObject provides the function `LuaGObject.yield()` which unlocks the LuaGObject lock when called, allowing the execution of callbacks and signal handlers originating from other threads. Once all queued callbacks and signal event handlers have resolved, LuaGObject reacquires the lock and execution is passed back to the Lua state. By adding a call to `LuaGObject.yield()` to another mainloop, threaded libraries can communicate back to your Lua state in a timely manner.

## 7. Logging

GLib provides logging functions using `g_message` and similar C macros. These are not usable directly in Lua, so LuaGObject provides a layer to access this functionality.

All logging is controlled by the `LuaGObject.log` table. To allow logging from Lua, call the `LuaGObject.log.domain(name)` function with the name of your application of library. This function returns a table containing functions named `message`, `warning`, `critical`, `error`, and `debug`—each of these functions takes a single format string and any number of additional parameters following the same rules as Lua's `string.format` method. A typical example is:

	local LuaGObject = require "LuaGObject"
	local log = LuaGObject.log.domain("MyApp")

	-- This is equivalent to 'g_message("A message %d", 1)' in C.
	log.message("A message %d", 1)

	-- This is equivalent to 'g_warning("Not found")' in C.
	log.warning "Not found"

## 8. Native Interoperability

There may be times where it is important to export either objects of records created in Lua to C code or vice-versa. LuaGObject allows transferring from Lua to C using Lua's `lightuserdata` type. To get a native pointer from any object instance, the `_native` attribute returns a pointer when queried:

	-- Create Lua-side window object.
	local window = Gtk.Window { title = "Hello" }

	-- Get native pointer to this object.
	local window_ptr = window._native

The variable `window_ptr` now holds a pointer to the `Gtk.Window` object.

To use a pointer from the C side of things, use Lua's API:

	// window_ptr can be now passed to C code, which can use it.
	GtkWindow *window = lua_touserdata (L, x);
	char *title;
	g_object_get (window, "title", &title);
	g_assert (g_str_equal (title, "Hello"));
	g_free (title);

An object created from the C side can also be passed to Lua as a `lightuserdata` value:

	// Create object on the C side and pass it to Lua
	GtkButton *button = gtk_button_new_with_label ("Foreign");
	lua_pushlightuserdata (L, button);
	lua_call (L, ...);

Assuming the call is to a function taking an argument named `button`, the userdata can be passed to the appropriate class' constructor as a parameter:

	-- Retrieve button on the Lua side.
	assert(type(button) == "userdata")
	box:append(Gtk.Button(button))

This isn't limited to classes—the same can be done with structs and unions.

## 9. GObject

Although GObject is unsurisingly compatible with GObject-Introspection, most of that library's elements are quite basic and to make programming in Lua simpler, LuaGObject provides special handling for certain GObject features.

### 9.1. GObject.Type

Unlike C's `GType` representation (which is an unsigned integer), LuaGObject will represent `GType` values by name as a string. Related constants and methods useful for handling `GType` values are present in the `GObject.Type` namespace.

Fundamental `GType` names are imported as constants into the `GObject.Type` namespace similarly to other enums, so it is possible to use `GObject.Type.INT` where `G_TYPE_INT` would be used in C code.

The available constants are `NONE`, `INTERFACE`, `CHAR`, `UCHAR`, `BOOLEAN`, `INT`, `UINT`, `LONG`, `ULONG`, `INT64`, `UINT64`, `ENUM`, `FLAGS`, `FLOAT`, `DOUBLE`, `STRING`, `POINTER`, `BOXED`, `PARAM`, `OBJECT`, and `VARIANT`.

Additionally, functions operating on `GType` values are also present in the `GObject.Type` namespace:

- `GObject.Type.parent()`
- `GObject.Type.depth()`
- `GObject.Type.next_base()`
- `GObject.Type.is_a()`
- `GObject.Type.children()`
- `GObject.Type.interfaces()`
- `GObject.Type.query()`
- `GObject.Type.fundamental_next()`
- `GObject.Type.fundamental()`

There is also a new function named `GObject.Type.type(name)` which returns the LuaGObject-native type representing the named `GType`. For example, calling `GObject.Type.type 'GtkWindow'` will return `Gtk.Window`:

	assert(Gtk.Window == GObject.Type.type("GtkWindow"))

When passing a `GType` value from Lua to C, you can use either a string with the type's name, a number representing the underlying numeric `GType` value, or any loaded component with a type assigned. Some examples:

	LuaGObject = require "LuaGObject"
	GObject = LuaGObject.GObject
	Gtk = LuaGObject.Gtk

	print(GObject.Type.NONE)
	print(GObject.Type.name(GObject.Type.NONE))
	-- prints "void" in both cases

	print(GObject.Type.name(Gtk.Window))
	-- prints "GtkWindow"

	print(GObject.Type.is_a(Gtk.Window, GObject.Type.OBJECT))
	-- prints "true"

	print(GObject.Type.parent(Gtk.Window))
	-- prints "GtkWidget"

### 9.2. GObject.Value

LuaGObject does not implement any automatic `GValue` boxing or unboxing, because this would involve guessing the `GType` of a Lua value and that is generally unsafe. Instead, easy to use and convenient wrappers for accessing `GValue` types and contents are provided.

#### 9.2.1. Creating GValues

To create new `GObject.Value` instances, 'call' `GObject.Value` as with classes and other LuaGObject types. The call has two optional arguments, specifying the `GType` of the newly created `GValue` and also the contents of resulting value. A few examples:

	local LuaGObject = require "LuaGObject"
	local GObject = LuaGObject.GObject
	local Gtk = LuaGObject.Gtk

	local empty = GObject.Value()
	local answer = GObject.Value(GObject.Type.INT, 42)
	local null_window = GObject.Value(Gtk.Window)
	local window = GObject.Value(Gtk.Window, Gtk.Window())

#### 9.2.2. Boxing and Unboxing GValues

`GObject.Value` adds two new pseudo-properties to `GValue` called `gtype` and `value` which contain the underlying type and value respectively. Both pseudo-properties readable and writable. Reading them will query the `GValue`'s current state by performing actual unboxing of the underlying `GValue`'s native data. Writing to `value` will perform boxing on the given Lua value. Writing to `gtype` will change the type of the `GValue` and if it already has a value, it will be converted using `g_value_transform()`. Some examples:

	assert(empty.gtype == nil)
	assert(empty.value == nil)
	assert(answer.gtype == GObject.Type.INT)
	assert(answer.value == 42)
	assert(null_window.gtype == "GtkWindow")
	assert(null_window.value == nil)

	empty.gtype = answer.gtype
	empty.value = 1
	assert(empty.gtype == GObject.Type.INT)
	assert(empty.value == 1)
	answer.gtype = GObject.Type.STRING)
	assert(answer.value == "42")

Although `GObject.Value` provides most of the methods provided by the `GValue` type for querying and setting data (e.g.: `g_value_get_string()` can be called by calling `GObject.Value.get_string()`, and `g_value_set_string()` can be called by calling `GObject.Value.set_string()`), it is recommended to always use the `value` and `gtype` pseudo-properties provided by LuaGObject.

### 9.3. GObject.Closure

Like with `GObject.Value` types, LuaGObject does not provide automatic boxing for `GClosure`s. To create a `GClosure` one must explicitly invoke its constructor by calling `GObject.Closure()` and passing a Lua function as its argument:

	local closure = GObject.Closure(func)

When the closure is executed, the given Lua function is called. The function receives `GObject.Value`s as arguments and it must return a `GObject.Value` as specified by the libraries being used.
