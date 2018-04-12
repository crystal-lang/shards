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

all: bin/shards

clean: phony
	rm -f bin/shards

bin/shards: $(SOURCES) $(TEMPLATES)
	@mkdir -p bin
	$(CRYSTAL) build src/shards.cr -o bin/shards $(CRFLAGS)

install: bin/shards phony
	$(INSTALL) --mode 0755 -d $(BINDIR) $(MANDIR)/man1 $(MANDIR)/man5
	$(INSTALL) --mode 0755 -t $(BINDIR) bin/shards
	$(INSTALL) --mode 0644 -t $(MANDIR)/man1 man/shards.1
	$(INSTALL) --mode 0644 -t $(MANDIR)/man5 man/shard.yml.5

uninstall: phony
	rm -f $(BINDIR)/shards
	rm -f $(MANDIR)/man1/shards.1
	rm -f $(MANDIR)/man5/shard.yml.5

test: test_unit test_integration

test_unit: phony
	$(CRYSTAL) run test/*_test.cr

test_integration: bin/shards phony
	$(CRYSTAL) run test/integration/*_test.cr

phony:
