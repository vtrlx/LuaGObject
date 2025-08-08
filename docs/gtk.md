# GTK and libadwaita Support

LuaGObject's Gtk support is based on GObject-Introspection. In practice, this means that GTK 3, GTK 4, and libadwaita ("Adw") should work out of the box.

Additionally to the default functionality exposed by these libraries, LuaGObject overrides certain classes within these libraries to provide some useful helpers for dealing with these libraries from the Lua side.

---

# GTK 4 Overrides

GTK 4's internals and class hierarchy are quite different from GTK 3, despite many widget classes exposing similar APIs as the previous major version. In practice, this means that GTK 3 overrides are largely incompatible with GTK 4. LuaGObject must therefore provide bespoke overrides for GTK 4, which will function differently from those for GTK 3.

## Accessing Width and Height

LuaGObject adds the `.width` and `.height` pseudo-property to all GTK 4 widgets. When read, these properties return the dimensions of the widget's current allocated space. When written, they set the value of the `width-request` or `height-request` properties which determine a widget's minimum size.

## Accessing Child Widgets

Any widget's children may be accessed through the `.children` pseudo-property. This returns a table which—when indexed with a number n—returns the n-th child of that widget, or `nil` if there is no n-th child.

	local box = Gtk.Box()
	box:append(Gtk.Label { label = 'first' })
	box:append(Gtk.Label { label = 'second' })
	box:append(Gtk.Label { label = 'third' })
	box:append(Gtk.Label { label = 'fourth' })
	print(box.children[1].label) -- Prints 'first'
	print(box.children[4].label) -- Prints 'fourth'

Because of how `ipairs()` works in Lua 5.3 and later, it is possible to pass a widget's `.children` attribute to `ipairs()` and iterate over all children. Continuing from above:

	for _, child in ipairs(box.children) do
		print(child.label)
	end

This example prints the labels' contents, in order.

Indexing with a negative number starts from the end and works backwards. Continuing again:

	print(box.children[-1].label) -- Prints 'fourth'
	print(box.children[-3].label) -- Prints 'second'

Indexing `.children` with 0 always returns `nil`.

## Constructing with Child Widgets

GTK 4 gets rid of the Container class, making it somewhat more complicated to insert child widgets when constructing a parent. Instead, LuaGObject provides overrides for specific container widget classes allowing children to be specified in the array part of a table constructor. These classes are:

- `Gtk.Box`
- `Gtk.FlowBox`
- `Gtk.ListBox`
- `Gtk.Stack`

An example of instantiating a `Gtk.Box` with its own children:

	local box = Gtk.Box {
		orientation = 'VERTICAL',
		Gtk.Label { label = 'first' },
		Gtk.Label { label = 'second' },
		Gtk.Label { label = 'third' },
		Gtk.Label { label = 'fourth' },
	}

This creates a `Gtk.Box` containing four children. Note that `box`'s `orientation` property was set to `Gtk.Orientation.VERTICAL` as well in the same constructor. For specific container widgets, this creates a programmer experience not unlike using `Gtk.Builder` for creating widget hierarchies, but with a syntax ressembling Blueprint.

### Advanced Example: Removing Children

Many container widgets implement a `:remove()` method which takes a child `Gtk.Widget` as its argument. Without the GTK 4 override, removing a child in this way can be somewhat tricky—one may need to call a function like `:get_child_at_index()`, including adjusting the index to account for 0-indexing.

With the `.children` attribute from LuaGObject's GTK 4 overrides, this becomes trivial:

	local list = Gtk.ListBox {
		Gtk.Label { label = 'first row' },
		Gtk.Label { label = 'second row' },
		Gtk.Label { label = 'third row' },
	}
	list:remove(list.children[2])

This removes the `Gtk.ListBox`'s second row.

---

# Adw (libadwaita) Overrides

As all widgets in the Adw namespace inherit from GTK 4's `Gtk.Widget`, Adw's widgets also possess the `.children`, `.height`, and `.width` pseudo-properties on the Lua side. Each attribute works the same as in GTK 4.

