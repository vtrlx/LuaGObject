-- LGI Lua-side core.
-- Copyright (c) 2010, 2011 Pavel Holejsovsky
-- Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php

local assert, require, pcall, setmetatable, pairs, type, error, tostring,
	_VERSION, jit
		= assert, require, pcall, setmetatable, pairs, type, error, tostring,
			_VERSION, rawget(_G, 'jit')

local package = require 'package'

-- Require core LuaGObject utilities, used during bootstrap.
local core = require 'LuaGObject.core'

-- Create LuaGObject table, containing the module.
local LuaGObject = {
	_NAME = 'LuaGObject',
	_VERSION = require 'LuaGObject.version',
}

-- Forward selected core methods into external interface.
for _, name in pairs { 'yield', 'lock', 'enter', 'leave' } do
	LuaGObject[name] = core[name]
end

-- If global package 'bytes' does not exist (i.e. not provided externally), use our internal (although incomplete) implementation.
local ok, bytes = pcall(require, 'bytes')
if not ok or not bytes then
	package.loaded.bytes = core.bytes
end

-- Prepare logging support.  'log' is module-exported table, containing all functionality related to logging wrapped around GLib g_log facility.
LuaGObject.log = require 'LuaGObject.log'

-- For the rest of bootstrap, prepare logging to LuaGObject domain.
local log = LuaGObject.log.domain('LuaGObject')

-- Repository, table with all loaded namespaces.  Its metatable takes care of loading on-demand.  Created by C-side bootstrap.
local repo = core.repo

local namespace = require 'LuaGObject.namespace'
LuaGObject.require = namespace.require

-- Install 'LuaGObject.package' method.
LuaGObject.package = require('LuaGObject.package').ensure

-- Add assert override, which accepts not only text message but any kind of error object.
function LuaGObject.assert(cond, ...)
	if cond then return cond, ... end
	local err = ...
	if _VERSION == 'Lua 5.1' and not jit then
		-- Lua 5.1 does not support displaying message of non-string
		-- errors on the commandline interpreter, so better stringize
		-- the error message right now.
		err = tostring(err)
	end
	error(err, 2)
end

-- Install metatable into repo table, so that on-demand loading works.
setmetatable(repo, {
	__index = function(_, name)
		return LuaGObject.require(name)
	end,
})

-- Create lazy-loading components for base gobject entities.
assert(core.gi.require ('GLib', '2.0'))
assert(core.gi.require ('GObject', '2.0'))
repo.GObject._precondition = {}
for _, name in pairs { 'Type', 'Value', 'Closure', 'Object' } do
	repo.GObject._precondition[name] = 'GObject-' .. name
end
repo.GObject._precondition.InitiallyUnowned = 'GObject-Object'

-- Create lazy-loading components for GLib primitives.
repo.GLib._precondition = {}
repo.GLib._precondition.Error = 'GLib-Error'
repo.GLib._precondition.Bytes = 'GLib-Bytes'
repo.GLib._precondition.Timer = 'GLib-Timer'
repo.GLib._precondition.MarkupParser = 'GLib-Markup'
repo.GLib._precondition.MarkupParseContext = 'GLib-Markup'
repo.GLib._precondition.Source = 'GLib-Source'
repo.GLib._precondition.SourceFuncs = 'GLib-Source'
for _, name in pairs { 'Variant', 'VariantType', 'VariantBuilder' } do
	repo.GLib._precondition[name] = 'GLib-Variant'
end

-- Access to module proxies the whole repo, so that LuaGObject.'namespace' notation works.
return setmetatable(LuaGObject, { __index = repo })
