-- LuaGObject Test Suite, GTK 4 test group.
-- Copyright © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license. See http://www.opensource.org/licenses/mit-license.php for more information.

local LuaGObject = require "LuaGObject"

if LuaGObject.Gtk.get_major_version() ~= 4 then
	-- The latest available version of GTK isn't GTK 4, so this test cannot be done.
	return
end

local check, checkv = testsuite.check, testsuite.checkv
local gtk = testsuite.group.new "gtk"

function gtk.dimensions()
	local Gtk = LuaGObject.Gtk
	local box = Gtk.Box()
	box.width = 600
	box.height = 600
	check(box.width_request == 600)
	check(box:get_allocated_width() == box.width)
	check(box.height_request == 600)
	check(box:get_allocated_height() == box.height)
end

function gtk.children()
	local Gtk = LuaGObject.Gtk
	local box = Gtk.Box()
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	box:append(label1)
	box:append(label2)
	box:append(label3)
	check(box.children[1] == label1)
	check(box.children[2] == label2)
	check(box.children[3] == label3)
end

function gtk.box_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local box = Gtk.Box {
		label1,
		label2,
		label3,
	}
	check(box.children[1] == label1)
	check(box.children[2] == label2)
	check(box.children[3] == label3)
end

function gtk.flowbox_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local flowbox = Gtk.FlowBox {
		label1,
		label2,
		label3,
	}
	check(flowbox.children[1].child == label1)
	check(flowbox.children[2].child == label2)
	check(flowbox.children[3].child == label3)
end

function gtk.listbox_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local listbox = Gtk.ListBox {
		label1,
		label2,
		label3,
	}
	check(listbox.children[1].child == label1)
	check(listbox.children[2].child == label2)
	check(listbox.children[3].child == label3)
end

function gtk.stack_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local stack = Gtk.Stack {
		label1,
		label2,
		label3,
	}
	check(stack.children[1] == label1)
	check(stack.children[2] == label2)
	check(stack.children[3] == label3)
end

function gtk.grid_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local grid = Gtk.Grid {
		{ label1, column = 1, row = 1 },
		{ label2, column = 3, row = 2 },
		{ label3, column = 2, row = 3 },
	}
	check(grid:get_child_at(1, 1) == label1)
	check(grid:get_child_at(3, 2) == label2)
	check(grid:get_child_at(2, 3) == label3)
	check(not grid:get_child_at(2, 2))
end

function gtk.notebook_container()
	local Gtk = LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local notebook = Gtk.Notebook {
		{ label1, tab_label = "Tab 1" },
		{
			label2,
			tab_label = Gtk.Label { label = "Tab 2" },
		},
		{
			label3,
			tab_label = Gtk.Label { label = "Tab 3" },
			menu_label = Gtk.MenuButton(),
		},
	}
	check(notebook:get_nth_page(0) == label1)
	check(notebook:get_nth_page(1) == label2)
	check(notebook:get_nth_page(2) == label3)
end

function gtk.extra_css_classes()
	local Gtk = LuaGObject.Gtk
	local box = Gtk.Box {
		orientation = "VERTICAL",
		extra_css_classes = { "linked" },
	}
	check(box:has_css_class "linked")
	-- The .vertical CSS class comes from setting the orientation to vertical. By checking it here, the test ensures that the existing class isn't overwritten by extra_css_classes.
	check(box:has_css_class "vertical")
end
