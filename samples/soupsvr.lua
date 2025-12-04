#! /usr/bin/env lua

--
-- Sample server using libsoup library.  Listens on 1080 port and serves
-- local files from current directory.  Allows to be terminated by query
-- for /quit file (i.e. curl http://localhost:1080/quit)
--

local coroutine = require 'coroutine'

local LuaGObject = require 'LuaGObject'
local bytes = require 'bytes'
local GLib = LuaGObject.GLib
local Gio = LuaGObject.Gio
local Soup = LuaGObject.Soup

local app = Gio.Application { application_id = 'org.LuaGObject.soupsvr' }
function app:on_activate()
	app:hold()

	local server = Soup.Server()

	-- Set up quit handler.
	server:add_handler('/quit', function(server, msg, path, query, ctx)
		msg:set_status(200)
		msg:get_response_body():complete()
		server:quit()
		app:release()
	end)

	-- Set up file retriever handler.
	server:add_handler('/', function(server, msg, path, query, ctx)
		local stream = Gio.File.new_for_path(path:sub(2)):read()
		if stream then
			-- The whole is send by function running in coroutine.
			-- Coroutine yields when it waits either for data from the
			-- disk or signal that chunk was successfully sent.
			local next_chunk = coroutine.wrap(function()
				local buffer = bytes.new(4096)
				while true do
					-- Read another chunk of data from the source to the
					-- buffer.
					stream:read_async(buffer, GLib.PRIORITY_DEFAULT,
						nil, coroutine.running())
					local size = stream.read_finish(coroutine.yield())
					if size < 0 then
						-- IO error reading disk, this simply shuts our toy
						-- server down.
						server:quit()
						app:release()
						return
					end

					-- Send the chunk to the message body.
					msg.response_body:append(tostring(buffer):sub(1, size))
					server:unpause_message(msg)

					-- Wait until soup signalizes that chunk was written.
					coroutine.yield()
					if size < #buffer then break end
				end
				msg.response_body:complete()
			end)

			-- Prepare sending using chunked method.
			msg:set_status(200)
			msg:get_response_headers():set_encoding('CHUNKED')

			-- When headers are written, start writing body by initial
			-- resuming of sending coroutine.
			msg.on_wrote_headers = next_chunk

			-- When the chunk is sent, resume coroutine so that it starts
			-- reading and sending another chunk.
			msg.on_wrote_chunk = next_chunk
		else
			-- File was not found, send proper code.
			msg:set_status(404)
			msg:get_response_body():complete()
		end
	end)

	server:listen_local(1080)
end

app:run { arg[0], ... }