Certain classes only exist in later versions of libadwaita. These version requirements will be noted where specific classes are mentioned.

## Constructing with Child Widgets

Like `Gtk.Box` and related classes, LuaGObject overrides certain Adw classes to allow specifying children to be added in constructor tables. The following widgets are supported:

- `Adw.PreferencesDialog`
	- Must only contain `Adw.PreferencesPage` children.
- `Adw.PreferencesPage`
	- Must only contain `Adw.PreferencesGroup` children.
- `Adw.PreferencesGroup`
- `Adw.ExpanderRow`
- `Adw.WrapBox` (Adw 1.7 and later)
- `Adw.ShortcutsDialog` (Adw 1.8 and later)
	- Must only contain `Adw.ShortcutsSection` children.
- `Adw.ShortcutsSection` (Adw 1.8 and later)
	- Must only contain `Adw.ShortcutsItem` children.

As with GTK 4, these constructors may be nested. Here is a more complex example involving the creation of a preferences page:

	local prefs_page = Adw.PreferencesPage {
		title = "Page 1",
		Adw.PreferencesGroup {
			title = "Group A",
			Adw.SwitchRow { title = "SwitchRow" },
			Adw.EntryRow { title = "EntryRow" },
		},
		Adw.PreferencesGroup {
			title = "Group B",
			Adw.SpinRow {
				title = "SpinRow",
				adjustment = Gtk.Adjustment.new(0, 0, 100, 1, 10, 0),
			},
		},
	}

## Constructing with Supplemental Widgets

Certain Adw classes have multiple different kinds of child widgets, preventing them from being arbitrarily added like with other container-type widgets. Widgets that work this way usually do so to distinguish between children coming before, and after, the main widget body. Each class supporting this pattern does so using class-specific methods. LuaGObject provides pseudo-properties for specific classes allowing these kinds of children to be added at construction time. Each pseudo-property is write-only and takes a value of either a single widget or a table array of widgets. Currently, these classes are:

- `Adw.HeaderBar`
	- `.start_packs` for widgets to be added through `:pack_start()`
	- `.end_packs` for widgets to be added through `:pack_end()`
- `Adw.ActionRow`
	- `.prefixes` for widgets to be added through `:add_prefix()`
	- `.suffixes` for widgets to be added through `:add_suffix()`
- `Adw.ToolbarView` (Adw 1.4 and later)
	- `.top_bars` for widgets to be added through `:add_top_bar()`
	- `.bottom_bars` for widgets to be added through `:add_bottom_bar()`

To initialize an `Adw.ToolbarView` with a top bar:

	local toolbar_view = Adw.ToolbarView {
		content = Adw.StatusPage {
			description = "Made with LuaGObject",
		},
		top_bars = Adw.HeaderBar {
			title_widget = Adw.WindowTitle.new("LuaGObject Window", ""),
		},
	}

Note that writing to a pseudo-property like `.top_bars` does not overwrite any existing top bars—instead, the written widgets are always added. This limitation applies to every pseudo-property outlined in this section.

Each pseudo-property is also inherited from respective superclasses, e.g.: `Adw.SpinRow`, `Adw.SwitchRow` inherit `.prefixes` and `.suffixes` from `Adw.ActionRow`.

---

# GTK 3 Overrides

For GTK 3, LuaGObject provides some extensions in order to support unintrospectable features and to provide easier and more Lua-like access to certain GTK 3 objects. The rest of this document describes enhancements LuaGObject provides when using GTK 3.

To explicitly use GTK 3 in LuaGObject, pass the version parameter to `LuaGObject.require` like so:

	local LuaGObject = require 'LuaGObject'
	local Gtk = LuaGObject.require('Gtk', '3.0')

Please note that different versions of the same library cannot be loaded at the same time. This means if you've already loaded a library dependent on a different version of Gtk (such as Adw or GtkSourceView-5), you won't be able to load GTK 3.

Generally speaking, it's recommended to avoid GTK 3 for new applications unless writing them for a platform that has not yet moved on to GTK 4 or newer. If this is the case for you, read on.

## Basic Widget and Container support

### Accessing Style Properties

To read style property values of a widget, a `style` attribute is implemented by LuaGObject. The following example reads the `resize-grip-height` style property from a Gtk.Window instance:

	local window = Gtk.Window()
	print(window.style.resize_grip_height)

### Gtk.Widget Width and Height Properties

LuaGObject adds new `width` and `height` properties to Gtk.Widget. Reading them yields allocated size (`Gtk.Widget.get_allocated_size()`), writing them sets a new size request (`Gtk.Widget.set_size_request()`). These usages typically mean what application logic needs: get the actual allocated size to draw on when reading, and request a specific size when writing.

### Child Properties

Child properties are properties of the relation between a container and child. A Lua-friendly access to these properties is implemented through the `property` attribute of `Gtk.Container`. The following example illustrates writing and reading of `width` property of `Gtk.Grid` and child `Gtk.Button`:

	local grid, button = Gtk.Grid(), Gtk.Button()
	grid:add(button)
	grid.property[button].width = 2
	print(grid.property[button].width)	-- prints 2

### Adding Children to a Container

The intended way to add children to a container is through the `Gtk.Container.add()` method. This method is overloaded by LuaGObject so that it accepts either a widget, or a table containing a widget at index 1 with the rest of the `name=value` pairs defining the child's properties. Therefore, this method is a full replacement of the unintrospectable `gtk_container_add_with_properties()` function. Let's simplify the previous section's example with this syntax:

	local grid, button = Gtk.Grid(), Gtk.Button()
	grid:add { button, width = 2 }
	print(grid.property[button].width)	-- prints 2

Another important feature of containers is that they have an extended constructor, the constructor table argument's array part can contain widgets to be added as children. The previous example can be simplified further as:

	local button = Gtk.Button()
	local grid = Gtk.Grid {
		{ button, width = 2 }
	}
	print(grid.property[button].width) -- prints 2

### Gtk.Widget `id` Property

Another important feature is that all widgets support the `id` property, which can hold an arbitrary string which is used to identify the widget. `id` is assigned by the user and defaults to `nil`. To find a widget using the specified id in the container's widget tree (i.e. not only in direct container children), query the `child` property of the container with the requested id. Rewriting the previous example using this technique:

	local grid = Gtk.Grid {
		{ Gtk.Button { id = 'button' }, width = 2 }
	}
	print(grid.property[grid.child.button].width) -- prints 2

The advantage of these features is that they allow using Lua's data description syntax for describing widget hierarchies in a natural way, instead of `Gtk.Builder`'s human-unfriendly XML. To build a very complicated widget tree:

	Gtk = LuaGObject.Gtk
	local window = Gtk.Window {
		title = 'Application',
		default_width = 640, default_height = 480,
		Gtk.Grid {
			orientation = Gtk.Orientation.VERTICAL,
			Gtk.Toolbar {
				Gtk.ToolButton { id = 'about', stock_id = Gtk.STOCK_ABOUT },
				Gtk.ToolButton { id = 'quit', stock_id = Gtk.STOCK_QUIT },
			},
			Gtk.ScrolledWindow {
				Gtk.TextView { id = 'view', expand = true }
			},
			Gtk.Statusbar { id = 'statusbar' }
		}
	}

	local n = 0
	function window.child.about:on_clicked()
		n = n + 1
		window.child.view.buffer.text = 'Clicked ' .. n .. ' times'
	end

	function window.child.quit:on_clicked()
		window:destroy()
	end

	window:show_all()

Run `samples/console.lua`, paste the example into its entry view and enjoy. The `samples/console.lua` example itself shows more complex usage of this pattern.

## Gtk.Builder

Although Lua's declarative style for creating widget hierarchies is generally preferred to builder's XML authoring by hand, `Gtk.Builder` can still be useful when widget hierarchies are designed in some external tool like `glade`.

Normally, `gtk_builder_add_from_file` and `gtk_builder_add_from_string` return `guint` instead of `gboolean`, which would make direct usage from Lua awkward. LuaGObject overrides these methods to return `boolean` as the first return value, so that the construction `assert(builder:add_from_file(filename))` can be used.

A new `objects` attribute provides direct access to loaded objects by their identifier, so that instead of `builder:get_object('id')` it is possible to use `builder.objects.id`

`Gtk.Builder.connect_signals(handlers)` tries to connect all signals to handlers which are defined in `handlers` table. Functions from `handlers` table are invoked with the target object on which a signal is emitted as the first argument, but it is possible to define the `object` attribute, in this case the object instance specified in `object` the attribute is used. The `after` attribute is honored, but `swapped` is completely ignored, as its semantics for LuaGObject are unclear and not very useful.

## Gtk.Action and Gtk.ActionGroup

LuaGObject provides a new method `Gtk.ActionGroup:add()` which generally replaces the unintrospectable `gtk_action_group_add_actions()` family of functions. `Gtk.ActionGroup:add()` accepts single argument, which may be one of:

- an instance of `Gtk.Action` - this is identical to calling `Gtk.Action.add_action()`.
- a table containing instance of `Gtk.Action` at index 1, and optionally having an attribute `accelerator`; this is a shorthand for `Gtk.ActionGroup.add_action_with_accel()`
- a table with array of `Gtk.RadioAction` instances, and optionally an `on_change` attribute containing function to be called when the radio group state is changed.

All actions or groups can be added through an array part of the `Gtk.ActionGroup` constructor, as demonstrated by the following example:

	local group = Gtk.ActionGroup {
		Gtk.Action { name = 'new', label = "_New" },
		{ Gtk.Action { name = 'open', label = "_Open" },
		accelerator = '<control>O' },
		{
			Gtk.RadioAction { name = 'simple', label = "_Simple", value = 1 },
			{ Gtk.RadioAction { name = 'complex', label = "_Complex",
			value = 2 }, accelerator = '<control>C' },
			on_change = function(action)
				print("Changed to: ", action.name)
			end
		},
	}

To access specific action from the group, a read-only attribute `action` is added to the group, which allows to be indexed by action name to retrieve an action. Continuing the example above, we can implement an action named 'new' like this:

	function group.action.new:on_activate()
		print("Action 'New' invoked")
	end

## Gtk.TextTagTable

It is possible to populate new instance of the tag table with tags during the construction, the array part of the constructor argument table is expected to contain `Gtk.TextTag` instances which are then automatically added to the table.

A new attribute `tag` is added which provides a Lua table which can be indexed by a string representing the tag name and returns the appropriate tag (so it is essentially a wrapper around the `Gtk.TextTagTable:lookup()` method).

The following example demonstrates both capabilities:

	local tag_table = Gtk.TextTagTable {
		Gtk.TextTag { name = 'plain', color = 'blue' },
		Gtk.TextTag { name = 'error', color = 'red' },
	}

	assert(tag_table.tag.plain == tag_table:lookup('plain'))

## TreeView and related classes

`Gtk.TreeView` and related classes like `Gtk.TreeModel` are one of the most complicated objects in the whole `Gtk`. LuaGObject adds some overrides to simplify working with them.

### Gtk.TreeModel

LuaGObject supports direct indexing of treemodel instances by iterators (i.e. `Gtk.TreeIter` instances). To get a value at the specified column number, index the resulting value again with the column number. Note that although `Gtk` uses 0-based column numbers, LuaGObject remaps them to 1-based numbers, because working with 1-based arrays is much more natural for Lua.

Another extension provided by LuaGObject is the `Gtk.TreeModel:pairs([parent_iter])` method for Lua-native iteration of the model. This method returns 3 values suitable to pass to the generic `for` loop, so that standard Lua iteration protocol can be used. See the example in the next section to learn how to use this.

### Gtk.ListStore and Gtk.TreeStore

The standard `Gtk.TreeModel` implementations, `Gtk.ListStore` and `Gtk.TreeStore` extend the concept of an indexing model instance with iterators to writing values as well. Indexing resultings value with a 1-based column number allows writing individual values, while assigning a table containing column-keyed values allows assigning multiple values at once. The following example illustrates all these techniques:

	local PersonColumn = { NAME = 1, AGE = 2, EMPLOYEE = 3 }
	local store = Gtk.ListStore.new {
		[PersonColumn.NAME] = GObject.Type.STRING,
		[PersonColumn.AGE] = GObject.Type.INT,
		[PersonColumn.EMPLOYEE] = GObject.Type.BOOLEAN,
	}
	local person = store:append()
	store[person] = {
		[PersonColumn.NAME] = "John Doe",
		[PersonColumn.AGE] = 45,
		[PersonColumn.EMPLOYEE] = true,
	}
	assert(store[person][PersonColumn.AGE] == 45)
	store[person][PersonColumn.AGE] = 42
	assert(store[person][PersonColumn.AGE] == 42)

	-- Print all persons in the store
	for i, p in store:pairs() do
		print(p[PersonColumn.NAME], p[PersonColumn.AGE])
	end

Note that the `append` and `insert` methods are overridden to accept an additional parameter containing a table with column/value pairs, so the creation section of previous example can be simplified to:

	local person = store:append {
		[PersonColumn.NAME] = "John Doe",
		[PersonColumn.AGE] = 45,
		[PersonColumn.EMPLOYEE] = true,
	}

You also can use numbers or strings as indexes. A use for this is reading values selected from `Gtk.ComboBox`:

	local index = MyComboBox:get_active() -- Index is string, but numbers is also supported
	print("Active index: ", index)
	print("Selected value: ", MyStore[index])

While this example uses `Gtk.ListStore`, similar overrides are also provided for `Gtk.TreeStore`.

### Gtk.TreeView and Gtk.TreeViewColumn

LuaGObject provides a `Gtk.TreeViewColumn:set(cell, data)` method, which allows assigning either a set of `cell` renderer attribute->model column pairs (in case that `data` argument is a table), or a custom data function for a specified cell renderer (when `data` is a function). Note that the column must already have a cell renderer assigned. See `gtk_tree_view_column_set_attributes()` and `gtk_tree_view_column_set_cell_data_func()` for precise documentation.

The override `Gtk.TreeViewColumn:add(def)` combines both adding a new cell renderer and setting attributes or a data function. The `def` argument is a table, containing a cell renderer instance at index 1 and the `data` at index 2. Optionally, it can also contain an `expand` attribute (set to `true` or `false`) and `align` attribute (set either to `start` or `end`). This method is basically a combination of `gtk_tree_view_column_pack_start()` or `gtk_tree_view_column_pack_end()` and `set()` override method.

The array part of the `Gtk.TreeViewColumn` constructor call is mapped to call the `Gtk.TreeViewColumn:add()` method, and the array part of `Gtk.TreeView` constructor call is mapped to call `Gtk.TreeView:append_column()`. This allows composing the whole initialized `TreeView`s in a declarative style as shown below:

	-- This example reuses 'store' model created in examples in the
	-- Gtk.TreeModel section above.
	local view = Gtk.TreeView {
		model = store,
		Gtk.TreeViewColumn {
			title = "Name and age",
			expand = true,
			{ Gtk.CellRendererText {}, { text = PersonColumn.NAME } },
			{ Gtk.CellRendererText {}, { text = PersonColumn.AGE } },
		},
		Gtk.TreeViewColumn {
			title = "Employee",
			{ Gtk.CellRendererToggle {}, { active = PersonColumn.EMPLOYEE } }
		},
	}
