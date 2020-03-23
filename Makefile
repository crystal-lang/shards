.POSIX:

CRYSTAL = crystal
CRFLAGS =
SHARDS_SOURCES = $(shell find src -name '*.cr')
MOLINILLO_SOURCES = $(shell find lib/molinillo -name '*.cr')
SOURCES = $(SHARDS_SOURCES) $(MOLINILLO_SOURCES)
TEMPLATES = src/templates/*.ecr

DESTDIR =
PREFIX = /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin
MANDIR = $(DESTDIR)$(PREFIX)/share/man
INSTALL = /usr/bin/install

all: bin/shards

clean: phony
	rm -f bin/shards

bin/shards: $(SOURCES) $(TEMPLATES)
	@mkdir -p bin
	$(CRYSTAL) build src/shards.cr -o bin/shards $(CRFLAGS)

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

test_unit: phony
	$(CRYSTAL) spec ./spec/unit/*_spec.cr

test_integration: bin/shards phony
	$(CRYSTAL) spec ./spec/integration/*_spec.cr

phony:
