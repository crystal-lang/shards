ASCIIDOC ?= asciidoctor

ASCIIDOC_OPTIONS = -a year=$(shell date +%Y) -a shards_version=$(SHARDS_VERSION)

MAN_FILES := man/shards.1 man/shard.yml.5
HTML_FILES := docs/shards.html docs/shard.yml.html

docs: manpages

manpages: $(MAN_FILES)

htmlpages: $(HTML_FILES)

man/%.1 man/%.5: docs/%.adoc
	$(ASCIIDOC) $(ASCIIDOC_OPTIONS) $< -b manpage -o $@

docs/%.html: docs/%.adoc
	$(ASCIIDOC) $(ASCIIDOC_OPTIONS) $< -b html5 -o $@

clean_docs: phony
	rm -f $(MAN_FILES)
	rm -rf docs/*.html

phony:
