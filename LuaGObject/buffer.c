/*
 * Dynamic Lua binding to GObject using dynamic gobject-introspection.
 *
 * Copyright (c) 2010, 2011 Pavel Holejsovsky
 * Licensed under the MIT license:
 * http://www.opensource.org/licenses/mit-license.php
 *
 * Implementation of writable buffer object.
 */

#include <string.h>
#include "lua_gobject.h"

static int
buffer_len (lua_State *L)
{
  luaL_checkudata (L, 1, LUA_GOBJECT_BYTES_BUFFER);
  lua_pushinteger (L, lua_objlen (L, 1));
  return 1;
}

static int
buffer_tostring (lua_State *L)
{
  gpointer data = luaL_checkudata (L, 1, LUA_GOBJECT_BYTES_BUFFER);
  lua_pushlstring (L, data, lua_objlen (L, 1));
  return 1;
}

static int
buffer_index (lua_State *L)
{
  lua_gobject_Unsigned index;
  unsigned char *buffer = luaL_checkudata (L, 1, LUA_GOBJECT_BYTES_BUFFER);
  index = lua_tointeger (L, 2);
  if (index > 0 && (size_t) index <= lua_objlen (L, 1))
    lua_pushinteger (L, buffer[index - 1]);
  else
    {
      luaL_argcheck (L, !lua_isnoneornil (L, 2), 2, "nil index");
      lua_pushnil (L);
    }
  return 1;
}

static int
buffer_newindex (lua_State *L)
{
  lua_gobject_Unsigned index;
  unsigned char *buffer = luaL_checkudata (L, 1, LUA_GOBJECT_BYTES_BUFFER);
  index = luaL_checkint (L, 2);
  luaL_argcheck (L, index > 0 && (size_t) index <= lua_objlen (L, 1),
                 2, "bad index");
  buffer[index - 1] = luaL_checkint (L, 3) & 0xff;
  return 0;
}

static const luaL_Reg buffer_mt_reg[] = {
  { "__len", buffer_len },
  { "__tostring", buffer_tostring },
  { "__index", buffer_index },
  { "__newindex", buffer_newindex },
  { NULL, NULL }
};

static int
buffer_new (lua_State *L)
{
  size_t size;
  gpointer *buffer;
  const char *source = NULL;

  if (lua_type (L, 1) == LUA_TSTRING)
    source = lua_tolstring (L, 1, &size);
  else
    size = luaL_checkint (L, 1);
  buffer = lua_newuserdata (L, size);
  if (source)
    memcpy (buffer, source, size);
  else
    memset (buffer, 0, size);
  luaL_getmetatable (L, LUA_GOBJECT_BYTES_BUFFER);
  lua_setmetatable (L, -2);
  return 1;
}

static const luaL_Reg buffer_reg[] = {
  { "new", buffer_new },
  { NULL, NULL }
};

void
lua_gobject_buffer_init (lua_State *L)
{
  /* Register metatables. */
  luaL_newmetatable (L, LUA_GOBJECT_BYTES_BUFFER);
  luaL_register (L, NULL, buffer_mt_reg);
  lua_pop (L, 1);

  /* Register global API. */
  lua_newtable (L);
  luaL_register (L, NULL, buffer_reg);
  lua_setfield (L, -2, "bytes");
}
