# Gio

Most Gio functionality is supported automatically through GObject-Introspection, but LuaGObject provides a helper called `Gio.Async` which makes it easier to use Gio-style asynchronous I/O.

## Asynchronous IO

Gio's native asynchronous operations are based on a traditional callback scheme. Once an operation has started, it is pushed to the background until it is finished where it will then call the registered callback using the results of a given operation as the parameters to the callback. While this pattern is used widely for most asynchronous programming, it also makes code much more difficult to reason about and does not fit well with Lua's native coroutines. Coroutines allow asynchronous code to take on a synchronous feeling, and avoid polluting one's code hierarchy with callbacks while still retaining the advantages of non-blocking I/O, and LuaGObject provides helpers to bridge this gap.

Gio-style asynchronous functions always come as pairs of two methods: `<name>_async` (sometimes just `<name>` without the suffix, especially in newer libraries) which starts an operation, and `<name>_finish` which is called within a registered callback and allows for the retrieval of an operation's results. When LuaGObject's `Gio` override is loaded, LuaGObject will detect these async pairs—within all namespaces, not just Gio's—and when these paired functions are found, it will synthesize a new function called `async_<name>` for each pair, wrapping the native methods using Lua coroutines to convert convert callbacks into synchronous code. For `async_<name>` functions to work, they must be called within the context `Gio.Async`. One can use `Gio.Async.call` to perform an async call as a synchronous call, and `Gio.Async.start` to start the routine in the background.

### The Gio.Async Class

This helper class is implemented by LuaGObject—it does not originate from Gio. It contains the interface for LuaGObject's asynchronous support. This class is entirely static and it is not possible to instantiate.

### Gio.Async.call and Gio.Async.start

	local call_results = Gio.Async.call(user_function[, cancellable[, io_priority])(user_args)
	local resume_results = Gio.Async.start(user_function[, cancellable[, io_priority])(user_args)

These methods accept user function to be run as argument and return function which starts execution of the user function in async-enabled context.

These functions accept a user-defined Lua function as their first parameter, in which all `async_<name>` functions will become available.

Any `async_<name>` methods called inside context do not accept `io_priority` and `cancellable` arguments (as their `<name>_async` original counterparts do). Instead, the `cancellable` and `io_priority` parameters passed to the originating `Gio.Async.call/start` are used in all `async_<name>` calls.

### Gio.Async.cancellable and Gio.Async.io_priority

Code running inside async-enabled context can query or the change value of the context-default `cancellable` and `io_priority` attributes by getting or setting them as attributes of the static `Gio.Async` class.

If `cancellable` or `io_priority` arguments are not provided to `Gio.Async.start` or `Gio.Async.call`, they are automatically inherited from the currently running async-enabled coroutine if available, otherwise default values are used (if the originating caller is not running in an async-enabled context).

### Simple asynchronous I/O example

This GTK+ 3 example example reacts to the press of button, reads contents of `/etc/passwd` and dumps it to standard output.

	local window = Gtk.Window {
		...  Gtk.Button { id = "button", label = "Breach" }, ...
	}

	function window.child.button:on_clicked()
		local function dump_file(filename)
			local file = Gio.File.new_for_path(filename)
			local info = file:async_query_info("standard::size", "NONE
			local stream = file:async_read()
			local bytes = stream:async_read_bytes(info:get_size())
			print(bytes.data)
			stream:async_close()
		end
		Gio.Async.start(dump_file)("/etc/passwd")
	end

Note that all reading happens while running on background, as the on_clicked() handler finishes while the async operation is still running in the background, so the main thread will never block no matter how big your '/etc/passwd' file is.

For a more detailed look at asynchronous operations, see `samples/giostream.lua`.
