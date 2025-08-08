-- LuaGObject Adw (libadwaita) overrides
-- © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license: http://www.opensource.org/licenses/mit-license.php

local LuaGObject = require "LuaGObject"
local Adw = LuaGObject.Adw
local Gtk = LuaGObject.Gtk

local log = LuaGObject.log.domain "LuaGObject.Adw"

-- Constructor container support --

Adw.PreferencesDialog._container_add = Adw.PreferencesDialog._method.add
Adw.PreferencesPage._container_add = Adw.PreferencesPage._method.add
Adw.PreferencesGroup._container_add = Adw.PreferencesGroup._method.add
Adw.ExpanderRow._container_add = Adw.ExpanderRow.add_row

-- These classes were introduced in later versions of Adw, and thus may not always be available.
if Adw.WrapBox then
	Adw.WrapBox._container_add = Adw.WrapBox._method.append
end
if Adw.ShortcutsDialog then
	Adw.ShortcutsDialog._container_add = Adw.ShortcutsDialog.add
end
if Adw.ShortcutsSection then
	Adw.ShortcutsSection._container_add = Adw.ShortcutsSection.add
end

-- Adw.ActionRow overrides --

Adw.ActionRow._attribute = {
	prefixes = {},
	suffixes = {},
}

function Adw.ActionRow._attribute.prefixes:get()
	error("%s: Cannot read prefixes; attribute is write-only.", self.type.name)
end
function Adw.ActionRow._attribute.prefixes:set(value)
	if Gtk.Widget:is_type_of(value) then
		value = { value }
	end
	if type(value) ~= "table" then
		error("%s: Can only write table or Gtk.Widget to add_prefixes.", self.type.name)
	end
	for _, c in ipairs(value) do
		self:add_prefix(c)
	end
end

function Adw.ActionRow._attribute.suffixes:get()
	error("%s: Cannot read suffixes; attribute is write-only.", self.type.name)
end
function Adw.ActionRow._attribute.suffixes:set(value)
	if Gtk.Widget:is_type_of(value) then
		value = { value }
	end
	if type(value) ~= "table" then
		error("%s: Can only write table or Widget to add_suffixes.", self.type.name)
	end
	for _, v in ipairs(value) do
		self:add_suffix(v)
	end
end

-- Adw.HeaderBar overrides --

Adw.HeaderBar._attribute = {
	end_packs = {},
	start_packs = {},
}

function Adw.HeaderBar._attribute.end_packs:get()
	error("%s: Cannot read end_packs; attribute is write-only.", self.type.name)
end
function Adw.HeaderBar._attribute.end_packs:set(value)
	if Gtk.Widget:is_type_of(value) then
		value = { value }
	end
	if type(value) ~= "table" then
		error("%s: Can only write table or Widget to end_packs.", self.type.name)
	end
	for _, v in ipairs(value) do
		self:pack_end(v)
	end
end

function Adw.HeaderBar._attribute.start_packs:get()
	error("%s: Cannot read start_packs; attribute is write-only.", self.type.name)
end
function Adw.HeaderBar._attribute.start_packs:set(value)
	if Gtk.Widget:is_type_of(widget) then
		value = { value }
	end
	if type(value) ~= "table" then
		error("%s: Can only write table or Widget to start_packs.", self.type.name)
	end
	for _, v in ipairs(value) do
		self:pack_start(v)
	end
end

-- Adw.ToolbarView overrides --

-- Adw.ToolbarView was introduced in Adw 1.4, and may not be available.
if Adw.ToolbarView then
	Adw.ToolbarView._attribute = {
		bottom_bars = {},
		top_bars = {},
	}

	function Adw.ToolbarView._attribute.bottom_bars:get()
		error("%s: Cannot read bottom_bars; attribute is write-only.", self.type.name)
	end
	function Adw.ToolbarView._attribute.bottom_bars:set(value)
		if Gtk.Widget:is_type_of(value) then
			value = { value }
		end
		if type(value) ~= "table" then
			error("%s: Can only write table or Gtk.Widget to add_bottom_bars.", self.type.name)
		end
		for _, v in ipairs(values) do
			self:add_bottom_bar(v)
		end
	end

	function Adw.ToolbarView._attribute.top_bars:get()
		error("%s: Cannot read top_bars; attribute is write-only.", self.type.name)
	end
	function Adw.ToolbarView._attribute.top_bars:set(value)
		if Gtk.Widget:is_type_of(value) then
			value = { value }
		end
		if type(value) ~= "table" then
			error("%s: Can only write table or Gtk.Widget to add_top_bars.", self.type.name)
		end
		for _, v in ipairs(value) do
			self:add_top_bar(v)
		end
	end
end
