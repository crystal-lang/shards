.POSIX:

CRYSTAL = crystal
CRFLAGS =
SOURCES = src/*.cr src/**/*.cr
TEMPLATES = src/templates/*.ecr

DESTDIR =
PREFIX = /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin
MANDIR = $(DESTDIR)$(PREFIX)/share/man
INSTALL = /usr/bin/install

all: shards

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

test:	test_unit test_integration

test_unit: phony
	$(CRYSTAL) run test/*_test.cr

test_integration: phony
	$(CRYSTAL) run test/integration/*_test.cr

phony:
