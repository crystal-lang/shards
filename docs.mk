ASCIIDOC ?= asciidoctor

ASCIIDOC_OPTIONS = -a year=$(shell date +%Y)

MAN_FILES := man/shards.1 man/shard.yml.5
HTML_FILES := docs/shards.html docs/shard.yml.html

# reproducible builds: reference date is ":date:" attribute from asciidoc source
date_attr = $(shell sed -rn 's/:date:\s*//p' $(1))
source_date_epoch = $(shell date +%s -u -d $(call date_attr,$(1)))

docs: manpages

manpages: $(MAN_FILES)

htmlpages: $(HTML_FILES)

man/%.1 man/%.5: docs/%.adoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOC) $(ASCIIDOC_OPTIONS) $< -b manpage -o $@

docs/%.html: docs/%.adoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOC) $(ASCIIDOC_OPTIONS) $< -b html5 -o $@

clean_docs: phony
	rm -f $(MAN_FILES)
	rm -rf docs/*.html

phony:
