ASCIIDOC ?= asciidoctor

MAN_FILES := man/shards.1 man/shard.yml.5

docs: manpages

manpages: $(MAN_FILES)

man/%.1 man/%.5: docs/%.adoc
	$(ASCIIDOC) $< -b manpage -o $@ -a year=$(shell date +%Y) -a shards_version=$(SHARDS_VERSION)

clean_docs: phony
	rm -f $(MAN_FILES)

phony:
