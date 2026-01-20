# LuaGObject: Dynamic binding to GObject-based libraries using GObject-Introspection.
# Author: Pavel Holejsovsky <pavel.holejsovsky@gmail.com>
# License: MIT

VERSION = 0.10.4
MAKE ?= make

ROCK = luagobject-$(VERSION)-1.rockspec

.PHONY : rock all clean install check

all :
	$(MAKE) -C LuaGObject

rock : $(ROCK)
$(ROCK) : rockspec.in Makefile
	sed 's/%VERSION%/$(VERSION)/' $< >$@

clean :
	rm -f *.rockspec
	$(MAKE) -C LuaGObject clean
	$(MAKE) -C tests clean

install :
	$(MAKE) -C LuaGObject install

check : all
	$(MAKE) -C tests check

export VERSION
