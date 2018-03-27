CRYSTAL ?= $(shell which crystal)

VERSION := $(shell cat VERSION)
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

DESTDIR := /
PREFIX := /usr/local
BINDIR := $(DESTDIR)$(PREFIX)/bin
MANDIR := $(DESTDIR)$(PREFIX)/share/man

ifeq ($(OS),linux)
	CRFLAGS := --link-flags "-static -L/opt/crystal/embedded/lib"
endif

ifeq ($(OS),darwin)
	CRFLAGS := --link-flags "-L."
endif

MANPAGES := $(wildcard man/*.[1-8])
SOURCES := $(wildcard src/*.cr src/**/*.cr)
TEMPLATES := $(wildcard src/templates/*.ecr)

# Builds an unoptimized binary.
all: bin/shards

bin/shards: $(SOURCES) $(TEMPLATES)
	$(CRYSTAL) build -o bin/shards src/shards.cr

# Builds an optimized static binary ready for distribution.
#
# On OS X the binary is only partially static (it depends on the system's
# dylib), but libyaml should be bundled, unless the linker can find
# libyaml.dylib
release:
	if [ "$(OS)" = "darwin" ] ; then \
	  cp /usr/local/lib/libyaml.a . ;\
	  chmod 644 libyaml.a ;\
	  export LIBRARY_PATH= ;\
	fi
	$(CRYSTAL) build --release -o bin/shards src/shards.cr $(CRFLAGS)
	gzip -c bin/shards > shards-$(VERSION)_$(OS)_$(ARCH).gz

# Builds the different releases in Vagrant boxes.
releases:
	vagrant up --provision
	vagrant ssh precise64 --command "cd /vagrant && make release"
	vagrant ssh precise32 --command "cd /vagrant && linux32 make release"
	vagrant halt

clean:
	rm -rf .crystal bin/shards

.PHONY: test
test:
	make test_unit
	make test_integration

.PHONY: test_unit
test_unit:
	$(CRYSTAL) run test/*_test.cr -- --parallel=1

.PHONY: test_integration
test_integration: all
	$(CRYSTAL) run test/integration/*_test.cr -- --parallel=1

.PHONY: install
install: install-bin install-man

.PHONY: install-bin
install-bin: bin/shards
	mkdir -p $(BINDIR)
	cp bin/shards $(BINDIR)/

.PHONY: install-man
install-man:
	mkdir -p $(MANDIR)/man1 $(MANDIR)/man5
	cp $(filter %.1,$(MANPAGES)) $(MANDIR)/man1/
	cp $(filter %.5,$(MANPAGES)) $(MANDIR)/man5/
