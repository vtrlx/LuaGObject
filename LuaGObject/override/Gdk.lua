------------------------------------------------------------------------------
--
--  LGI Gdk3 override module.
--
--  Copyright (c) 2011, 2014 Pavel Holejsovsky
--  Licensed under the MIT license:
--  http://www.opensource.org/licenses/mit-license.php
--
------------------------------------------------------------------------------

local select, type, pairs, unpack, rawget = select, type, pairs, unpack, rawget

local LuaGObject = require 'LuaGObject'

local core = require 'LuaGObject.core'
local ffi = require 'LuaGObject.ffi'
local ti = ffi.types

local Gdk = LuaGObject.Gdk
local cairo = LuaGObject.cairo

-- Take over internal GDK synchronization lock in Gdk3.
-- This API does not exist in Gdk4.
if core.gi.Gdk.resolve.gdk_threads_set_lock_functions then
   core.registerlock(core.gi.Gdk.resolve.gdk_threads_set_lock_functions)
   Gdk.threads_init()
end

-- Gdk.Rectangle does not exist at all in older GOI, because it is
-- aliased to cairo.RectangleInt.  Make sure that we have it exists,
-- because it is very commonly used in API documentation.
if not Gdk.Rectangle then
   Gdk.Rectangle = LuaGObject.cairo.RectangleInt
   Gdk.Rectangle._method = rawget(Gdk.Rectangle, '_method') or {}
   Gdk.Rectangle._method.intersect = Gdk.rectangle_intersect
   Gdk.Rectangle._method.union = Gdk.rectangle_union
end

-- Declare GdkAtoms which are #define'd in Gdk3 sources and not
-- introspected in gir.
if Gdk.Atom then
   local _ = Gdk.KEY_0
   for name, val in pairs {
      SELECTION_PRIMARY = 1,
      SELECTION_SECONDARY = 2,
      SELECTION_CLIPBOARD = 69,
      TARGET_BITMAP = 5,
      TARGET_COLORMAP = 7,
      TARGET_DRAWABLE = 17,
      TARGET_PIXMAP = 20,
      TARGET_STRING = 31,
      SELECTION_TYPE_ATOM = 4,
      SELECTION_TYPE_BITMAP = 5,
      SELECTION_TYPE_COLORMAP = 7,
      SELECTION_TYPE_DRAWABLE = 17,
      SELECTION_TYPE_INTEGER = 19,
      SELECTION_TYPE_PIXMAP = 20,
      SELECTION_TYPE_WINDOW = 33,
      SELECTION_TYPE_STRING = 31,
   } do Gdk._constant[name] = Gdk.Atom(val) end
end

-- Easier-to-use Gdk.RGBA.parse() override.
if Gdk.RGBA then
    local parse = Gdk.RGBA.parse
    function Gdk.RGBA.parse(arg1, arg2)
       if Gdk.RGBA:is_type_of(arg1) then
          -- Standard member method.
          return parse(arg1, arg2)
       else
          -- Static constructor variant.
          local rgba = Gdk.RGBA()
          return parse(rgba, arg1) and rgba or nil
       end
    end
end

-- Gdk.Window.destroy() actually consumes 'self'.  Prepare workaround
-- with override doing ref on input arg first.
if Gdk.Window then
   local destroy = Gdk.Window.destroy
   local ref = core.callable.new {
      addr = core.gi.GObject.resolve.g_object_ref,
      ret = ti.ptr, ti.ptr
   }
   function Gdk.Window:destroy()
      ref(self._native)
      destroy(self)
   end
end

-- Better integrate Gdk cairo helpers.
if Gdk.Window then
   Gdk.Window.cairo_create = Gdk.cairo_create
end
cairo.Region.create_from_surface = Gdk.cairo_region_create_from_surface

local cairo_set_source_rgba = cairo.Context.set_source_rgba
function cairo.Context:set_source_rgba(...)
   if select('#', ...) == 1 then
      return Gdk.cairo_set_source_rgba(self, ...)
   else
      return cairo_set_source_rgba(self, ...)
   end
end

local cairo_rectangle = cairo.Context.rectangle
function cairo.Context:rectangle(...)
   if select('#', ...) == 1 then
      return Gdk.cairo_rectangle(self, ...)
   else
      return cairo_rectangle(self, ...)
   end
end

for _, name in pairs { 'get_clip_rectangle', 'set_source_color',
		       'set_source_pixbuf', 'set_source_window',
		       'region' } do
   cairo.Context._method[name] = Gdk['cairo_' .. name]
end
for _, name in pairs { 'clip_rectangle', 'source_color', 'source_pixbuf',
		       'source_window' } do
   cairo.Context._attribute[name] = {
      get = cairo.Context._method['get_' .. name],
      set = cairo.Context._method['set_' .. name],
   }
end

-- Gdk events have strange hierarchy; GdkEvent is union of all known
-- GdkEventXxx specific types.  This means that generic gdk_event_xxx
-- methods are not available on GdkEventXxxx specific types.  Work
-- around this by setting GdkEvent as parent for GdkEventXxxx specific
-- types.
for _, event_type in pairs {
   'Any', 'Expose', 'Visibility', 'Motion', 'Button', 'Touch', 'Scroll', 'Key',
   'Crossing', 'Focus', 'Configure', 'Property', 'Selection', 'OwnerChange',
   'Proximity', 'DND', 'WindowState', 'Setting', 'GrabBroken' } do
   local event = Gdk['Event' .. event_type]
   if event then
      event._parent = Gdk.Event
   end
end
