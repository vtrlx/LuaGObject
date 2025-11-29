# LuaGObject GVariant Support

LuaGObject provides extended overrides for supporting GLib's GVariant type. It supports the following operations with variants:

## Creation

Variants should be created using GLib.Variant(type, value) constructor. The `type` parameter is either GLib.VariantType or just a plain string describing requested type of the variant. These types are supported:

- `b`, `y`, `n`, `q`, `i`, `u`, `q`, `t`, `s`, `d`, `o`, `g` are basic types, see either GVariant's documentation or the DBus specification for their meaning. The `value` argument is expected to contain an appropriate string or number for the basic type.
- `v` is the variant type, where `value` should be another GLib.Variant instance.
- `m` is the 'maybe' type, where `value` should be either `nil` or a value acceptable for the target type.
- `a` is an array of values of the specified type, where `value` is expected to contain a Lua table (array) with values for the array. If the array contains `nil` elements inside, it must contain also the `n` field with the real length of the array.
- `(typelist)` is a tuple of types, where `value` is expected to contain a Lua table (array) with values for the tuple members.
- `{key-value-pair}` is a dictionary entry, where `value` is expected to contain a Lua table (array) with 2 values (key and value) for the entry.

There are two convenience exceptions from above rules:

1. when an array of dictionary entries is given (i.e. a dictionary), `value` is expected to contain a Lua table with keys and values mapping to dictionary keys and values
2. when an array of bytes is given, a bytestring is expected in the form of a Lua string, not an array of byte numbers.

Here are some examples to create valid variants:

	GLib = require("LuaGObject").Glib
	local v1 = GLib.Variant("s", "Hello")
	local v2 = GLib.Variant("d", 3.14)
	local v3 = GLib.Variant("ms", nil)
	local v4 = GLib.Variant("v", v3)
	local v5 = GLib.Variant("as", { "Hello", "world" })
	local v6 = GLib.Variant("ami", { 1, nil, 2, n = 3 })
	local v7 = GLib.Variant("(is)", { 100, "title" })
	local v8 = GLib.Variant("a{sd}", { pi = 3.14, one = 1 })
	local v9 = GLib.Variant("aay", { "bytestring1", "bytestring2" })
	local v10 = GLib.Variant("(a{o(oayays)})",
		{{["/path/to/object1"]={"/path/to/object2",
			"bytestring1",
			"bytestring2",
			"string"}}})

## Data access

LuaGObject implements the following special properties for accessing data stored inside variants:

- `type` contains a read-only string describing the variant's type
- `value` unpacks the value of the variant. Simple scalar types are unpacked into their corresponding Lua variants, tuples and dictionary entries are unpacked into Lua tables (arrays), child variants are expanded for `v`-typed variants. Dictionaries return a proxy table which can be indexed by dictionary keys to retrieve dictionary values. Generic arrays are __not__ automatically expanded, the source variants are returned instead.
- The length operator `#` is overridden for GLib.Variants, returning number of child elements. Non-compound variants always return 0, and 'maybe's return 0 or 1. Arrays, tuples and dictionary entries return the number of children subvariants.
- The numeric accessor operator `[number]` can index compound variants, returning the n-th subvariant (array entry, n-th field of tuple etc).
- `pairs() and ipairs()` can accept Variants, which behave as expected.
- contents of complex data types may be accessed using `get_child_value` method call.

Examples of extracting values from variants created above:

	assert(v1.type == "s" and v1.value == "Hello")
	assert(v2.value == 3.14)
	assert(v3.value == nil and #v3 = 0)
	assert(v4.value == nil and #v4 = 1)
	assert(v5.value == v5 and #v5 == 2 and v5[2] == "world")
	assert(#v6 == 3 and v6[2] == nil)
	assert(v7.value[1] == 100 and v7[1] == 100 and #v7 == 2)
	assert(v8.value.pi == 3.14 and v8.value["one"] == 1 and #v8 == 2)
	assert(v9[1] == "bytestring1")
	assert(v10:get_child_value(0)
		:get_child_value(0)
		:get_child_value(1)
		:get_child_value(2).value == "bytestring2")
	for k, v in v8:pairs() do print(k, v) end

## Serialization

To serialize a variant into bytestream form, use the `data` property, which returns a Lua string containing the serialized variant. Deserialization is done by calling the `Variant.new_from_data` constructor, which is similar to `g_variant_new_from_data`, but it does _not_ accept a `destroy_notify` argument. See the following serialization example:

	local v = GLib.Variant("s", "Hello")
	local serialized = v.data
	assert(type(data) == "string")

	local newv = GLib.Variant.new_from_data(serialized, true)
	assert(newv.type == "s" and newv.value == "Hello")

## Other operations

LuaGObject also contains many of the original `g_variant_` APIs, but many of them are not necessary because their functionality is covered in a more Lua-native way by operations described above. However, there are still some useful calls, which are described here. All of them can be called using object notation on variant instances, e.g. `local vt = variant:get_type()`. See GLib's documentation for more detailed descriptions.

- `print(with_types)` returns a textual format of the variant. Note that LuaGObject does not contain opposite operation, i.e. g_variant_parse is not implemented yet.
- `is_of_type(type)` checks whether a variant instance conforms to the specified type
- `compare(other_variant)` and `equal(other_variant)` allow comparison of variant instances
- `byteswap()`, `is_normal_form()`, and `get_normal_form()` for changing the underlying binary representation of variants.
- `get_type()` returns a `VariantType` instance representing the type of the variant. It's seldom useful, as the `type` property returns the type as a string and is usually the better choice.
- `GLib.VariantBuilder` is supported, but it is rarely useful as the creation of variant instances using constructors as noted above is usually preferred. An exception where `VariantBuilder` may be advisable is when creating very large arrays as creating a source Lua table might waste a lot of memory. Building such an array piece by piece using a `VariantBuilder` is often preferable. Not that `VariantBuilder`'s `end()` method clashes with Lua's `end` keyword, so LuaGObject renames it to `_end()`.
- `VARIANT_TYPE_` constants are accessible as `GLib.VariantType.XXX`, e.g. `GLib.VariantType.STRING`. Although there should not be many cases where these constants are needed.
