-- LuaGObject Test Suite, Adwaita test group.
-- Copyright © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license. See http://www.opensource.org/licenses/mit-license.php for more information.

local io = require "io"
local os = require "os"
local LuaGObject = require "LuaGObject"

if LuaGObject.Gtk.get_major_version() ~= 4 then
	-- Adwaita 1.0 requires GTK 4. If the GTK isn't version 4, Adwaita cannot be loaded, the test cannot be done, so simply return.
	return
end
assert(LuaGObject.Adw.get_major_version() == 1)

local check, checkv = testsuite.check, testsuite.checkv
local adw = testsuite.group.new "adw"

function adw.prefsdialog()
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

function adw.actionrow()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local actionrow = Adw.ActionRow {
		-- If this doesn't crash, then it's assumed the override is working.
		prefixes = Gtk.Button.new_with_label "prefix button",
		suffixes = Gtk.Button.new_with_label "suffix button",
	}
end

function adw.headerbar()
	local Adw, Gtk = LuaGObject.Adw, LuaGObject.Gtk
	local headerbar = Adw.HeaderBar {
		-- If this doesn't crash, then it's assumed the override is working.
		start_packs = Gtk.Button.new_with_label "start button",
		end_packs = Gtk.Button.new_with_label "end button",
	}
end
