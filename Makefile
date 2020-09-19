.POSIX:

release ?=      ## Compile in release mode
debug ?=        ## Add symbolic debug info
static ?=       ## Enable static linking

CRYSTAL ?= crystal
SHARDS ?= shards
override FLAGS += $(if $(release),--release )$(if $(debug),-d )$(if $(static),--static )

SHARDS_SOURCES = $(shell find src -name '*.cr')
MOLINILLO_SOURCES = $(shell find lib/molinillo -name '*.cr' 2> /dev/null)
SOURCES = $(SHARDS_SOURCES) $(MOLINILLO_SOURCES)
TEMPLATES = src/templates/*.ecr

SHARDS_CONFIG_BUILD_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
SOURCE_DATE_EPOCH := $(shell (git show -s --format=%ct HEAD || stat -c "%Y" Makefile || stat -f "%m" Makefile) 2> /dev/null)
EXPORTS := SHARDS_CONFIG_BUILD_COMMIT="$(SHARDS_CONFIG_BUILD_COMMIT)" SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"
DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(DESTDIR)$(PREFIX)/bin
MANDIR ?= $(DESTDIR)$(PREFIX)/share/man
INSTALL ?= /usr/bin/install

MOLINILLO_VERSION = $(shell $(CRYSTAL) eval 'require "yaml"; puts YAML.parse(File.read("shard.lock"))["shards"]["molinillo"]["version"]')
MOLINILLO_URL = "https://github.com/crystal-lang/crystal-molinillo/archive/v$(MOLINILLO_VERSION).tar.gz"

all: bin/shards

clean: phony
	rm -f bin/shards

bin/shards: $(SOURCES) $(TEMPLATES) lib
	@mkdir -p bin
	$(EXPORTS) $(CRYSTAL) build $(FLAGS) src/shards.cr -o bin/shards

install: bin/shards phony
	$(INSTALL) -m 0755 -d "$(BINDIR)" "$(MANDIR)/man1" "$(MANDIR)/man5"
	$(INSTALL) -m 0755 bin/shards "$(BINDIR)"
	$(INSTALL) -m 0644 man/shards.1 "$(MANDIR)/man1"
	$(INSTALL) -m 0644 man/shard.yml.5 "$(MANDIR)/man5"

uninstall: phony
	rm -f "$(BINDIR)/shards"
	rm -f "$(MANDIR)/man1/shards.1"
	rm -f "$(MANDIR)/man5/shard.yml.5"

test: test_unit test_integration

test_unit: phony lib
	$(CRYSTAL) spec ./spec/unit/

test_integration: bin/shards phony
	$(CRYSTAL) spec ./spec/integration/

lib: shard.lock
	mkdir -p lib/molinillo
	$(SHARDS) install || (curl -L $(MOLINILLO_URL) | tar -xzf - -C lib/molinillo --strip-components=1)
	touch lib

shard.lock: shard.yml
	$(SHARDS) update

phony:
