SRC=flac.md
PDF=$(SRC:.md=.pdf)
HTML=$(SRC:.md=.html)
AUTHOR=ietf
VERSION=00

$(info PDF and HTML rendering has been tested with pandoc version 1.13.2.1, some older versions are known to produce very poor output, please ensure your pandoc is recent enough.)
$(info RFC rendering has been tested with mmark version 1.3.4 and xml2rfc 2.5.1, please ensure these are installed and recent enough.)

all: draft-$(AUTHOR)-cellar-flac-00.html draft-$(AUTHOR)-cellar-flac-$(VERSION).txt

draft-$(AUTHOR)-cellar-flac-$(VERSION).html: flac.md
	cat rfc_frontmatter.md "$<" > merged.md
	mmark -xml2 -page merged.md > draft-$(AUTHOR)-cellar-flac-$(VERSION).xml
	xml2rfc --html draft-$(AUTHOR)-cellar-flac-$(VERSION).xml -o "$@"

draft-$(AUTHOR)-cellar-flac-$(VERSION).txt: flac.md
	cat rfc_frontmatter.md "$<" > merged.md
	mmark -xml2 -page merged.md > draft-$(AUTHOR)-cellar-flac-$(VERSION).xml
	xml2rfc draft-$(AUTHOR)-cellar-flac-$(VERSION).xml -o "$@"

clean:
	rm -f draft-$(AUTHOR)-cellar-flac-$(VERSION).txt draft-$(AUTHOR)-cellar-flac-$(VERSION).html merged.md draft-$(AUTHOR)-cellar-flac-$(VERSION).xml
