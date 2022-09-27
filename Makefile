AUTHOR=ietf
VERSION=05
BASENAME=draft-$(AUTHOR)-cellar-flac-$(VERSION)

all: $(BASENAME).txt $(BASENAME).html $(BASENAME).pdf

$(BASENAME).txt $(BASENAME).html: $(BASENAME).xml
	xml2rfc --v3 $^ --text --html

$(BASENAME).pdf: $(BASENAME).xml
	xml2rfc --v3 $^ --pdf


$(BASENAME).xml: rfc_frontmatter.md flac.md rfc_backmatter.md
	cat $^ | sed -e "s/@BUILD_VERSION@/$(BASENAME)/" |  mmark > $@

clean:
	rm -f $(BASENAME).txt $(BASENAME).html $(BASENAME).pdf merged.md $(BASENAME).xml
