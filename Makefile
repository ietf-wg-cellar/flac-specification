SRC=flac.md
PDF=$(SRC:.md=.pdf)
HTML=$(SRC:.md=.html)

$(info PDF and HTML rendering has been tested with pandoc version 1.13.2.1, some older versions are known to produce very poor output, please ensure your pandoc is recent enough.)
$(info RFC rendering has been tested with mmark version 1.3.4 and xml2rfc 2.5.1, please ensure these are installed and recent enough.)

all: draft-xiph-cellar-flac-00.html draft-xiph-cellar-flac-00.txt

draft-xiph-cellar-flac-00.html: flac.md
	cat rfc_frontmatter.md "$<" > merged.md
	mmark -xml2 -page merged.md > draft-xiph-cellar-flac-00.xml
	xml2rfc --html draft-xiph-cellar-flac-00.xml -o "$@"

draft-xiph-cellar-flac-00.txt: flac.md
	cat rfc_frontmatter.md "$<" > merged.md
	mmark -xml2 -page merged.md > draft-xiph-cellar-flac-00.xml
	xml2rfc draft-xiph-cellar-flac-00.xml -o "$@"

clean:
	rm -f draft-xiph-cellar-flac-00.txt draft-xiph-cellar-flac-00.html merged.md draft-xiph-cellar-flac-00.xml
