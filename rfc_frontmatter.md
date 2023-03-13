%%%
title = "Free Lossless Audio Codec"
abbrev = "FLAC"
ipr= "trust200902"
area = "art"
submissiontype = "IETF"
workgroup = "cellar"
keyword = ["free,lossless,audio,codec,encoder,decoder,compression,compressor,archival,archive,archiving,backup,music"]

[seriesInfo]
name = "Internet-Draft"
stream = "IETF"
status = "standard"
value = "@BUILD_VERSION@"

[[author]]
initials="M.Q.C."
surname="van Beurden"
fullname="Martijn van Beurden"
  [author.address]
  email="mvanb1@gmail.com"
    [author.address.postal]
    country="NL"

[[author]]
initials="A."
surname="Weaver"
fullname="Andrew Weaver"
  [author.address]
  email="theandrewjw@gmail.com"
%%%

.# Abstract

This document defines the Free Lossless Audio Codec (FLAC) format. FLAC is designed to reduce the amount of computer storage space needed to store digital audio signals without losing information in doing so (i.e. lossless). FLAC is free in the sense that its specification is open and its reference implementation is open-source. Compared to other lossless (audio) coding formats, FLAC is a format with low complexity and can be coded to and from with little computing resources. Decoding of FLAC has seen many independent implementations on many different platforms, and both encoding and decoding can be implemented without needing floating-point arithmetic.

{mainmatter}
