# Introduction

This document provides a detailed definition of the FLAC format. FLAC stands for Free Lossless Audio Codec: it is designed to reduce the amount of computer storage space needed to store digital audio signals without needing to remove information in doing so (i.e. lossless). FLAC is free in the sense that its specification is open, its reference implementation is open-source and it is not encumbered by any known patent.

FLAC is able to achieve lossless compression because samples in audio signals tend to be highly correlated with their close neighbors. In contrast with general purpose compressors, which often use dictionaries, do run-length coding or exploit long-term repetition, FLAC removes redundancy solely in the very short term, looking back at most 32 samples.

Compared to other lossless (audio) coding formats, FLAC is a format with low complexity and can be coded to and from with little computing resources. Decoding of FLAC has seen many independent implementations on many different platforms, and both encoding and decoding can be implemented without needing floating-point arithmetic.

# Notation and Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they appear in all capitals, as shown here.

Numbers in the FLAC format are unsigned and coded big-endian unless otherwise noted. Unary coding when used in the FLAC format is done with 0 bits terminated with a 1 bit.

# Definitions

- **Lossless compression**: reducing the amount of computer storage space needed to store data without needing to remove or irreversibly alter any of this data in doing so. In other words, decompressing losslessly compressed information returns exactly the original data.

- **Lossy compression**: like lossless compression, but instead removing, irreversibly altering or only approximating information for the purpose of further reducing the amount of computer storage space needed. In other words, decompressing lossy compressed information returns an approximation of the original data.

- **Block**: A (short) section of linear pulse-code modulated audio, with one or more channels.

- **Subblock**: All samples within a corresponding block for 1 channel. One or more subblocks form a block, and all subblocks in a certain block contain the same number of samples.

- **Frame**: A frame header plus one or more subframes. It encodes the contents of a corresponding block.

- **Subframe**: An encoded subblock. All subframes within a frame code for the same number of samples. A subframe MAY correspond to a subblock, else it corresponds to either the addition or subtraction of two subblocks, see [section on interchannel decorrelation](#interchannel-decorrelation).

- **Blocksize**: The total number of samples contained in a block or coded in a frame, divided by the number of channels. In other words, the number of samples in any subblock of a block, or any subframe of a frame. This is also called **interchannel samples**.

- **Bit depth** or **bits per sample**: the number of bits used to contain each sample. This MUST be the same for all subblocks in a block but MAY be different for different subframes in a frame because of [interchannel decorrelation](#interchannel-decorrelation).

- **Predictor**: a model used to predict samples in an audio signal based on past samples. FLAC uses such predictors to remove redundancy in a signal in order to be able to compress it.

- **Linear predictor**: a predictor using [linear prediction](https://en.wikipedia.org/wiki/Linear_prediction). This is also called **linear predictive coding (LPC)**. With a linear predictor each prediction is a linear combination of past samples, hence the name. A linear predictor has a [causal discrete-time finite impulse response](https://en.wikipedia.org/wiki/Finite_impulse_response).

- **Fixed predictor**: a linear predictor in which the model parameters are the same across all FLAC files, and thus not need to be stored.

- **Predictor order**: the number of past samples that a predictor uses. For example, a 4th order predictor uses the 4 samples directly preceding a certain sample to predict it. In FLAC, samples used in a predictor are always consecutive, and are always the samples directly before the sample that is being predicted

- **Residual**: The audio signal that remains after a predictor has been subtracted from a subblock. If the predictor has been able to remove redundancy from the signal, the samples of the remaining signal (the **residual samples**) will have, on average, a smaller numerical value than the original signal.

- **Rice code**: A [variable-length code](https://en.wikipedia.org/wiki/Variable-length_code) which compresses data by making use of the observation that, after using an effective predictor, most residual samples are closer to zero than the original samples, while still allowing for a small part of the samples to be much larger.

# FLAC format overview

The FLAC format is suited for storing pulse-code modulated (PCM) audio with 1 to 8 channels, sample rates from 1 to 1048576 Hertz and bit depths between 4 and 32 bits. Most tools for reading and writing the FLAC format have been optimized for CD-audio, which is PCM audio with 2 channels, a sample rate of 44.1 kHz and a bit depth of 16 bits.

The coding methods provided by the FLAC format works best on PCM audio signals of which the samples have a signed representation and are centered around zero. Audio signals in which samples have an unsigned representation must be transformed to a signed representation as described in this document in order to achieve reasonable compression. The FLAC format is not suited to compress audio that is not PCM. Pulse-density modulated audio, e.g. DSD, cannot be compressed by FLAC.

## File structure

A FLAC file starts with the file signature fLaC (in ASCII, so 0x664C6143) followed by one or more metadata blocks before coding any audio. Following the last metadata block are one or more frames.

## Metadata blocks

Each metadata block has a header specifying which type it is, whether it is the last metadata block and its size, so that each metadata block can be easily skipped. These metadata blocks are referred to as being file-level metadata, as each frame also contains some metadata in its header. See [file-level metadata](#file-level metadata) for more information.

There are 7 kinds of metadata blocks defined

- Streaminfo: contains the sample rate, number of channels, bit depth, total number of samples and MD5 signature of the audio in the FLAC file, as well as the the minimum and maximum blocksize and minimum and maximum frame size that occur in the file.
- Application metadata: can contain binary data of any kind. As the name suggests, this was envisioned to be used by computer programs to store application-specific data. For human-readable data, a vorbis comment metadata block is used instead.
- Padding: while not strictly metadata, this is space intentionally left blank by the encoder to ease the addition of metadata later on, without having to rewrite the entire file
- Seektable: contains any number of seekpoints, each of which point to a certain sample in the stream to aid seeking.
- Vorbis comment: contains any number of human-readable name-value pairs. This is most commonly used to store information such as title, artist, tracknumber etc., but there is no limit to its use as long as the contents are UTF-8 encodable.
- Cuesheet: Contains a list of locations of interest in the file. This is most commonly used to store the track and index structure of a CDDA disc when the FLAC file contains the audio contents of that disc.
- Picture: Contains an image belonging to the audio in the FLAC file in some way.

## Audio frames

The PCM audio in a FLAC file or stream is divided into blocks, which in turn consist of subblocks. (See section [definitions](#definitions)) These blocks and subblocks are coded respectively as frames and subframes in a FLAC file.

Samples from different channels are not interleaved for each sample, but rather for each block. So, a frame contains a certain number of subframes equal to the number of channels. These subframes are all coded independently and stored one after another. If for example the PCM audio with 2 channels is divided into blocks of size 32, a FLAC frame will contain 2 subframes, the first one coding for 32 samples of the first channel, followed by the second subframe which codes for the 32 samples of the second channel.

As each subframe uses a single predictor, the blocksize influences the compression achieved by the FLAC representation: smaller blocks carry more overhead, larger blocks usually have a less effective predictor. In FLAC, blocksizes can vary between 16 samples and 65535 samples, except for the last block of a stream, which may also be smaller than 16 samples.

A distinction is made between fixed blocksize and variable blocksize streams. In fixed blocksize streams, all blocks except the last one have the same size. Fixed blocksize FLAC files are the most prevalent, as algorithmically determining the optimal variable blocksize layout has turned out to be quite difficult for FLAC encoders.

## Frame sync code

Each FLAC frame starts with a (byte aligned) sync code. In order to find the start of a frame when seeking or starting to decode a stream halfway (for example in internet radio streams), a decoder searches for this sync code, and then validates whether it is the start of a frame by decoding and verifying the frame header.

This verification is necessary because it is not possible to eliminate frame sync codes elsewhere in the stream. Various parts of the format have been designed such that the possibility of encountering a false sync code is reduced, but it is still necessary for a decoder to do as many checks as possible to ascertain that an encountered sync code actually is the start of a frame, especially during seeking or when decoding starts halfway a stream.

## Frame metadata

Each FLAC frame has a header containing the sample rate, bit depth, number of channels, blocksize and position of the contained audio. This way, a decoder has all the information it needs even when decoding starts halfway a stream and the streaminfo metadata block has not been received.

As a frame header does not code for any audio, it is a form of overhead. To not hurt compression too much, the frame header has been made as compact as possible and is not able to contain all bit depths, sample rates and channel orderings possible within the FLAC format. Specifically, for any bit depth other than 4, 8, 12, 16, 20 or 24 bit, any channel ordering other than specified as standard in [channel ordering](#channel-ordering)., any sample rate above 65535Hz not divisible by 10 and any sample rate above 655350Hz the frame header refers to a streaminfo block for information. A FLAC file that contains such parameters is therefore non-streamable, as the frame header alone does not provide all information needed to correctly decode the frame.

The frame header also contains an 8-bit checksum to validate the header.

## Subframe types

Following the frame header are one or more subframes. Each subframe contains the number of audio samples of one channel. The number of audio samples contained is equal to the blocksize in the frame header.

The FLAC format offers four kinds of subframe types

- Constant: all samples in a subblock have the same value. The subframe only contains this single sample value.
- Fixed predictor: One of 5 pre-defined predictors is chosen. The subframe contains warm-up samples and a rice-coded residual.
- Linear predictor: Up to 32 predictor coefficients are stored. The subframe contains predictor coefficients, warm-up samples and a rice-coded residual.
- No predictor: Also called verbatim, samples are simply stored directly. This is used when there is little or no redundancy in the signal, for example on white noise.

The linear predictor is flexible in that both the number of coefficients (i.e. the predictor order) and the precision of these coefficients can be different for each subframe.

## Residual storage

In case a subframe uses a predictor to approximate the coded audio signal, a residual needs to be stored. When an effective predictor is used, the average numerical value of the residual samples is smaller than that of the samples before prediction. While having smaller values on average, it is possible a few 'outlier' residual samples are much larger than any of the original samples. Sometimes these outliers even exceed the range the bit depth of the original audio offers.

To be able to efficiently code a set of numbers of which most are small but a few are much larger, Rice coding is used. This code works by choosing a Rice parameter, splitting the numerical value of each residual sample in two parts by dividing it with `2^(Rice parameter)`, creating a quotient and a remainder. The quotient is stored in unary form, the remainder in binary form. If indeed most residual samples are close to zero and the Rice parameter is chosen right, this form of coding, a so-called variable-length code, usually needs less bits to store than storing the residual in unencoded form.

As Rice codes can only handle unsigned numbers, signed numbers are zigzag encoded to a so-called folded residual. For more information see section [coded residual](#coded-residual) for a more thorough explanation.

Quite often the optimal Rice parameter varies over the course of a subframe. To accommodate this, the residual is split up into `2^(partition order)` partitions, where each partition has its own Rice parameter. The FLAC format uses two forms of Rice coding, which only differ in the number of bits used for encoding the Rice parameter, which is either 4 or 5 bits.

## Frame checksum

Following the last subframe is a CRC-16 checksum of the whole frame, including the frame sync code.

## Further compression improvement

Besides using correlation to past samples with predictors, the FLAC format can also make use of correlation between the left and right channel in stereo audio. This is done by not directly coding subblocks into subframes, but instead coding an average of all samples in both subblocks (a mid channel) or the difference between all samples in both subblocks (a side channel). The following combinations are possible:

- Independent. All channels are coded independently. All non-stereo files are encoded this way.
- Mid-side. A left and right subblock are converted to mid and side subframes. The samples in the mid subframe are the sums of all samples in the left subblock with their corresponding samples in the right subblock, and shifting each of these sums right by 1 bit. The samples in the side subframe are the samples in the right subblock subtracted from their corresponding samples in the left subblock.
- Left-side. The left subblock is coded directly to the left subframe, while the side subframe is constructed in the same way as for mid-side.
- Right-side. The right subblock is coded directly to the right subframe, while the side subframe is constructed in the same way as for mid-side. Note that the actual coded subframe order is side-right.

Another feature in the FLAC format is the detection of wasted bits. These are one or more LSB that are zero throughout the entire subframe. See [section on wasted bits](#wasted-bits).

# Principles

FLAC has no format version information, but it does contain not yet assigned space in several places. Future versions of the format MAY use this unassigned space safely without breaking the format of older streams. Older decoders MAY choose to abort decoding or skip data encoded with newer methods. Apart from these currently not assigned patterns, invalid patterns are specified in several places, meaning that the patterns MUST never appear in any valid bitstream, in any prior, present, or future version of the format. These invalid patterns usually make finding the frame sync code more robust.

All numbers used in a FLAC bitstream MUST be integers; there are no floating-point representations. All numbers MUST be big-endian coded, except the vendor string and field lengths used in Vorbis comments, which MUST be coded little-endian. All numbers MUST be unsigned except all numbers which directly represent samples and two numbers in a linear prediction subframe: the prediction right shift and the predictor coefficient, which MUST be signed two’s complement. None of these restrictions apply to application metadata blocks.

All samples encoded to and decoded from the FLAC format MUST be in a signed representation.

There are several ways to convert unsigned sample representations to signed sample representations, but the coding methods provided by the FLAC format work best on audio signals of which the numerical values of the samples are centered around zero, i.e. have no DC offset. In most unsigned audio formats, signals are centered around halfway the range of the unsigned integer type used. If that is the case, all sample representations SHOULD be converted by first copying the number to a signed integer with sufficient range and then subtracting half of the range of the unsigned integer type, which should result in a signal with samples centered around 0.

# File-level metadata

At the start of a FLAC file, following the fLaC ASCII file signature, one or more metadata blocks MUST be present before any audio frames appear. The first metadata block MUST be a streaminfo block.

Each metadata block starts with a 4 byte header. The first bit in this header flags whether a metadata block is the last one, it is a 0 when other metadata blocks follow, otherwise it is a 1. The 7 remaining bits of the first header byte contain the type of the metadata block as an unsigned number between 0 and 126 according to the following table. A value of 127 (i.e. 0b1111111) is invalid. The three bytes that follow code for the size of the metadata block in bytes excluding the 4 header bytes as an unsigned number coded big-endian.

Value   | Metadata block type
:-------|:-----------
0       | Streaminfo
1       | Padding
2       | Application
3       | Seektable
4       | Vorbis comment
5       | Cuesheet
6       | Picture
7 - 126 | currently not assigned
127     | invalid

## Streaminfo

The first metadata block in a FLAC file MUST be a streaminfo block, and it MUST only appear once in a file. As the streaminfo metadata block has a fixed format, its length as coded by the header is always 34 bytes.

The first 2 bytes contain the minimum blocksize that might appear, the following 2 bytes contain the maximum blocksize used. These numbers are unsigned, coded in big-endian and represent interchannel samples. The minimum blocksize is excluding the last block of a FLAC file, which may be smaller. If the minimum blocksize is equal to the maximum blocksize, the file contains a fixed blocksize stream. Please note that most encoders that create variable blocksize files simply set the minimum blocksize to 0 or 16, which might or might not be the actual minimum blocksize appearing in a stream.

The following 3 bytes contain the minimum framesize in bytes, which is again followed by 3 bytes containing the maximum framesize in bytes. These numbers are unsigned, coded in big-endian. As these numbers are not known at the start of encoding, they are both zero, meaning they are unknown, in case the encoder was unable to seek back to the start of the file after encoding.

The following 20 bits contain the sample rate in Hertz of the audio. This number is unsigned, coded big-endian. A value of zero is invalid.

The following 3 bits contain the number of channels of the audio minus 1. This number is unsigned. For example, a value of 0b110 indicates that the audio has 7 channels.

The following 5 bits contain the bit depth of the audio minus 1. This number is unsigned. For example, a value of 0b10111 indicates that the audio has a bit depth of 24 bits.

The following 36 bits contain the number of interchannel samples in the audio file. This number is unsigned and coded big-endian. As this number might be unknown at the start of encoding, it is set to zero, meaning it is unknown, in case the encoder was unable to seek back to the start of the file after encoding.

The last 16 bytes of a streaminfo metadata block contain an MD5 signature of all PCM audio samples. This MD5 signature is made by performing an MD5 transformation on the samples of all channels interleaved, represented in signed, little-endian form. This interleaving is on a per-sample basis, so for a stereo file this means first the first sample of the first channel, then the first sample of the second channel, then the second sample of the first channel etc. Before performing the MD5 transformation, all samples must be byte-aligned. So, in case the bit depth is not a whole number of bytes, additional zero bits are inserted at the most-significant position until each sample representation is a whole number of bytes. This MD5 signature can be zero, meaning it is unknown, in case the encoder was unable to seek back to the start of the file after encoding or if the encoder did not calculate the MD5 signature.

## Application

Any application metadata block starts with a 4-byte identifier, the rest of the block is in free format and completely up to the computer program using it. There are a couple of IDs registered on https://xiph.org/flac/id.html but registration is not mandatory.

## Padding

If any padding blocks are present in a FLAC file, they are usually last. Padding blocks are meant to leave room for other metadata blocks to be able to grow and shrink in size, without having to rewrite all audio data that comes after the metadata. The size of a padding block is already defined by the metadata block header, so a padding block MUST contain nothing but zero bytes (i.e. 0x00).

## Seektable

To speed up seeking in the audio data, a seektable metadata block can be used. This table can contain any number of seekpoints, each of which contain the first sample number of a frame, the byte offset from the first audio frame at which this frame can be found, and the number of interchannel samples in this frame. A FLAC file MUST NOT contain more than one seektable metadata block.

The seektable contains only seekpoints, the number of which is implied by the size of the seektable given by the metadata block header. Each seekpoint has a length of 18 bytes, so a seektable with a length of 162 bytes contains 9 seekpoints.

The first 8 bytes of each seekpoint contain the number of the first sample in the frame that the seekpoint points to. This number is unsigned, coded big-endian. The following 8 bytes contain the position of the first byte of the frame pointed to, relative to the first byte of the first frame in the stream. The last 2 bytes contain the number of interchannel samples the frame that is pointed to contains.

A seektable can also contain placeholder points, which do not point anywhere but can be used to reserve space which is used to write seekpoints to later. A placeholder seekpoint has the first 8 bytes set to 0xFFFFFFFFFFFFFFFF and all remaining bits set to 0.

## Vorbis comment

A vorbis comment metadata block contains human-readable information coded in UTF-8. Because this metadata block stores data in almost the same way the vorbis codec does, the name vorbis comment was chosen. A vorbis comment metadata block consists of a vendor string optionally followed by a number of fields, which are pairs of field names and field contents. Many users refer to these fields as FLAC tags or simply as tags. A FLAC file MUST NOT contain more than one vorbis comment metadata block.

A vorbis comment metadata block starts with a vendor string, which contains a human readable description of the application that created the FLAC file. The first 4 bytes of a vorbis comment metadata block contain the length in bytes of the vendor string as an unsigned number coded little-endian. The vendor string follows UTF-8 coded, and is not terminated in any way.

Following the vendor string are 4 bytes containing the number of fields that are in this vorbis comment block. This number is unsigned, coded little-endian. Finally, each field is stored with a 4 byte length. First, the 4 byte field length in bytes is stored unsigned, little-endian. The field itself is, like the vendor string, UTF-8 coded, not terminated in any way.

Each field consists of a field name and a field content, separated by an = character. The field name MUST only consist of UTF-8 code points U+0020 through U+0074, excluding U+003D, which is the = character. In other words, the field name can contain all printable ASCII characters except the equals sign. The evaluation of the field names MUST be case insensitive, so U+0041 through 0+005A (A-Z) MUST be considered equivalent to U+0061 through U+007A. The field contents can contain any UTF-8 character.

### Standard field names

Besides the one defined in the following section, no standard field names are defined. In general, most software recognizes the following field names

- Title: name of the current work
- Artist: name of the artist generally responsible for the current work. For orchestral works this is usually the composer, otherwise is it often the performer
- Album: name of the collection the current work belongs to

For a more comprehensive list of possible field names, [the list of tags used in the MusicBrainz project](http://picard-docs.musicbrainz.org/en/variables/variables.html) is recommended.

### Channel mask

Besides fields containing information about the work itself, one field is defined for technical reasons, of which the field name is WAVEFORMATEXTENSIBLE_CHANNEL_MASK. This field contains information on which channels the file contains. Use of this field is RECOMMENDED in case these differ from the channels defined in [channel ordering](#channel-ordering).

The channel mask consists of flag bits indicating which channels are present, stored in a hexadecimal representation preceded by 0x. The flags only signal which channels are present, not in which order, so in case a file has to be encoded in which channels are ordered differently, they have to be reordered. Please note that a file in which the channel order is defined through the WAVEFORMATEXTENSIBLE_CHANNEL_MASK is not streamable, i.e. non-subset, as the field is not found in each frame header. The mask bits can be found in the following table

Bit number | Channel description
:----------|:-----------
0          | Front left
1          | Front right
2          | Front center
3          | Low-frequency effects (LFE)
4          | Back left
5          | Back right
6          | Front left of center
7          | Front right of center
8          | Back center
9          | Side left
10         | Side right
11         | Top center
12         | Top front left
13         | Top front center
14         | Top front right
15         | Top rear left
16         | Top rear center
17         | Top rear right

Following are 3 examples:
- if a file has a single channel, being a LFE channel, the VORBIS_COMMENT field is WAVEFORMATEXTENSIBLE_CHANNEL_MASK=0x8
- if a file has 4 channels, being front left, front right, top front left and top front right, the VORBIS_COMMENT field is WAVEFORMATEXTENSIBLE_CHANNEL_MASK=0x5003
- if an input has 4 channels, being back center, top front center, front center and top rear center in that order, they have to be reordered to front center, back center, top front center and top rear center. The VORBIS_COMMENT field added is WAVEFORMATEXTENSIBLE_CHANNEL_MASK=0x12004.

WAVEFORMATEXTENSIBLE_CHANNEL_MASK fields MAY be padded with zeros, for example, 0x0008 for a single LFE channel. Parsing of WAVEFORMATEXTENSIBLE_CHANNEL_MASK fields MUST be case-insensitive for both the field name and the field contents.

## Cuesheet

To either store the track and index structure of a CDDA along with its audio or to provide a mechanism to store locations of interest within a FLAC file, a cuesheet metadata block can be used. Certain aspects of this metadata block follow directly from the CDDA specification, called Red Book. For more information on the function and history of these aspects, please refer to Red Book.

A cuesheet block contains one or more tracks, each of which in turn contains one or more indexes.

The first 128 bytes MAY contain a catalog number for the stored content. This is stored using printable ASCII characters (0x20 through 0x7e inclusive). If no catalog number is present, all 128 bytes MUST be 0x00. If the catalog number is shorter than 128 characters, it MUST start at the first available byte and any unused bytes MUST be 0x00.

The next 8 bytes contain the number of lead-in samples as an unsigned number coded big-endian. This number should be 0 for cuesheets that do not belong to a CDDA. For a CDDA, it is the number of samples counting from the first sample that can be read from the disc until the first sample of the first index of the first track.

Following the number of lead-in samples is 1 bit that flags whether a cuesheet belongs to a CDDA: its value is 1 if it belongs to CDDA, its value is 0 otherwise.

Following the number of lead-in samples are 7 bits and 258 bytes that are not yet assigned, all bits MUST be zero.

Next is 1 byte containing the number of tracks that the cuesheet metadata block contains as an unsigned number.

Following the number of tracks are the tracks themselves, the specification of which follows.

### Cuesheet track

Each track starts with the 8 bytes containing the position of its first index in samples as an unsigned number coded big-endian. This number is relative to the start of the FLAC stream.

Following it is 1 byte containing the tracknumber as an unsigned number. Track number 0 MUST NOT be used.

Following are 12 bytes containing the ISRC for the track. See [the IFPI website for more information](https://isrc.ifpi.org/). In case the ISRC is not known or not available, this field MUST contain 12 0x00 bytes.

Following are 2 bits, the first a flag bit that is 0 for audio and 1 for non-audio, the second a flag bit that is 0 when no pre-emphasis was applied to the audio and 1 when pre-emphasis has been applied. These two bits correspond to CDDA subchannel Q bits 3 and 5 respectively.

Following are 6 bits and 13 bytes that are not yet assigned, all bits MUST be zero.

Following is 1 byte containing the number of index points for this track as an unsigned number. Each track MUST have at least one index point, except for the lead-out track which MUST have no index points.

Following the number of index points are the index points themselves, the specification of which follows.

### Cuesheet index

Each index point starts with the 8 bytes containing the position of its first index in samples as an unsigned number coded big-endian. This number is relative to the start of the track. In other words, to calculate the location of the index point relative to the start of the FLAC stream, the position of the index point has to be added to the position of the track it belongs to.

Next is 1 byte containing the number of the index point. In most implementations an index number of 0 is regarded as signalling the start of a pre-gap, while the index number 1 is the actual start of the track. If a pre-gap is present, it is often used to signal that a previous track has ended, but the next track has not yet begun.

Next are 3 bytes that are not yet assigned, all three MUST be 0x00.

## Picture

To store image data belonging to an audio file, a picture metadata block can be used. There are 21 different picture types defined, of which “front cover” is most often displayed by FLAC player software and hardware. The structure of a picture frame is very similar to an ID3v2 APIC frame. Because of this, length fields are 32-bit as they are in ID3v2, but as a FLAC metadata block has a length field that is only 24-bit, these 32-bit fields can never be fully used in FLAC.

The first 4 bytes contain an unsigned number coded big-endian between 0 and 20 describing the picture type according to the following table. Any number not in the table is currently not assigned and SHOULD NOT be used. There MUST NOT be more than one picture metadata block with type 1. There MUST NOT be more than one picture metadata block with type 2 in a FLAC file.

Value | Picture type
:-----|:-----------
0     | Other
1     | PNG file icon of 32x32 pixels
2     | General file icon
3     | Front cover
4     | Back cover
5     | Liner notes page
6     | Media label (e.g. CD, Vinyl or Cassette label)
7     | Lead artist, lead performer or soloist
8     | Artist or performer
9     | Conductor
10    | Band or orchestra
11    | Composer
12    | Lyricist or text writer
13    | Recording location
14    | During recording
15    | During performance
16    | Movie or video screen capture
17    | A bright colored fish
18    | Illustration
19    | Band or artist logotype
20    | Publisher or studio logotype

Following the picture type is the MIME-type of the image that is embedded. First, 4 bytes contain the length of the string as an unsigned number coded big-endian, directly followed by the MIME-string, which is not terminated in any way. The MIME-string MUST only consist of printable ASCII characters, i.e. 0x20 through 0x7e (inclusive) The MIME-string can also be --> (two dashes and a larger than sign) to indicate that the image data is not actually image data but instead a URL to an image.

Following the MIME-type is an (optional) description, which is stored the same way as the MIME-type: a length followed by the string itself. The length can be 0 to indicate no string is present. The string is coded UTF-8.

Following are 4 bytes coding the width of the image, 4 bytes coding the height of the image, 4 bytes coding the color depth of the image (in bits per pixel) and 4 bytes coding the number of colors used in case of an indexed image, zero otherwise. Each of these is an unsigned number coded big-endian

Following are 4 bytes containing the size of the images as an unsigned number coded big-endian. Note that while this number allows for images with a size of up to 4GiB, a FLAC metadata block can only be up to 16MiB in size.

Finally, directly following the size of the image is the image data itself.

# Frame structure

Directly after the last metadata block, one or more frames follow. Each frame consists of a frame header, one or more subframes, padding zero bits to achieve byte-alignment and a frame footer.

## Frame header

Each frame starts with the 15-bit frame sync code 0b111111111111100. Following the sync code is the blocking strategy bit, which MUST NOT change during the audio stream. The blocking strategy bit is 0 for a fixed blocksize stream or 1 for variable blocksize stream. If the blocking strategy is known, a decoder can search for a 16-bit sync code, either 0xF8 for a fixed blocksize stream or 0xF9 for a variable blocksize stream. To ease the search for the sync code and further reduction of false positives, all frames MUST start on a byte boundary.

Note that streams with a variable blocksize that do not have the blocksize strategy bit set to 1 can be encountered, as this bit was introduced a few years after the FLAC bitstream was frozen by assigning a previously unassigned bit for this task. See section [past changes](#past-changes) for more details.

Following the frame sync code and blocksize strategy bit are 4 bits referred to as the blocksize bits. Their value relates to the blocksize according to the following table, where v is the value of the 4 bits as an unsigned number.

Value           | Blocksize
:---------------|:-----------
0b0000          | currently not assigned
0b0001          | 192
0b0010 - 0b0101 | 144 \* (2\^v), i.e. 576, 1152, 2304 or 4608
0b0110          | blocksize minus 1 stored further down header as an 8-bit number
0b0111          | blocksize minus 1 stored further down header as a 16-bit number
0b1000 - 0b1111 | 2\^v, i.e. 256, 512, 1024, 2048, 4096, 8192, 16384 or 32768

The next 4 bits, referred to as the sample rate bits, contain the sample rate according to the following table

Value   | Sample rate
:-------|:-----------
0b0000  | sample rate only stored in streaminfo metadata block
0b0001  | 88.2 kHz
0b0010  | 176.4 kHz
0b0011  | 192 kHz
0b0100  | 8 kHz
0b0101  | 16 kHz
0b0110  | 22.05 kHz
0b0111  | 24 kHz
0b1000  | 32 kHz
0b1001  | 44.1 kHz
0b1010  | 48 kHz
0b1011  | 96 kHz
0b1100  | sample rate in kHz stored further down header as an 8-bit number
0b1101  | sample rate in Hz stored further down header as a 16-bit number
0b1110  | sample rate in Hz divided by 10 stored further down header as a 16-bit number
0b1111  | invalid

The next 4 bits (the first 4 bits of the fourth byte of each frame), referred to as the channel bits, code for both the number of channels as well as any stereo decorrelation used according to the following table, where v is the value of the 4 bits as an unsigned number. See also [the section channel ordering](#channel-ordering) and [the section on stereo decorrelation](#stereo-decorrelation).

Value           | Channels
:---------------|:-----------
0b0000 - 0b0111 | (v + 1) channels, stored without any interchannel decorrelation
0b1000          | 2 channels, stored as left/side stereo
0b1001          | 2 channels, stored as right/side stereo
0b1010          | 2 channels, stored as mid/side stereo
0b1011 - 0b1111 | currently not assigned

The next 3 bits code for the bit depth of the samples in the subframe according to the following table.

Value   | Bit depth
:-------|:-----------
0b000   | bit depth only stored in streaminfo metadata block
0b001   | 8 bits per sample
0b010   | 12 bits per sample
0b011   | currently not assigned
0b100   | 16 bits per sample
0b101   | 20 bits per sample
0b110   | 24 bits per sample
0b111   | currently not assigned

The next bit is currently not assigned and MUST be zero.

Following (starting at the fifth byte of the frame) is either a sample or a frame number. When dealing with variable blocksize streams, the sample number of the first sample in the frame is encoded. When the file contains a fixed blocksize stream, the frame number is encoded. The sample or frame number is stored in a variable length code like UTF-8, but extended to a maximum of 36 bit unencoded, 7 byte encoded. When a frame number is encoded, the value MUST NOT be larger than what fits a value 31 bit unencoded or 6 byte encoded. Please note that most general purpose UTF-8 encoders and decoders will not be able to handle these extended codes.

If the blocksize bits defined earlier in this section were 0b0110 or 0b0111 (blocksize minus 1 stored further down header), this follows the sample or frame number as an either a 8 or a 16 bit unsigned number coded big-endian.

Following either the frame/sample number or the blocksize is the sample rate, if the sample rate bits were 0b1100, 0b1101 or 0b1110 (sample rate stored further down header), as either an 8 or a 16 bit unsigned number coded big-endian.

Finally, after either the frame/sample number, the blocksize or the sample rate, is a 8-bit CRC. This CRC is initialized with 0 and has the polynomial x^8 + x^2 + x^1 + x^0. This CRC covers the whole frame header before the CRC, including the sync code.

## Subframes

Following the frame header are a number subframes equal to the number of audio channels. Each subblock is directly coded into a subframe, except when additional transformations are applied. See [the section on additional PCM transformations](#additional-pcm-transformations).

### Subframe header

Each subframe starts with a header. The first bit of the header is always 0, followed by 6 bits describing which subframe type is used according to the following table, where v is the value of the 6 bits as an unsigned number.

Value               | Subframe type
:-------------------|:-----------
0b000000            | Constant subframe
0b000001            | Verbatim subframe
0b000010 - 0b000111 | currently not assigned
0b001000 - 0b001100 | Subframe with a fixed predictor v-8, i.e. 0, 1, 2, 3 or 4
0b001101 - 0b011111 | currently not assigned
0b100000 - 0b111111 | Subframe with a linear predictor v-31, i.e. 1 through 32 (inclusive)

Following the subframe type bits is a bit that flags whether the subframe has any wasted bits. If it is 0, the subframe doesn’t have any wasted bits and the subframe header is complete. If it is 1, the subframe does have wasted bits and the number of wasted bits follows unary coded. [See the section on wasted bits](#wasted-bits).

### Constant subframe

In a constant subframe only a single sample is stored. This sample is stored as a signed integer number, coded big-endian, signed two's complement. The number of bits used to store this sample depends on the bit depth of the current subframe. The bit depth of a subframe is equal to the bit depth in the frame header, minus the number of wasted bits in that subblock, plus 1 bit when the current subframe is a side subframe. See also the [section on interchannel decorrelation](#stereo-decorrelation) and the [section on wasted bits per sample flag](#wasted-bits).

### Verbatim subframe

A verbatim subframe stores all samples unencoded in sequential order. See [section on Constant subframe](#constant-subframe) on how a sample is stored unencoded. The number of samples that need to be stored in a subframe is given by the blocksize in the frame header.

### Subframe with a fixed predictor

Five different fixed predictors are defined, one for each predictor order 0 through 4. To encode a signal with a fixed predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a fixed predictor, first the residual has to be decoded, after which for each sample the prediction can be added. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough fully decoded previous samples are needed to calculate the prediction.

Prediction and subsequent subtraction from the current sample or addition to the current residual sample MUST be implemented in signed integer math to eliminate the possibility of introducing rounding error. The minimum required size of the used signed integer data type depends on the sample bit depth and the predictor order, and can be calculated by adding the headroom bits in the table below to the subframe bit depth. For example, if the sample bit depth of the source is 16, the current subframe encodes a side channel (see the [section on interchannel decorrelation](#interchannel-decorrelation)) and the predictor order is 3, the minimum required size of the used signed integer data type is at least 16 + 1 + 3 = 20 bits.

Order | Prediction                                    | Derivation                              | Bits of headroom
:-----|:----------------------------------------------|:----------------------------------------|:----------------
0     | 0                                             | N/A                                     | 0
1     | s(n-1)                                        | N/A                                     | 1
2     | 2 * s(n-1) - s(n-2)                           | s(n-1) + ∆s(n-1)                        | 2
3     | 3 * s(n-1) - 3 * s(n-2) + s(n-3)              | s(n-1) + ∆s(n-1) + ∆∆s(n-1)             | 3
4     | 4 * s(n-1) - 6 * s(n-2) + 4 * s(n-3) - s(n-4) | s(n-1) + ∆s(n-1) + ∆∆s(n-1) + ∆∆∆s(n-1) | 4

Where
- n is the number of the sample being predicted
- s(n) is the sample being predicted
- s(n-1) is the sample before the one being predicted
- ∆s(n-1) is the difference between the previous sample and the sample before that, i.e. s(n-1) - s(n-2). This is the closest available first-order discrete derivative
- ∆∆s(n-1) is ∆s(n-1) - ∆s(n-2) or the closest available second-order discrete derivative
- ∆∆∆s(n-1) is ∆∆s(n-1) - ∆∆s(n-2) or the closest available third-order discrete derivative

For fixed predictor order 0, the prediction is always 0, thus each residual sample is equal to its corresponding input or decoded sample. The difference between a fixed predictor with order 0 and a verbatim subframe, is that a verbatim subframe stores all samples unencoded, while a fixed predictor with order 0 has all its samples processed by the residual coder.

The first order fixed predictor is comparable to how DPCM encoding works, as the resulting residual sample is the difference between the corresponding sample and the sample before it. The higher fixed predictors can be understood as polynomials fitted to the previous samples.

As the fixed predictors are specified, they do not have to be stored. The fixed predictor order specifies which predictor is used. To be able to predict samples, warm-up samples are stored, as the predictor needs previous samples in its prediction. The number of warm-up samples is equal to the predictor order. These warm-up samples directly follow the subframe header in unencoded form. See [section on Constant subframe](#constant-subframe) on how samples are stored unencoded. Directly following the warm-up samples is the coded residual.

### Subframe with a linear predictor

Whereas fixed predictors are well suited for simple signals, using a (non-fixed) linear predictor on more complex signals can improve compression by making the residual samples even smaller. There is a certain trade-off however, as storing the predictor coefficients takes up space as well.

In the FLAC format, a predictor is defined by up to 32 predictor coefficients and a right shift. To form a prediction, each coefficient is multiplied with its corresponding past sample, the results are added and this addition is then shifted right by the specified number of bits. To encode a signal with a linear predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a linear predictor, first the residual has to be decoded, after which for each sample the prediction can be added. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough fully decoded previous samples are needed to calculate the prediction.

A subframe with a linear predictor has ‘order’ number of warm-up samples directly following the subframe header. See [section on Constant subframe](#constant-subframe) on how samples are stored unencoded.

Following the warm up samples are the 4 bits containing the predictor coefficient precision minus 1 in bits as an unsigned number, e.g. 0b1000 means each predictor coefficient takes 9 bits. The value 0b1111 is invalid. 

Following the predictor coefficient precision are 5 bits containing the prediction right shift. This value was once defined as a signed number, but as a negative right shift leads to undefined behavior and as the need for such shifts is very rare, this number MUST be positive. A decoder could also verify that the first of the 5 bits is zero and read the next 4 bits as an unsigned number instead of reading the 5 bits as a signed number.

Following the prediction right shift are ‘order’ number of predictor coefficients, each using ‘prediction coefficient precision’ number of bits, stored the same way as the warm-up samples: coded big-endian, signed two’s complement. After these coefficients, the coded residual follows.

Please note that the order in which the predictor coefficients appear in the bitstream corresponds to which **past** sample they belong. In other words, the order of the predictor coefficients is opposite to the chronological order of the samples. So, the first predictor coefficient has to be multiplied with the sample directly before the sample that is being predicted, the second predictor coefficient has to be multiplied with the sample before that etc.

Prediction and subsequent subtraction from the current sample or addition to the current residual sample MUST be implemented in signed integer math to eliminate the possibility of introducing rounding error. The minimum required size of the used signed integer data type depends on the sample bit depth, the predictor coefficient precision and the predictor order. It can be calculated by adding the predictor coefficient precision, log2(predictor order) rounded up and subframe bit depth.

For example, if the sample bit depth of the source is 24, the current subframe encodes a side channel (see the [section on interchannel decorrelation](#interchannel-decorrelation)), the predictor order is 12 and the predictor coefficient precision is 15 bits, the minimum required size of the used signed integer data type is at least 24 + 1 + 15 + ceil(log2(12)) = 44 bits. As another example, with a side-channel subframe bit depth of 16, a predictor order of 8 and a predictor coefficient precision of 15 bits, the minimum required size of the used signed integer data type is 16 + 1 + 12 + ceil(log2(8)) = 32 bits.

### Coded residual

The first two bits in a coded residual indicate which coding method is used. If they are 0b00, the coded residual is in the form of a partitioned Rice code with 4-bit parameters. If they are 0b01, the coded residual is in the form of a partitioned Rice code with 5-bit parameters. The values 0b10 and 0b11 are currently not assigned.

Both defined coding methods work the same way, but differ in the number of bits used for rice parameters. The 4 bits that directly follow the coding method bits form the partition order, which is an unsigned number. The rest of the coded residual consists of 2^(partition order) partitions. For example, if the 4 bits are 0b1000, the partition order is 8, and the rest of the entropy block contains 2^8 = 256 partitions.

Each partition contains a certain amount of residual samples. The number of residual samples in the first partition is equal to (blocksize >> partition order) - predictor order, i.e. the blocksize divided by the number of partitions minus the predictor order. In all other partitions the number of residual samples is equal to (blocksize >> partition order).

The partition order MUST be so that the blocksize is evenly divisible by the number of partitions. This means for example that for all uneven blocksizes, only partition order 0 is allowed.  The partition order also MUST be so that the (blocksize >> partition order) is larger than the predictor order. This means for example that with a blocksize of 4096 and a predictor order of 4, partition order cannot be larger than 9.

In case the coded residual of the current subframe is one with a 4-bit Rice parameter (see table at the start of this section), the first 4 bits of each partition are either a rice parameter or an escape code. These 4 bits indicate an escape code if they are 0b1111, otherwise they contain the rice parameter as an unsigned number. In case the coded residual of the current subframe is one with a 5-bit Rice parameter, the first 5 bits indicate an escape code if they are 0b11111, otherwise they contain the rice parameter as an unsigned number as well.

In case an escape code was used, the partition does not contain a variable-length rice coded residual, but a fixed-length unencoded residual. Directly following the escape code are 5 bits containing the number of bits with which the residual is stored, as an unsigned number.

In case a rice parameter was provided, the partition contains a rice coded residual. The residual samples, which are signed numbers, are represented by unsigned numbers in the rice code. For positive numbers, the representation is the number doubled, for negative numbers, the representation is the number multiplied by -2 and has 1 subtracted. This representation of signed numbers is also known as zigzag encoding and the zigzag encoded residual is called the folded residual. The folded residual samples are then each divided by the rice parameter. The result of each division rounded down (the quotient) is stored unary, the remainder is stored binary.

Decoding the coded residual thus involves selecting the right coding method, finding the number of partitions, reading unary and binary parts of each codeword one-by-one and keeping track of when a new partition starts and thus when a new rice parameter needs to be read.

#### Example

Provided is a subframe with blocksize 24, predictor order 2 and partition order 2. This means this subframe has 22 residual samples, as the predictor needs 2 warm-up samples, for which no residual needs to be stored. The residual samples are stored in a partitioned rice code with 4-bit parameters. The rice parameter for the first partition is 6, for the second it is 2, the third it is 0 and the last partition uses an escape code, specifying 2 bits.

The residual samples have a folded representation as described earlier. The first 4 are divided by 2^6, the next 6 are divided by 2^2, the 6 that follow are divided by 2^0 and the last 6 are stored unencoded. See the following table as to how the residuals are represented

residual | folded residual | rice parameter | quotient | remainder | rice codeword
:---|:----|:---------------|:--|:---|:------------
25  | 50  | 6              | 0 | 50 | 0b1110010
-23 | 45  | 6              | 0 | 45 | 0b1101101
54  | 108 | 6              | 1 | 44 | 0b01101100
-34 | 67  | 6              | 1 | 3  | 0b01000011
-18 | 35  | 2              | 8 | 3  | 0b00000000111
4   | 8   | 2              | 2 | 0  | 0b00100
-2  | 3   | 2              | 0 | 3  | 0b111
1   | 2   | 2              | 0 | 2  | 0b110
 0  | 0   | 2              | 0 | 0  | 0b100
 3  | 6   | 2              | 1 | 2  | 0b0110
 0  | 0   | 0              | 0 | 0  | 0b1
 -1 | 1   | 0              | 1 | 0  | 0b01
 0  | 0   | 0              | 0 | 0  | 0b1
 1  | 2   | 0              | 2 | 0  | 0b001
 0  | 0   | 0              | 0 | 0  | 0b1
2   | 4   | 0              | 4 | 0  | 0b00001
 0  | -   | Escape, 2 bit  | - | -  | 0b00
 -1 | -   | Escape, 2 bit  | - | -  | 0b10
 0  | -   | Escape, 2 bit  | - | -  | 0b00
 1  | -   | Escape, 2 bit  | - | -  | 0b01
 0  | -   | Escape, 2 bit  | - | -  | 0b00
-1  | -   | Escape, 2 bit  | - | -  | 0b10


To sum up the whole coded residual for this example: the first two bits are 0b00 to indicate that this is a partitioned rice code with 4-bit parameters. This is followed by 0b0010 indicating that this code is split into four partitions. The next 4 bits are 0b0110, being the rice parameter of the first partition, 6. Following that are the rice codewords of the first 4 residuals, which can be found in the last column of the table above. The next 4 bits are 0b0010, being the rice parameter of the second partition, 2, followed by the rice codewords of the next 6 residuals. The next 4 bits are 0b000, the rice parameter of the third partition, 0, followed by the rice codewords of the corresponding 6 residuals. Finally, the last partition is in unencoded binary form, with 2 bits. This partition starts with the escape code, 0b1111, followed by the number of bits 0b00010 and the last 6 residuals.

## Frame footer

Following the last subframe is the frame footer. If the last subframe is not byte aligned (i.e. the bits required to store all subframes put together are not divisible by 8), zero bits are added until byte alignment is reached. Following this is a 16-bit CRC, initialized with 0, with polynomial x^16 + x^15 + x^2 + x^0. This CRC covers the whole frame excluding the 16-bit CRC, including the sync code.

# Format subset

To both enable streaming and simplify playback on devices with limited hardware capabilities, a subset of the FLAC format is specified, limiting certain aspects of the format. This restricted subset of the FLAC format is usually referred to as simply ‘the subset’, while files and streams complying to these restrictions are referred to as subset files and subset streams.

In streaming, a decoder usually does not have access to a streaminfo metadata block. Therefore, subset streams cannot rely on this for information. This imposes the following two restrictions:

- In subset streams the sample rate bits in a frame header MUST NOT be 0b0000, which means 'sample rate only stored in streaminfo metadata block'
- In subset streams the bit depth bits in a frame header MUST NOT be 0b000, which means 'bit depth only stored in streaminfo metadata block'

To simplify playback on devices with limited hardware capabilities, further restrictions are imposed regarding the maximum blocksize and complexity, to limit the maximum buffersize required. Three restrictions are added:

- In subset streams the blocksize MUST NOT exceed 16384
- In subset streams the Rice partition order MUST NOT exceed 8
- In subset streams where the sample rate is smaller than or equal to 48000 Hertz, the predictor order in any subframe MUST NOT exceed 12.
- In subset streams where the sample rate is smaller than or equal to 48000 Hertz, the blocksize MUST NOT exceed 4608

A file is subset compliant when all 6 restrictions are met.

# Channel ordering

A FLAC file can contain any number of channels from 1 to 8. For some applications the use of these channels is context dependent, for example when a FLAC file contains a multitrack recording. However, as FLAC is most often used for delivery to an audio consumer, defaults are provided according to the following table

Number of channels | Default channel order
:------------------|:---------------
1                  | front center
2                  | front left, front right
3                  | front left, front right, front center
4                  | front left, front right, back left, back right
5                  | front left, front right, front center, back/surround left, back/surround right
6                  | front left, front right, front center, low-frequency effects (LFE), back/surround left, back/surround right
7                  | front left, front right, front center, low-frequency effects (LFE), back center, side left, side right
8                  | front left, front right, front center, low-frequency effects (LFE), back left, back right, side left, side right

When channels different than the defaults in the table above are encoded, it is RECOMMENDED to use a channel mask, see [the section on channel masks][#channel-mask]. In case this is not usable, for example on a multitrack recording, a vorbis comment field can be added with an explanation.

# Additional PCM transformations

Besides prediction, there are two more transformations available in FLAC to improve compression, which are defined in this section.

## Stereo decorrelation

In case a frame uses left/side stereo, right/side stereo or mid/side stereo, a transformation is necessary directly before encoding both subframes or direct after decoding both subframes. Two transformations are defined: a side channel and a mid channel.

The side channel is the difference between the left and right channel, i.e. the numerical values of all samples in the second subblock of PCM audio subtracted from the numerical values of the corresponding samples in the first subblock of PCM audio. As this subtraction can result in numerical values twice as large as any of the original values, a side channel needs a bit depth 1 bit larger than the bit depth of the PCM audio.

The mid channel is the sum of the left and right channel, i.e. the numerical values of all samples in the second subblock of PCM audio added to the numerical values of the corresponding samples in the first subblock of PCM audio. A mid channel needs a bit depth 1 bit larger than the bit depth of the PCM audio much like a side channel. However, as in FLAC a mid channel is always paired with a side channel and as an odd numerical value in a side channel must always correspond to an odd numerical value in the mid channel for the corresponding sample, the mid channel can be shifted right 1 bit without becoming lossy.

In case of left/side stereo, the first subframe codes for the left channel (i.e. the first subblock of the PCM audio) and the second subframe codes for the side channel. Note that the side channel will have 1 bit of extra bit depth. In case of right/side stereo, which is actually coded in the order side/right, the first subframe codes for the side channel and the second subframe for the right channel (i.e. the second subblock of PCM audio), where once again the side channel will have 1 bit of extra bit depth.

For mid/side stereo, the first subframe codes for the mid channel, and the second subframe for the side channel. To losslessly reconstruct left and right, all samples of the mid channel first have to be shifted left by one bit, and 1 has to be added for each sample where the corresponding sample in the side channel is odd. After this reconstruction of the mid channel, the left channel is restored by adding the side channel to the mid channel and shifting right by 1 bit, while for the right channel the side channel has to be subtracted from the mid channel and the result shifted right by 1 bit.


On encoding the stereo decorrelation step takes place after blocking, before subframes are coded. On decoding, reassembling the two channels happens after both subframes have been fully decoded.

## Wasted bits

Certain file formats, like AIFF, can store audio samples with a bit depth that is not an integer number of bytes by padding them with least significant zero bits to a bit depth that is an integer number of bytes. For example, shifting a 14-bit sample right by 2 pads it to a 16-bit sample, which then has two zero least-significant bits. In this specification, these least-significant zero bits are referred to as wasted bits-per-sample or simply wasted bits. They are wasted in a sense that they contain no information, but are stored anyway.

In case a FLAC encoder detects such wasted bits in an audio subblock, it can decide to ignore these wasted bits, and code the subframe with only the non-wasted bits. For example, if the frame header preceding a subframe specifies a sample size of 16 bits per sample and the subframe header specifies 3 wasted bits, samples in that subframe are coded as 13 bits per sample.

If a subframe specifies 'k' number of wasted bits, a decoder MUST add k least-significant zero bits by shifting left (padding) after decoding a sample from that subframe. In case the frame has left/side, right/side or mid/side stereo, padding MUST happen to a sample before it is used to reconstruct a left or right sample.

Besides audio files that have a certain number of wasted bits for the whole file, there exist audio files in which the number of wasted bits varies. There are DVD-Audio discs in which blocks of samples have had their least-significant bits selectively zeroed, as to slightly improve the compression of their otherwise lossless Meridian Lossless Packing codec. There are also audio processors like lossyWAV that enable users to improve compression of their files by a lossless audio codec in a non-lossless way. Because of this the number of wasted bits MAY change between frames and MAY differ between subframes.

So, in effect, the detection (in encoding) of wasted bits happens after stereo decorrelation and before prediction, reconstruction (in decoding) of wasted bits happens after calculating a sample value from the predictor and residual but before stereo reassembling.

# Past changes

The FLAC format was originally specified in December 2000 and more or less finalized in March 2001. While the specification has seen several additions over the years, there has been one substantial change to the format.

Before July 2007, variable blocksize streams were not explicitly marked as such by a flag bit in the frame header. A decoder had two ways to detect a variable blocksize stream, either by comparing the minimum and maximum blocksize in the STREAMINFO metadata block, or by detecting a change of blocksize during a stream which could in theory not happen at all. As the meaning of one number in the frame header depends on whether or not a stream is variable blocksize, one of the reserved bits was changed to be used as a blocksize strategy flag, facilitating easier detection. [See also the section frame header](#frame-header).

Along with the addition of a new flag, the meaning of the blocksize bits was subtly changed. Before, blocksize bits 0b0001-0b0101 and 0b1000-0b1111 could only be used for fixed blocksize streams, while 0b0110 and 0b0111 could be used for both fixed blocksize and variable blocksize streams. After the change, these restrictions were lifted and 0b0001-0b1111 could all be used for both variable blocksize and fixed blocksize streams.

Another change to the format that is worth noting is the addition of Rice coded residuals with a 5-bit Rice parameter. This was added in July 2007 as it was found that the optimal Rice parameter for the residual of certain audio signals with a 24-bit bit depth lies outside the range allowed by the 4-bit Rice parameter.

# Security Considerations

Like any other codec (such as [@?RFC6716]), FLAC should not be used with insecure ciphers or cipher modes that are vulnerable to known plaintext attacks. Some of the header bits as well as the padding are easily predictable.

Implementations of the FLAC codec need to take appropriate security considerations into account. Those related to denial of service are outlined in Section 2.1 of [@!RFC4732]. It is extremely important for the decoder to be robust against malicious payloads. Malicious payloads **MUST NOT** cause the decoder to overrun its allocated memory or to take an excessive amount of resources to decode. An overrun in allocated memory could lead to arbitrary code execution by an attacker. The same applies to the encoder, even though problems in encoders are typically rarer. Malicious audio streams **MUST NOT** cause the encoder to misbehave because this would allow an attacker to attack transcoding gateways. An example is allocating more memory than available especially with blocksizes of more than 10000 or with big metadata blocks, or not allocating enough memory before copying data, which lead to execution of malicious code, crashes, freezes or reboots on some known implementations.
See the [FLAC decoder testbench](https://wiki.hydrogenaud.io/index.php?title=FLAC_decoder_testbench) for a non-exhaustive list of FLAC files with extreme configurations which lead to crashes or reboots on some known implementations.

None of the content carried in FLAC is intended to be executable.
