-- LuaGObject Gtk4 overrides
-- © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license: http://www.opensource.org/licenses/mit-license.php

local LuaGObject = require "LuaGObject"
local Gtk = LuaGObject.Gtk
local Gdk = LuaGObject.Gdk

local log = LuaGObject.log.domain "LuaGObject.Gtk4"

assert(Gtk.get_major_version() == 4)

-- Initialize GTK.
Gtk.disable_setlocale()
if not Gtk.init_check() then
    return "gtk_init_check() failed"
end

-- Gtk.Allocation overrides --

-- Gtk.Allocation internally aliases to Gdk.Rectangle, so let's alias here as well.
Gtk.Allocation = Gdk.Rectangle

-- Gtk.Widget overrides --

Gtk.Widget._attribute = {
	width = { get = Gtk.Widget.get_allocated_width },
	height = { get = Gtk.Widget.get_allocated_height },
	children = {},
}

-- Allow to query a widget's currently-allocated dimensions by indexing .width or .height, and set the requested dimensions by assigning these pseudo-properties.
function Gtk.Widget._attribute.width:set(width)
	self.width_request = width
end
function Gtk.Widget._attribute.height:set(height)
	self.height_request = height
end

-- Access children by index. [1] returns the first child, [2] returns the second, [-1] returns the last, [-2] returns the second-last. If no child exists at the given index, returns nil.
local widget_children_mt = {}
function widget_children_mt:__index(key)
	if type(key) ~= "number" then
		error("%s: cannot access child at non-numeric index", self._widget.type.name)
	end
	local child
	if key == 0 then
		return nil
	elseif key < 0 then
		child = self._widget:get_last_child()
		for i = 2, -key do
			if not child then return end
			child = child:get_prev_sibling()
		end
	else
		child = self._widget:get_first_child()
		for i = 2, key do
			if not child then return end
			child = child:get_next_sibling()
		end
	end
	return child
end

function widget_children_mt:__newindex()
	error("%s: child widgets cannot be assigned", self._widget.type.name)
end

function Gtk.Widget._attribute.children:get()
	return setmetatable({ _widget = self }, widget_children_mt)
end

-- Constructor container support --

Gtk.Box._container_add = Gtk.Box._method.append
Gtk.FlowBox._container_add = Gtk.FlowBox._method.append
Gtk.ListBox._container_add = Gtk.ListBox._method.append
Gtk.Stack._container_add = Gtk.Stack._method.add_child
