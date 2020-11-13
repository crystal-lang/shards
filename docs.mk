ASCIIDOC ?= asciidoctor

ASCIIDOC_OPTIONS = -a year=$(shell date +%Y) -a shards_version=$(SHARDS_VERSION)

MAN_FILES := man/shards.1 man/shard.yml.5
docs: manpages

manpages: $(MAN_FILES)

man/%.1 man/%.5: docs/%.adoc
	$(ASCIIDOC) $(ASCIIDOC_OPTIONS) $< -b html5 -o $@

clean_docs: phony
	rm -f $(MAN_FILES)

phony:
