-- LuaGObject Gtk4 overrides
-- © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license: http://www.opensource.org/licenses/mit-license.php

local LuaGObject = require 'LuaGObject'
local core = require 'LuaGObject.core'
local Gtk = LuaGObject.Gtk
local Gdk = LuaGObject.Gdk
local GObject = LuaGObject.GObject
local cairo = LuaGObject.cairo

local log = LuaGObject.log.domain('LuaGObject.Gtk4')

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
	child = {},
}

-- Allow to query a widget's currently-allocated dimensions by indexing .width or .height, and set the requested dimensions by assigning these pseudo-properties.
function Gtk.Widget._attribute.width:set(width)
	self.width_request = width
end
function Gtk.Widget._attribute.height:set(height)
	self.height_request = height
end

-- Access children by index. [1] returns the first child, [2] returns the second, [-1] returns the last, [-2] returns the second-last. If no child exists at the given index, returns nil.
local widget_child_mt = {}
function widget_child_mt:__index(key)
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

function widget_child_mt:__newindex()
	error("%s: cannot assign child", self._widget.type.name)
end

function Gtk.Widget._attribute.child:get()
	return setmetatable({ _widget = self }, widget_child_mt)
end

-- Gtk.Box overrides --

Gtk.Box._attribute = {
	child = {},
}

function Gtk.Box:add(widget, props)
	if type(widget) == "table" or props then
		error("%s:add(): Gtk4 does not support child properties", self.type.name)
	end
	self:append(widget)
end

-- Make Gtk.Box:add() available to constructors
Gtk.Box._container_add = Gtk.Box.add

-- Access a Gtk.Box's children as usual. If assigning a child by number, it will replace the widget at the given index.
local box_child_mt = { __index = widget_child_mt.__index }
function box_child_mt:__newindex(key, child)
	if type(key) ~= "number" or key == 0 then
		error("%s: cannot write to index %q", self._widget.type.name, key)
	end
	local sibling = self[key]
	if not Gtk.Widget:is_type_of(child) then
		error("%s: attempt to insert non-widget child", self._widget.type.name)
	elseif not sibling and key > 0 then
		self._widget:append(child)
	elseif not sibling and key < 0 then
		self._widget:prepend(child)
	else
		self._widget:insert_child_after(child, sibling)
		self._widget:remove(sibling)
	end
end

function Gtk.Box._attribute.child:get()
	return setmetatable({ _widget = self }, box_child_mt)
end

-- Gtk.FlowBox overrides --

function Gtk.FlowBox:add(widget, props)
	if type(widget) == "table" or props then
		error("%s:add(): Gtk4 does not support child properties", self.type.name)
	end
	self:append(widget)
end

-- Make Gtk.FlowBox:add() available to constructors.
Gtk.FlowBox._container_add = Gtk.FlowBox.add

-- Gtk.ListBox overrides --

function Gtk.ListBox:add(widget, props)
	if type(widget) == "table" or props then
		error("%s:add(): Gtk4 does not support child properties", self.type.name)
	end
	self:append(widget)
end

-- Make Gtk.ListBox:add() available to constructors.
Gtk.ListBox._container_add = Gtk.ListBox.add

-- Gtk.Stack overrides --

function Gtk.Stack:add(widget, props)
	if type(widget) == "table" or props then
		error("%s:add(): Gtk4 does not support child properties", self.type.name)
	end
	self:add_child(widget)
end

-- Make Gtk.Stack:add() available to Gtk.Stack's constructor.
Gtk.Stack._container_add = Gtk.Stack.add
