AUTHOR=ietf
VERSION=03
BASENAME=draft-$(AUTHOR)-cellar-flac-$(VERSION)

all: $(BASENAME).html $(BASENAME).txt

$(BASENAME).xml: rfc_frontmatter.md flac.md rfc_backmatter.md
	cat $^ | mmark > $@

$(BASENAME).html: $(BASENAME).xml
	xml2rfc --html --v3 $^ -o "$@"

$(BASENAME).txt: $(BASENAME).xml
	xml2rfc --v3 $^ -o "$@"

clean:
	rm -f $(BASENAME).txt $(BASENAME).html merged.md $(BASENAME).xml
