-- LuaGObject Gtk overrides
-- © 2025 Victoria Lacroix
-- Licensed under the terms of an MIT license: http://www.opensource.org/licenses/mit-license.php

local LuaGObject = require 'LuaGObject'
local Gtk = LuaGObject.Gtk

if Gtk.get_major_version() <= 3 then
   return require 'LuaGObject.override.Gtk3'
elseif Gtk.get_major_version() == 4 then
   return require 'LuaGObject.override.Gtk4'
elseif Gtk.get_major_version() > 4 then
   -- No override for Gtk5 or later… yet.
   return
end
