-- LuaGObject Test Suite, Adwaita test group.
-- Copyright © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license. See http://www.opensource.org/licenses/mit-license.php for more information.

local LuaGObject = require "LuaGObject"

if LuaGObject.Gtk.get_major_version() ~= 4 then
	-- Adwaita 1.0 requires GTK 4. If the GTK isn't version 4, Adwaita cannot be loaded, the test cannot be done, so simply return.
	return
end
assert(LuaGObject.Adw.get_major_version() == 1)

local check, checkv = testsuite.check, testsuite.checkv
local adw = testsuite.group.new "adw"

function adw.prefsdialog_container()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local label = Gtk.Label()
	local dialog = Adw.PreferencesDialog {
		title = "Dialog",
		Adw.PreferencesPage {
			title = "Page",
			Adw.PreferencesGroup {
				title = "Group",
				Adw.ExpanderRow {
					title = "ExpanderRow",
					label,
				}
			}
		},
	}
	-- Checking the children through the children API is inadvisable, because Adw inserts a handful children into the mix to make the widget pretty.
	local visible_page = dialog.visible_page
	check(Adw.PreferencesPage:is_type_of(visible_page))
	-- Adw.PreferencesPage has :get_group only from v1.8 or later, which is not available in Ubuntu 24.04 LTS. This means, it's difficult to test conclusively in CI whether the container portion of the override works. Instead, it'll be assumed that if children can be added through the container override, it must be working.
end

function adw.carousel_container()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local carousel = Adw.Carousel {
		label1,
		label2,
		label3,
	}
	check(carousel:get_nth_page(0) == label1)
	check(carousel:get_nth_page(1) == label2)
	check(carousel:get_nth_page(2) == label3)
	check(not carousel:get_nth_page(3))
end

function adw.tabview_container()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local tabview = Adw.TabView {
		label1,
		label2,
		{ label3, title = "Tab 3" },
	}
	check(tabview:get_nth_page(0).child == label1)
	check(tabview:get_nth_page(1).child == label2)
	check(tabview:get_nth_page(2).child == label3)
	check(not tabview:get_nth_page(3))
end

function adw.viewstack_container()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local label1 = Gtk.Label()
	local label2 = Gtk.Label()
	local label3 = Gtk.Label()
	local viewstack = Adw.ViewStack {
		{ label1, name = "view1" },
		{ label2, name = "view2", title = "View 2" },
		{
			label3,
			name = "view3",
			title = "View 3",
			icon_name = "emblem-system-symbolic",
		},
	}
	check(viewstack:get_child_by_name "view1" == label1)
	check(viewstack:get_child_by_name "view2" == label2)
	check(viewstack:get_child_by_name "view3" == label3)

end

function adw.actionrow_childattrs()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local actionrow = Adw.ActionRow {
		-- If this doesn't crash, then it's assumed the override is working.
		prefixes = Gtk.Button.new_with_label "prefix button",
		suffixes = Gtk.Button.new_with_label "suffix button",
	}
end

function adw.headerbar_childattrs()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local headerbar = Adw.HeaderBar {
		-- If this doesn't crash, then it's assumed the override is working.
		start_packs = Gtk.Button.new_with_label "start button",
		end_packs = Gtk.Button.new_with_label "end button",
	}
end
