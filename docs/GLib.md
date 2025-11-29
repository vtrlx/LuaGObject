# GLib in LuaGObject

LuaGObject overrides numerous functions provided by GLib, which may change their semantics and parameters compared to C or other language bindings. This file documents all cases where that occurs.

## GLib Functions

[`GLib.markup_escape_text`](https://docs.gtk.org/glib/func.markup_escape_text.html) is changed so that its `len` parameter is optional. If not specified, it will be determine

## [GLib.Bytes](https://docs.gtk.org/glib/struct.Bytes.html)

LuaGObject allows querying the length of a `GLib.Bytes` instance from Lua using the length operator (`#`), and the underlying data can be obtained using the `.data` pseudo-property.

	-- Assuming `bytes` is an instance of GLib.Bytes,
	for i = 1, #bytes do
		print(i, bytes.data[i])
	end
	-- Alternatively,
	for i, byte in ipairs(bytes.data) do
		print(i, b)
	end

## [GLib.Error](https://docs.gtk.org/glib/struct.Error.html)

`GLib.Error` values may be constructed using the same arguments [from its constructor](https://docs.gtk.org/glib/ctor.Error.new.html), but LuaGObject also allows the `domain` parameter to be the actual underlying error type, or a string to be used to look up the appropriate `GQuark` value using [`GLib.quark_from_string()`](https://docs.gtk.org/glib/func.quark_from_string.html) and the `code` parameter may optionally be the nickname string of a specific error code instead of the underlying integer value.

For instance, to create a `G_FILE_ERROR_NOENT`:

	local err = GLib.Error.new(Gio.FileError, "NOENT", "no such file or directory")

### [GLib.Error:matches()](https://docs.gtk.org/glib/method.Error.matches.html)

To simplify error handling, the same conveniences provided for constructing error objects are also available on the `:matches()` method. This means it's possible to easily check errors using simple control flow in Lua.

To check for errors in reading a `Gio.File`,

	local file = Gio.File.new_for_path(path)
	local bytes, _, err = file:load_bytes()
	if err and err:matches(Gio.FileError, "NOENT") then
		-- handle the error
	elseif err and err:matches(...) then
		-- etc.
	end

## [GLib.MarkupParser](https://docs.gtk.org/glib/struct.MarkupParser.html) and [GLib.MarkupParseContext](https://docs.gtk.org/glib/struct.MarkupParseContext.html)

LuaGObject overrides the `GLib.MarkupParser` struct to add various important safety features to it. Additionally, `:start_element` method is also overridden such that the `attribute_names` and `attribute_values` arrays are now passed in as a table of key-value pairs. This means that, when creating your own `GLib.MarkupParser`, the `.start_element` attribute's function signature is different than expected.

If you want to handle a `color` attribute in your markup parser,

	local parser = GLib.MarkupParser {
		start_element = function(context, tag, attr)
			local element = { tag = tag, attr = attr }
			if attr.color then
				local color = parsecolor(attr.color)
			end
			...
		end,
		text = function(context, text)
			...
		end,
		end_element = function(context)
			...
		end,
	}

For a more detailed example of how to user a `GLib.MarkupParser`, see the file `samples/markupthrough.lua`.

A few overrides are also provided for `GLib.MarkupParserContext`. When constructing with `.new()` from Lua, the `user_data_dnotify` parameter is not present at all. The `:parse()` method is changed so that the `len` parameter is optional—if not given, one will be calculated based on the length of the `text` parameter.

## [GLib.Source](https://docs.gtk.org/glib/struct.Source.html) and [GLib.SourceFuncs](https://docs.gtk.org/glib/struct.SourceFuncs.html)

LuaGObject provides an additional field to `GLib.Source` instances called `.prepare`, which is derived from the same member of the `GLib.SourceFuncs` struct. To make it easier to initialize `GLib.Source` instances, LuaGObject also overrides its constructor so that a table of functions (as defined by `GLib.SourceFuncs`) may be passed as the parameter.

Thus, initializing a `GLib.Source` ressembles other class instantiations in LuaGObject,

	local source = GLib.Source {
		prepare = function(self, timeout)
			...
		end,
		check = function(self)
			...
		end,
	}

## GLib.Timer

LuaGObject overrides some internal functionality of the `GLib.Timer` class to ensure that it is allocated and freed properly once Lua's garbage collector runs, but the API to this class remains unchanged.

## GLib.Variant

LuaGObject's override for `GLib.Variant` is very extensive, so it is explained [in GLib-Variant.md](GLib-Variant.md).
