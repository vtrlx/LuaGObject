#!/usr/bin/env lua

local core = require 'LuaGObject.core'

local args = { ... }

local output_path = 'meta/LuaGObject.lua'
local namespace_specs = {}
local primary_namespace
local skip_dependencies = false
local compact_spacing = false

local i = 1
while i <= #args do
   local val = args[i]
   if val == '--output' then
      i = i + 1
      output_path = args[i]
   elseif val == '--namespace' then
      i = i + 1
      namespace_specs[#namespace_specs + 1] = args[i]
   elseif val == '--skip-deps' then
      skip_dependencies = true
   elseif val == '--compact' then
      compact_spacing = true
   else
      namespace_specs[#namespace_specs + 1] = val
   end
   i = i + 1
end

if #namespace_specs == 0 then
   io.stderr:write('usage: ', arg[0], ' [--output <path>] [--skip-deps] [--compact] <Namespace[-Version]>...\n')
   os.exit(1)
end

local function parse_namespace_spec(spec)
   if not spec then return nil end
   local name, version = spec:match('^([%w_]+)[%-%:@](.+)$')
   if not name then
      name = spec
   end
   if version == '' then version = nil end
   return name, version
end

local lua_keywords = {
   'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
   'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
   'true', 'until', 'while',
}

local keyword_lookup = {}
for _, kw in ipairs(lua_keywords) do
   keyword_lookup[kw] = true
end

local function is_keyword(name)
   return keyword_lookup[name] == true
end

local function is_valid_identifier(name)
   return type(name) == 'string'
      and name:match('^[A-Za-z_][%w_]*$') ~= nil
      and not is_keyword(name)
end

local function sanitize_identifier(name, fallback)
   if not name or name == '' then
      return fallback or 'value'
   end
   local sanitized = name:gsub('[^%w_]', '_')
   if sanitized == '' then
      sanitized = fallback or 'value'
   end
   if sanitized:match('^%d') then
      sanitized = '_' .. sanitized
   end
    if is_keyword(sanitized) then
       sanitized = '_' .. sanitized
    end
   return sanitized
end

local function make_namespace_var_name(namespace)
   if is_valid_identifier(namespace) then
      return namespace
   end
   return sanitize_identifier(namespace, 'ns')
end

local function format_field_annotation_name(name)
   if is_valid_identifier(name) then
      return name
   end
   return ('[%q]'):format(name)
end

local function format_table_key(name)
   if is_valid_identifier(name) then
      return name
   end
   return ('[%q]'):format(name)
end

local function format_table_access(base, name)
   if is_valid_identifier(name) then
      return base .. '.' .. name
   end
   return base .. ('[%q]'):format(name)
end

local function format_qualified_name(namespace, name)
   if not namespace or namespace == '' then
      return format_field_annotation_name(name)
   end
   if is_valid_identifier(name) then
      return namespace .. '.' .. name
   end
   return namespace .. ('[%q]'):format(name)
end

local namespaces = {}
local queue = {}

local function enqueue_namespace(name, version, force)
   if not name then return end
   local existing = namespaces[name]

   if skip_dependencies and not force then
      if not existing then
         namespaces[name] = { version = version, skipped = true }
      elseif version and not existing.version then
         existing.version = version
      end
      return
   end

   if not existing or existing.skipped then
      local new_version = version or (existing and existing.version) or nil
      namespaces[name] = { version = new_version }
      queue[#queue + 1] = name
      if os.getenv('LUA_GOBJECT_META_DEBUG') then
         io.stderr:write('Enqueued namespace: ' .. name .. (version and (' ' .. version) or '') .. '\n')
      end
   elseif version and not existing.version then
      existing.version = version
   end
end

if not skip_dependencies then
   enqueue_namespace('GLib', nil, true)
   enqueue_namespace('GObject', nil, true)
end

for _, spec in ipairs(namespace_specs) do
   local name, version = parse_namespace_spec(spec)
   if not name then
      io.stderr:write('invalid namespace spec: ', spec, '\n')
      os.exit(1)
   end
   if not primary_namespace then
      primary_namespace = name
   end
   enqueue_namespace(name, version, true)
end

local processed = {}
local namespace_data = {}
local process_order = {}

local unknown_tags = {}

local type_to_string
local ensure_type_dependencies
local collect_callable
local build_callable_signature
local emit_object
local emit_interface
local emit_struct
local emit_union
local emit_enum
local emit_flags
local emit_callback
local emit_function
local emit_constant

local function add_nil(type_str)
   if not type_str or type_str == '' then
      return 'nil'
   end
   if type_str == 'any' then
      return type_str
   end
   if type_str:find('nil') then
      return type_str
   end
   return type_str .. '|nil'
end

local function needs_paren(type_str)
   return type_str:find('[%s|,]') ~= nil
end

local function as_array(type_str)
   if needs_paren(type_str) then
      return '(' .. type_str .. ')[]'
   end
   return type_str .. '[]'
end

type_to_string = function(ti, context)
   if not ti then return 'any' end
   local tag = ti.tag
   if not tag then return 'any' end

   if tag == 'void' then
      return context == 'return' and 'nil' or 'any'
   end
   if tag == 'boolean' or tag == 'gboolean' then
      return 'boolean'
   end
   if tag == 'utf8' or tag == 'filename' then
      return 'string'
   end
   if tag == 'gunichar' or tag == 'unichar' then
      return 'integer'
   end
   if tag == 'char' or tag == 'uchar' or tag == 'int' or tag == 'uint'
      or tag == 'long' or tag == 'ulong' or tag == 'short' or tag == 'ushort'
      or tag == 'size' or tag == 'ssize' or tag == 'gint' or tag == 'guint'
      or tag == 'gsize' or tag == 'gssize' or tag == 'gshort' or tag == 'gushort'
      or tag == 'gchar' or tag == 'guchar' or tag:match('^g?u?int%d+$') then
      return 'integer'
   end
   if tag == 'float' or tag == 'double' or tag == 'gfloat' or tag == 'gdouble' then
      return 'number'
   end
   if tag == 'error' then
      enqueue_namespace('GLib')
      return format_qualified_name('GLib', 'Error')
   end
   if tag == 'GType' then
      enqueue_namespace('GObject')
      return format_qualified_name('GObject', 'Type')
   end
   if tag == 'gpointer' or tag == 'pointer' then
      return 'userdata'
   end

   if tag == 'interface' then
      local iface = ti.interface
      if not iface then return 'any' end
      local ns = iface.namespace or ''
      if ns ~= '' then
         enqueue_namespace(ns)
      end
      if iface.type == 'callback' then
         return build_callable_signature(iface)
      else
         return format_qualified_name(ns, iface.name)
      end
   elseif tag == 'array' then
      local params = ti.params
      local element_type = 'any'
      if params and params[1] then
         element_type = type_to_string(params[1], context)
      end
      return as_array(element_type)
   elseif tag == 'ghash' then
      local params = ti.params
      local key_type = params and params[1] and type_to_string(params[1], context) or 'any'
      local value_type = params and params[2] and type_to_string(params[2], context) or 'any'
      return ('table<%s, %s>'):format(key_type, value_type)
   elseif tag == 'gslist' or tag == 'glist' then
      local params = ti.params
      local element_type = params and params[1] and type_to_string(params[1], context) or 'any'
      return as_array(element_type)
   end

   unknown_tags[tag] = true
   return 'any'
end

collect_callable = function(info, opts)
   opts = opts or {}
   local params = {}
   local returns = {}
   local args = info.args or {}
   local hidden = {}

   for idx = 1, #args do
      local arg = args[idx]
      local ti = arg.typeinfo
      if ti and ti.tag == 'array' and ti.array_type == 'c' then
         local length_index = ti.array_length
         if length_index and length_index >= 0 then
            hidden[length_index + 1] = true
         end
      end
   end

   local function add_param_record(list, record)
      list[#list + 1] = record
   end

   for idx = 1, #args do
      if not hidden[idx] then
         local arg = args[idx]
         local dir = arg.direction or 'in'
         local name = sanitize_identifier(arg.name, 'arg' .. idx)
         local ti = arg.typeinfo
         local type_str = type_to_string(ti, dir == 'in' and 'param' or 'return')
         local optional = arg.optional or false

         if optional then
            type_str = add_nil(type_str)
         end

         if dir == 'in' or dir == 'inout' then
            add_param_record(params, { name = name, type = type_str, optional = optional })
         end

         if dir ~= 'in' then
            add_param_record(returns, { name = name, type = type_to_string(ti, 'return') })
         end
      end
   end

   local ret_ti = info.return_type
   local ret_type = type_to_string(ret_ti, 'return')
   if ret_type and ret_type ~= 'nil' then
      table.insert(returns, 1, { name = sanitize_identifier(info.return_name, 'result'), type = ret_type })
   end

   return params, returns
end

build_callable_signature = function(info, opts)
   local params, returns = collect_callable(info, opts)
   local param_parts = {}
   for _, param in ipairs(params) do
      param_parts[#param_parts + 1] = ("%s: %s"):format(param.name, param.type)
   end
   local signature = ('fun(%s)'):format(table.concat(param_parts, ', '))
   if #returns > 0 then
      local ret_parts = {}
      for _, ret in ipairs(returns) do
         ret_parts[#ret_parts + 1] = ret.type
      end
      signature = signature .. ': ' .. table.concat(ret_parts, ', ')
   end
   return signature, params, returns
end

ensure_type_dependencies = function(ti)
   if not ti then return end
   local tag = ti.tag
   if not tag then return end

   if tag == 'interface' then
      local iface = ti.interface
      if iface then
         local ns = iface.namespace
         if ns then
            enqueue_namespace(ns)
         end
         if iface.type == 'callback' then
            if iface.args then
               for i = 1, #iface.args do
                  ensure_type_dependencies(iface.args[i].typeinfo)
               end
            end
            ensure_type_dependencies(iface.return_type)
         end
      end
   elseif tag == 'array' or tag == 'gslist' or tag == 'glist' or tag == 'ghash' then
      local params = ti.params
      if params then
         for idx = 1, #params do
            ensure_type_dependencies(params[idx])
         end
      end
   elseif tag == 'error' then
      enqueue_namespace('GLib')
   end
end


local function add_namespace_field(ns_entry, name, type_str)
   if not name or name == '' or not type_str then return end
   local fields = ns_entry.fields
   if not fields[name] then
      fields[name] = type_str
      ns_entry.field_order[#ns_entry.field_order + 1] = name
   end
end

local function scan_callable_dependencies(callable)
   if callable.return_type then
      ensure_type_dependencies(callable.return_type)
   end
   local args = callable.args
   if args then
      for i = 1, #args do
         ensure_type_dependencies(args[i].typeinfo)
      end
   end
end

local function format_param_annotation(param)
   if param.optional then
      local type_str = param.type
      local parts = {}
      local changed = false
      for part in type_str:gmatch('[^|]+') do
         local trimmed = part:gsub('^%s+', ''):gsub('%s+$', '')
         if trimmed ~= 'nil' then
            parts[#parts + 1] = trimmed
         else
            changed = true
         end
      end
      if changed then
         type_str = table.concat(parts, '|')
         if type_str == '' then
            type_str = 'any'
         end
      end
      return ('---@param %s? %s'):format(param.name, type_str)
   end
   return ('---@param %s %s'):format(param.name, param.type)
end

local function format_returns(returns)
   if #returns == 0 then return nil end
   local parts = {}
   for _, ret in ipairs(returns) do
      if ret.name and ret.name ~= '' then
         parts[#parts + 1] = ret.type .. ' ' .. ret.name
      else
         parts[#parts + 1] = ret.type
      end
   end
   return '---@return ' .. table.concat(parts, ', ')
end

local function collect_annotations(list, transformer)
   local acc = {}
   if list then
      for i = 1, #list do
         local name, type_str = transformer(list[i], i)
         if name and type_str then
            acc[#acc + 1] = { name = name, type = type_str }
         end
      end
   end
   table.sort(acc, function(a, b) return a.name < b.name end)
   return acc
end

local function add_blank_line(lines)
   if not compact_spacing then
      lines[#lines + 1] = ''
   end
end

local function emit_methods_for_type(lines, type_access, methods, self_type)
   if not methods then return end
   for i = 1, #methods do
      local method = methods[i]
      local flags = method.flags or {}
      local _, params, returns = build_callable_signature(method)

      if flags.is_method and not is_valid_identifier(method.name) then
         local has_self = false
         for _, param in ipairs(params) do
            if param.name == 'self' then
               has_self = true
               break
            end
         end
         if not has_self then
            table.insert(params, 1, {
               name = 'self',
               type = self_type or 'any',
               optional = false,
            })
         end
      end

      local param_annotations = {}
      for _, param in ipairs(params) do
         param_annotations[#param_annotations + 1] = format_param_annotation(param)
      end
      local return_annotation = format_returns(returns)

      for _, annotation in ipairs(param_annotations) do
         lines[#lines + 1] = annotation
      end
      if return_annotation then
         lines[#lines + 1] = return_annotation
      end

      local arg_names = {}
      for _, param in ipairs(params) do
         arg_names[#arg_names + 1] = param.name
      end

      local is_valid_name = is_valid_identifier(method.name)
      if flags.is_method and is_valid_name and arg_names[1] == 'self' then
         table.remove(arg_names, 1)
      end

      local header
      local access = format_table_access(type_access, method.name)
      if flags.is_method then
         if is_valid_name then
            header = ('function %s:%s(%s) end'):format(type_access, method.name, table.concat(arg_names, ', '))
         else
            if arg_names[1] ~= 'self' then
               table.insert(arg_names, 1, 'self')
            end
            header = ('%s = function(%s) end'):format(access, table.concat(arg_names, ', '))
         end
      else
         if is_valid_name then
            header = ('function %s(%s) end'):format(access, table.concat(arg_names, ', '))
         else
            header = ('%s = function(%s) end'):format(access, table.concat(arg_names, ', '))
         end
      end

      lines[#lines + 1] = header
      add_blank_line(lines)
   end
end

emit_object = function(lines, ns_name, ns_local, entry)
   local class_name = format_qualified_name(ns_name, entry.name)
   local type_access = format_table_access(ns_local, entry.name)
   local parent = entry.parent
   if parent then
      local parent_name = format_qualified_name(parent.namespace, parent.name)
      lines[#lines + 1] = ('---@class %s: %s'):format(class_name, parent_name)
   else
      lines[#lines + 1] = ('---@class %s'):format(class_name)
   end

   local prop_annotations = collect_annotations(entry.properties, function(prop, index)
      local name = prop.name or ('property' .. index)
      return name, type_to_string(prop.typeinfo, 'return')
   end)
   for _, prop in ipairs(prop_annotations) do
      lines[#lines + 1] = ('---@field %s %s'):format(format_field_annotation_name(prop.name), prop.type)
   end

   local constructors = {}
   if entry.methods then
      for i = 1, #entry.methods do
         local method = entry.methods[i]
         local flags = method.flags or {}
         if flags.is_constructor then
            local signature = build_callable_signature(method)
            constructors[#constructors + 1] = signature
         end
      end
   end
   table.sort(constructors)
   for _, signature in ipairs(constructors) do
      lines[#lines + 1] = ('---@overload %s'):format(signature)
   end

   lines[#lines + 1] = (type_access .. ' = {}')
   add_blank_line(lines)

   emit_methods_for_type(lines, type_access, entry.methods, class_name)
end

emit_interface = emit_object

emit_struct = function(lines, ns_name, ns_local, entry)
   local class_name = format_qualified_name(ns_name, entry.name)
   local type_access = format_table_access(ns_local, entry.name)
   lines[#lines + 1] = ('---@class %s'):format(class_name)

   local field_annotations = collect_annotations(entry.fields, function(field, index)
      local name = field.name or ('field' .. index)
      return name, type_to_string(field.typeinfo, 'return')
   end)
   for _, field in ipairs(field_annotations) do
      lines[#lines + 1] = ('---@field %s %s'):format(format_field_annotation_name(field.name), field.type)
   end

   local constructors = {}
   if entry.methods then
      for i = 1, #entry.methods do
         local method = entry.methods[i]
         local flags = method.flags or {}
         if flags.is_constructor then
            local signature = build_callable_signature(method)
            constructors[#constructors + 1] = signature
         end
      end
   end
   table.sort(constructors)
   for _, signature in ipairs(constructors) do
      lines[#lines + 1] = ('---@overload %s'):format(signature)
   end

   lines[#lines + 1] = (type_access .. ' = {}')
   add_blank_line(lines)

   emit_methods_for_type(lines, type_access, entry.methods, class_name)
end

emit_union = emit_struct

emit_enum = function(lines, ns_name, ns_local, entry)
   local full_name = format_qualified_name(ns_name, entry.name)
   local type_access = format_table_access(ns_local, entry.name)
   lines[#lines + 1] = ('---@enum %s'):format(full_name)
   lines[#lines + 1] = (type_access .. ' = {')
   local values = entry.values or {}
   local entries = {}
   for i = 1, #values do
      local val = values[i]
      local key = core.upcase(val.name or ''):gsub('%-', '_')
      entries[#entries + 1] = { key = key, value = tostring(val.value) }
   end
   table.sort(entries, function(a, b) return a.key < b.key end)
   for _, item in ipairs(entries) do
      local key_repr = format_table_key(item.key)
      lines[#lines + 1] = ('   %s = %s,'):format(key_repr, item.value)
   end
   lines[#lines + 1] = '}'
   add_blank_line(lines)
end

emit_flags = emit_enum

emit_callback = function(lines, ns_name, ns_local, entry)
   local full_name = format_qualified_name(ns_name, entry.name)
   local signature = build_callable_signature(entry)
   lines[#lines + 1] = ('---@alias %s %s'):format(full_name, signature)
   lines[#lines + 1] = ('---@type %s'):format(full_name)
   lines[#lines + 1] = (format_table_access(ns_local, entry.name) .. ' = nil')
   add_blank_line(lines)
end

emit_function = function(lines, ns_name, ns_local, entry)
   local signature, params, returns = build_callable_signature(entry)
   for _, param in ipairs(params) do
      lines[#lines + 1] = format_param_annotation(param)
   end
   local return_annotation = format_returns(returns)
   if return_annotation then
      lines[#lines + 1] = return_annotation
   end
   local arg_names = {}
   for _, param in ipairs(params) do
      arg_names[#arg_names + 1] = param.name
   end
   local access = format_table_access(ns_local, entry.name)
   if is_valid_identifier(entry.name) then
      lines[#lines + 1] = ('function %s(%s) end'):format(access, table.concat(arg_names, ', '))
   else
      lines[#lines + 1] = ('%s = function(%s) end'):format(access, table.concat(arg_names, ', '))
   end
   add_blank_line(lines)
end

emit_constant = function(lines, ns_name, ns_local, entry)
   local const_type = type_to_string(entry.typeinfo, 'return')
   if const_type and const_type ~= 'nil' then
      lines[#lines + 1] = ('---@type %s'):format(const_type)
   end
   lines[#lines + 1] = (format_table_access(ns_local, entry.name) .. ' = nil')
   add_blank_line(lines)
end

if os.getenv('LUA_GOBJECT_META_DEBUG') then
   io.stderr:write('Initial queue length: ' .. tostring(#queue) .. '\n')
end

while #queue > 0 do
   local namespace = table.remove(queue, 1)
   if not processed[namespace] then
      if os.getenv('LUA_GOBJECT_META_DEBUG') then
         io.stderr:write('Processing namespace: ' .. namespace .. '\n')
      end
      local ns_entry = namespaces[namespace]
      local requested_version = ns_entry and ns_entry.version or nil
      local info = core.gi.require(namespace, requested_version)
      if not info then error("Could not find "..namespace.." v"..requested_version) end
      ns_entry.version = info.version or requested_version

      local deps = info.dependencies or {}
      if not skip_dependencies then
         for dep_name, dep_version in pairs(deps) do
            enqueue_namespace(dep_name, dep_version)
         end
      end

      processed[namespace] = true
      process_order[#process_order + 1] = namespace
      if os.getenv('LUA_GOBJECT_META_DEBUG') then
         io.stderr:write('Added to process_order: ' .. namespace .. ' (size ' .. #process_order .. ')\n')
      end

      local ns_data = {
         name = namespace,
         version = ns_entry.version,
         objects = {},
         interfaces = {},
         structs = {},
         unions = {},
         enums = {},
         flags = {},
         callbacks = {},
         functions = {},
         constants = {},
         fields = {},
         field_order = {},
      }
      namespace_data[namespace] = ns_data

      local ns_table = core.gi[namespace]
      for idx = 1, #ns_table do
         local entry = ns_table[idx]
         local etype = entry.type
         if etype == 'object' then
            ns_data.objects[#ns_data.objects + 1] = entry

            if entry.properties then
               for i = 1, #entry.properties do
                  ensure_type_dependencies(entry.properties[i].typeinfo)
               end
            end
            if entry.fields then
               for i = 1, #entry.fields do
                  ensure_type_dependencies(entry.fields[i].typeinfo)
               end
            end
            if entry.methods then
               for i = 1, #entry.methods do
                  scan_callable_dependencies(entry.methods[i])
               end
            end
            if entry.signals then
               for i = 1, #entry.signals do
                  scan_callable_dependencies(entry.signals[i])
               end
            end
         elseif etype == 'interface' then
            ns_data.interfaces[#ns_data.interfaces + 1] = entry
            if entry.properties then
               for i = 1, #entry.properties do
                  ensure_type_dependencies(entry.properties[i].typeinfo)
               end
            end
            if entry.methods then
               for i = 1, #entry.methods do
                  scan_callable_dependencies(entry.methods[i])
               end
            end
            if entry.signals then
               for i = 1, #entry.signals do
                  scan_callable_dependencies(entry.signals[i])
               end
            end
         elseif etype == 'struct' then
            ns_data.structs[#ns_data.structs + 1] = entry
            if entry.fields then
               for i = 1, #entry.fields do
                  ensure_type_dependencies(entry.fields[i].typeinfo)
               end
            end
            if entry.methods then
               for i = 1, #entry.methods do
                  scan_callable_dependencies(entry.methods[i])
               end
            end
         elseif etype == 'union' then
            ns_data.unions[#ns_data.unions + 1] = entry
            if entry.fields then
               for i = 1, #entry.fields do
                  ensure_type_dependencies(entry.fields[i].typeinfo)
               end
            end
            if entry.methods then
               for i = 1, #entry.methods do
                  scan_callable_dependencies(entry.methods[i])
               end
            end
         elseif etype == 'enum' then
            ns_data.enums[#ns_data.enums + 1] = entry
         elseif etype == 'flags' then
            ns_data.flags[#ns_data.flags + 1] = entry
         elseif etype == 'callback' then
            ns_data.callbacks[#ns_data.callbacks + 1] = entry
            scan_callable_dependencies(entry)
         elseif etype == 'function' then
            ns_data.functions[#ns_data.functions + 1] = entry
            scan_callable_dependencies(entry)
         elseif etype == 'constant' then
            ns_data.constants[#ns_data.constants + 1] = entry
            ensure_type_dependencies(entry.typeinfo)
            add_namespace_field(ns_data, entry.name, type_to_string(entry.typeinfo, 'return'))
         end
      end

      table.sort(ns_data.objects, function(a, b) return a.name < b.name end)
      table.sort(ns_data.interfaces, function(a, b) return a.name < b.name end)
      table.sort(ns_data.structs, function(a, b) return a.name < b.name end)
      table.sort(ns_data.unions, function(a, b) return a.name < b.name end)
      table.sort(ns_data.enums, function(a, b) return a.name < b.name end)
      table.sort(ns_data.flags, function(a, b) return a.name < b.name end)
      table.sort(ns_data.callbacks, function(a, b) return a.name < b.name end)
      table.sort(ns_data.functions, function(a, b) return a.name < b.name end)
      table.sort(ns_data.constants, function(a, b) return a.name < b.name end)
      table.sort(ns_data.field_order)
   end
end

if not primary_namespace then
   primary_namespace = process_order[1]
end

local namespace_vars = {}
for _, ns_name in ipairs(process_order) do
   namespace_vars[ns_name] = make_namespace_var_name(ns_name)
end

local lines = {}

lines[#lines + 1] = '---@meta'
add_blank_line(lines)

for _, ns_name in ipairs(process_order) do
   local data = namespace_data[ns_name]
   local ns_local = namespace_vars[ns_name]

   lines[#lines + 1] = ('---@class %s'):format(ns_name)
   local field_order = {}
   for _, field in ipairs(data.field_order) do
      field_order[#field_order + 1] = field
   end
   table.sort(field_order)
   for _, field in ipairs(field_order) do
      local type_str = data.fields[field] or 'any'
      lines[#lines + 1] = ('---@field %s %s'):format(format_field_annotation_name(field), type_str)
   end
   lines[#lines + 1] = ('local %s = {}'):format(ns_local)
   add_blank_line(lines)

   for _, entry in ipairs(data.objects) do
      emit_object(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.interfaces) do
      emit_interface(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.structs) do
      emit_struct(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.unions) do
      emit_union(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.enums) do
      emit_enum(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.flags) do
      emit_flags(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.callbacks) do
      emit_callback(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.functions) do
      emit_function(lines, ns_name, ns_local, entry)
   end
   for _, entry in ipairs(data.constants) do
      emit_constant(lines, ns_name, ns_local, entry)
   end

   add_blank_line(lines)
end

local primary_var = primary_namespace and namespace_vars[primary_namespace]
if not primary_var then
   primary_var = namespace_vars[process_order[#process_order]]
end

lines[#lines + 1] = ('return %s'):format(primary_var or 'nil')

local content = table.concat(lines, '\n')

local function ensure_directory(path)
   local dir = path:match('^(.*)/[^/]+$')
   if dir and #dir > 0 then
      os.execute(('mkdir -p %q'):format(dir))
   end
end

ensure_directory(output_path)

if os.getenv('LUA_GOBJECT_META_DEBUG') then
   io.stderr:write(('Generating namespaces (%d): %s\n'):format(#process_order, table.concat(process_order, ', ')))
end

local file, err = io.open(output_path, 'w')
if not file then
   error(('failed to open %s for writing: %s'):format(output_path, err))
end
file:write(content)
file:close()

if next(unknown_tags) then
   io.stderr:write('warning: unhandled GI type tags:')
   for tag in pairs(unknown_tags) do
      io.stderr:write(' ', tag)
   end
   io.stderr:write('\n')
end
