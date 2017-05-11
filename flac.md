# format

This is a detailed description of the FLAC format. There is also a
companion document that describes [FLAC-to-Ogg
mapping](ogg_mapping.html).

For a user-oriented overview, see [About the FLAC
Format](documentation_format_overview.html).

# Acknowledgments

FLAC owes much to the many people who have advanced the audio
compression field so freely. For instance:
-   [A. J. Robinson](http://svr-www.eng.cam.ac.uk/~ajr/) for his work on
    [Shorten](http://svr-www.eng.cam.ac.uk/reports/abstracts/robinson_tr156.html);
    his paper is a good starting point on some of the basic methods used
    by FLAC. FLAC trivially extends and improves the fixed predictors,
    LPC coefficient quantization, and Rice coding used in Shorten.
-   [S. W.
    Golomb](https://web.archive.org/web/20040215005354/http://csi.usc.edu/faculty/golomb.html)
    and Robert F. Rice; their universal codes are used by FLAC's entropy
    coder.
-   N. Levinson and J. Durbin; the reference encoder uses an algorithm
    developed and refined by them for determining the LPC coefficients
    from the autocorrelation coefficients.
-   And of course, [Claude
    Shannon](http://en.wikipedia.org/wiki/Claude_Shannon)

# Scope

It is a known fact that no algorithm can losslessly compress all
possible input, so most compressors restrict themselves to a useful
domain and try to work as well as possible within that domain. FLAC's
domain is audio data. Though it can losslessly **code** any input, only
certain kinds of input will get smaller. FLAC exploits the fact that
audio data typically has a high degree of sample-to-sample correlation.

Within the audio domain, there are many possible subdomains. For
example: low bitrate speech, high-bitrate multi-channel music, etc. FLAC
itself does not target a specific subdomain but many of the default
parameters of the reference encoder are tuned to CD-quality music data
(i.e. 44.1kHz, 2 channel, 16 bits per sample). The effect of the
encoding parameters on different kinds of audio data will be examined
later.

# Architecture

Similar to many audio coders, a FLAC encoder has the following stages:
-   [Blocking](#blocking). The input is broken up into many contiguous
    blocks. With FLAC, the blocks may vary in size. The optimal size of
    the block is usually affected by many factors, including the sample
    rate, spectral characteristics over time, etc. Though FLAC allows
    the block size to vary within a stream, the reference encoder uses a
    fixed block size.
-   [Interchannel Decorrelation](#interchannel). In the case of stereo
    streams, the encoder will create mid and side signals based on the
    average and difference (respectively) of the left and right
    channels. The encoder will then pass the best form of the signal to
    the next stage.
-   [Prediction](#prediction). The block is passed through a prediction
    stage where the encoder tries to find a mathematical description
    (usually an approximate one) of the signal. This description is
    typically much smaller than the raw signal itself. Since the methods
    of prediction are known to both the encoder and decoder, only the
    parameters of the predictor need be included in the compressed
    stream. FLAC currently uses four different classes of predictors
    (described in the [prediction](#prediction) section), but the format
    has reserved space for additional methods. FLAC allows the class of
    predictor to change from block to block, or even within the channels
    of a block.
-   [Residual coding](#residualcoding). If the predictor does not
    describe the signal exactly, the difference between the original
    signal and the predicted signal (called the error or residual
    signal) must be coded losslessy. If the predictor is effective, the
    residual signal will require fewer bits per sample than the original
    signal. FLAC currently uses only one method for encoding the
    residual (see the [Residual coding](#residualcoding) section), but
    the format has reserved space for additional methods. FLAC allows
    the residual coding method to change from block to block, or even
    within the channels of a block.

In addition, FLAC specifies a metadata system, which allows arbitrary
information about the stream to be included at the beginning of the
stream.

# Definitions

Many terms like "block" and "frame" are used to mean different things in
differenct encoding schemes. For example, a frame in MP3 corresponds to
many samples across several channels, whereas an S/PDIF frame represents
just one sample for each channel. The definitions we use for FLAC
follow. Note that when we talk about blocks and subblocks we are
referring to the raw unencoded audio data that is the input to the
encoder, and when we talk about frames and subframes, we are referring
to the FLAC-encoded data.
-   **Block**: One or more audio samples that span several channels.
-   **Subblock**: One or more audio samples within a channel. So a block
    contains one subblock for each channel, and all subblocks contain
    the same number of samples.
-   **Blocksize**: The number of samples in any of a block's subblocks.
    For example, a one second block sampled at 44.1KHz has a blocksize
    of 44100, regardless of the number of channels.
-   **Frame**: A frame header plus one or more subframes.
-   **Subframe**: A subframe header plus one or more encoded samples
    from a given channel. All subframes within a frame will contain the
    same number of samples.

# Blocking

The size used for blocking the audio data has a direct effect on the
compression ratio. If the block size is too small, the resulting large
number of frames mean that excess bits will be wasted on frame headers.
If the block size is too large, the characteristics of the signal may
vary so much that the encoder will be unable to find a good predictor.
In order to simplify encoder/decoder design, FLAC imposes a minimum
block size of 16 samples, and a maximum block size of 65535 samples.
This range covers the optimal size for all of the audio data FLAC
supports.

Currently the reference encoder uses a fixed block size, optimized on
the sample rate of the input. Future versions may vary the block size
depending on the characteristics of the signal.

Blocked data is passed to the predictor stage one subblock (channel) at
a time. Each subblock is independently coded into a subframe, and the
subframes are concatenated into a frame. Because each channel is coded
separately, it means that one channel of a stereo frame may be encoded
as a constant subframe, and the other an LPC subframe.

# Interchannel Decorrelation

In stereo streams, many times there is an exploitable amount of
correlation between the left and right channels. FLAC allows the frames
of stereo streams to have different channel assignments, and an encoder
may choose to use the best representation on a frame-by-frame basis.
-   **Independent**. The left and right channels are coded
    independently.
-   **Mid-side**. The left and right channels are transformed into mid
    and side channels. The mid channel is the midpoint (average) of the
    left and right signals, and the side is the difference signal (left
    minus right).
-   **Left-side**. The left channel and side channel are coded.
-   **Right-side**. The right channel and side channel are coded

Surprisingly, the left-side and right-side forms can be the most
efficient in many frames, even though the raw number of bits per sample
needed for the original signal is slightly more than that needed for
independent or mid-side coding.

# Prediction

FLAC uses four methods for modeling the input signal:
-   **Verbatim**. This is essentially a zero-order predictor of the
    signal. The predicted signal is zero, meaning the residual is the
    signal itself, and the compression is zero. This is the baseline
    against which the other predictors are measured. If you feed random
    data to the encoder, the verbatim predictor will probably be used
    for every subblock. Since the raw signal is not actually passed
    through the residual coding stage (it is added to the stream
    'verbatim'), the encoding results will not be the same as a
    zero-order linear predictor.
-   **Constant**. This predictor is used whenever the subblock is pure
    DC ("digital silence"), i.e. a constant value throughout. The signal
    is run-length encoded and added to the stream.
-   **Fixed linear predictor**. FLAC uses a class of
    computationally-efficient fixed linear predictors (for a good
    description, see
    [audiopak](http://www.hpl.hp.com/techreports/1999/HPL-1999-144.pdf)
    and
    [shorten](http://svr-www.eng.cam.ac.uk/reports/abstracts/robinson_tr156.html)).
    FLAC adds a fourth-order predictor to the zero-to-third-order
    predictors used by Shorten. Since the predictors are fixed, the
    predictor order is the only parameter that needs to be stored in the
    compressed stream. The error signal is then passed to the residual
    coder.
-   **FIR Linear prediction**. For more accurate modeling (at a cost of
    slower encoding), FLAC supports up to 32nd order FIR linear
    prediction (again, for information on linear prediction, see
    [audiopak](http://www.hpl.hp.com/techreports/1999/HPL-1999-144.pdf)
    and
    [shorten](http://svr-www.eng.cam.ac.uk/reports/abstracts/robinson_tr156.html)).
    The reference encoder uses the Levinson-Durbin method for
    calculating the LPC coefficients from the autocorrelation
    coefficients, and the coefficients are quantized before computing
    the residual. Whereas encoders such as Shorten used a fixed
    quantization for the entire input, FLAC allows the quantized
    coefficient precision to vary from subframe to subframe. The FLAC
    reference encoder estimates the optimal precision to use based on
    the block size and dynamic range of the original signal.

# Residual Coding

FLAC currently defines two similar methods for the coding of the error
signal from the prediction stage. The error signal is coded using Rice
codes in one of two ways: 1) the encoder estimates a single Rice
parameter based on the variance of the residual and Rice codes the
entire residual using this parameter; 2) the residual is partitioned
into several equal-length regions of contiguous samples, and each region
is coded with its own Rice parameter based on the region's mean. (Note
that the first method is a special case of the second method with one
partition, except the Rice parameter is based on the residual variance
instead of the mean.)

The FLAC format has reserved space for other coding methods. Some
possiblities for volunteers would be to explore better context-modeling
of the Rice parameter, or Huffman coding. See
[LOCO-I](http://www.hpl.hp.com/techreports/98/HPL-98-193.html) and
[pucrunch](http://www.cs.tut.fi/~albert/Dev/pucrunch/packing.html) for
descriptions of several universal codes.

# Format

This section specifies the FLAC bitstream format. FLAC has no format
version information, but it does contain reserved space in several
places. Future versions of the format may use this reserved space safely
without breaking the format of older streams. Older decoders may choose
to abort decoding or skip data encoded with newer methods. Apart from
reserved patterns, in places the format specifies invalid patterns,
meaning that the patterns may never appear in any valid bitstream, in
any prior, present, or future versions of the format. These invalid
patterns are usually used to make the synchronization mechanism more
robust.

All numbers used in a FLAC bitstream are integers; there are no
floating-point representations. All numbers are big-endian coded. All
numbers are unsigned unless otherwise specified.

Before the formal description of the stream, an overview might be
helpful.
-   A FLAC bitstream consists of the "fLaC" marker at the beginning of
    the stream, followed by a mandatory metadata block (called the
    STREAMINFO block), any number of other metadata blocks, then the
    audio frames.
-   FLAC supports up to 128 kinds of metadata blocks; currently the
    following are defined:
    -   [STREAMINFO](#def_STREAMINFO): This block has information
        about the whole stream, like sample rate, number of channels,
        total number of samples, etc. It must be present as the first
        metadata block in the stream. Other metadata blocks may follow,
        and ones that the decoder doesn't understand, it will skip.
    -   [APPLICATION](#def_APPLICATION): This block is for use by
        third-party applications. The only mandatory field is a 32-bit
        identifier. This ID is granted upon request to an application by
        the FLAC maintainers. The remainder is of the block is defined
        by the registered application. Visit the [registration
        page](id.html) if you would like to register an ID for your
        application with FLAC.
    -   [PADDING](#def_PADDING): This block allows for an arbitrary
        amount of padding. The contents of a PADDING block have no
        meaning. This block is useful when it is known that metadata
        will be edited after encoding; the user can instruct the encoder
        to reserve a PADDING block of sufficient size so that when
        metadata is added, it will simply overwrite the padding (which
        is relatively quick) instead of having to insert it into the
        right place in the existing file (which would normally require
        rewriting the entire file).
    -   [SEEKTABLE](#def_SEEKTABLE): This is an optional block for
        storing seek points. It is possible to seek to any given sample
        in a FLAC stream without a seek table, but the delay can be
        unpredictable since the bitrate may vary widely within a stream.
        By adding seek points to a stream, this delay can be
        significantly reduced. Each seek point takes 18 bytes, so 1%
        resolution within a stream adds less than 2k. There can be only
        one SEEKTABLE in a stream, but the table can have any number of
        seek points. There is also a special 'placeholder' seekpoint
        which will be ignored by decoders but which can be used to
        reserve space for future seek point insertion.
    -   [VORBIS\_COMMENT](#def_VORBIS_COMMENT): This block is for
        storing a list of human-readable name/value pairs. Values are
        encoded using UTF-8. It is an implementation of the [Vorbis
        comment
        specification](http://xiph.org/vorbis/doc/v-comment.html)
        (without the framing bit). This is the only officially supported
        tagging mechanism in FLAC. There may be only one VORBIS\_COMMENT
        block in a stream. In some external documentation, Vorbis
        comments are called FLAC tags to lessen confusion.
    -   [CUESHEET](#def_CUESHEET): This block is for storing various
        information that can be used in a cue sheet. It supports track
        and index points, compatible with Red Book CD digital audio
        discs, as well as other CD-DA metadata such as media catalog
        number and track ISRCs. The CUESHEET block is especially useful
        for backing up CD-DA discs, but it can be used as a general
        purpose cueing mechanism for playback.
    -   [PICTURE](#def_PICTURE): This block is for storing pictures
        associated with the file, most commonly cover art from CDs.
        There may be more than one PICTURE block in a file. The picture
        format is similar to the [APIC frame in
        ID3v2](http://www.id3.org/id3v2.4.0-frames). The PICTURE block
        has a type, MIME type, and UTF-8 description like ID3v2, and
        supports external linking via URL (though this is discouraged).
        The differences are that there is no uniqueness constraint on
        the description field, and the MIME type is mandatory. The FLAC
        PICTURE block also includes the resolution, color depth, and
        palette size so that the client can search for a suitable
        picture without having to scan them all.
-   The audio data is composed of one or more audio frames. Each frame
    consists of a frame header, which contains a sync code, information
    about the frame like the block size, sample rate, number of
    channels, et cetera, and an 8-bit CRC. The frame header also
    contains either the sample number of the first sample in the frame
    (for variable-blocksize streams), or the frame number (for
    fixed-blocksize streams). This allows for fast, sample-accurate
    seeking to be performed. Following the frame header are encoded
    subframes, one for each channel, and finally, the frame is
    zero-padded to a byte boundary. Each subframe has its own header
    that specifies how the subframe is encoded.
-   Since a decoder may start decoding in the middle of a stream, there
    must be a method to determine the start of a frame. A 14-bit sync
    code begins each frame. The sync code will not appear anywhere else
    in the frame header. However, since it may appear in the subframes,
    the decoder has two other ways of ensuring a correct sync. The first
    is to check that the rest of the frame header contains no invalid
    data. Even this is not foolproof since valid header patterns can
    still occur within the subframes. The decoder's final check is to
    generate an 8-bit CRC of the frame header and compare this to the
    CRC stored at the end of the frame header.
-   Again, since a decoder may start decoding at an arbitrary frame in
    the stream, each frame header must contain some basic information
    about the stream because the decoder may not have access to the
    STREAMINFO metadata block at the start of the stream. This
    information includes sample rate, bits per sample, number of
    channels, etc. Since the frame header is pure overhead, it has a
    direct effect on the compression ratio. To keep the frame header as
    small as possible, FLAC uses lookup tables for the most commonly
    used values for frame parameters. For instance, the sample rate part
    of the frame header is specified using 4 bits. Eight of the bit
    patterns correspond to the commonly used sample rates of
    8/16/22.05/24/32/44.1/48/96 kHz. However, odd sample rates can be
    specified by using one of the 'hint' bit patterns, directing the
    decoder to find the exact sample rate at the end of the frame
    header. The same method is used for specifying the block size and
    bits per sample. In this way, the frame header size stays small for
    all of the most common forms of audio data.
-   Individual subframes (one for each channel) are coded separately
    within a frame, and appear serially in the stream. In other words,
    the encoded audio data is NOT channel-interleaved. This reduces
    decoder complexity at the cost of requiring larger decode buffers.
    Each subframe has its own header specifying the attributes of the
    subframe, like prediction method and order, residual coding
    parameters, etc. The header is followed by the encoded audio data
    for that channel.
-   [FLAC](#flac-subset) specifies a subset of itself as the Subset format.
    The purpose of this is to ensure that any streams encoded according
    to the Subset are truly "streamable", meaning that a decoder that
    cannot seek within the stream can still pick up in the middle of the
    stream and start decoding. It also makes hardware decoder
    implementations more practical by limiting the encoding parameters
    such that decoder buffer sizes and other resource requirements can
    be easily determined. [flac]{.commandname} generates Subset streams
    by default unless the "--lax" command-line option is used. The
    Subset makes the following limitations on what may be used in the
    stream:
    -   The blocksize bits in the [frame header](#frame_header) must be
        0001-1110. The blocksize must be &lt;=16384; if the sample rate
        is &lt;= 48000Hz, the blocksize must be &lt;=4608.
    -   The sample rate bits in the [frame header](#frame_header) must
        be 0001-1110.
    -   The bits-per-sample bits in the [frame header](#frame_header)
        must be 001-111.
    -   If the sample rate is &lt;= 48000Hz, the filter order in [LPC
        subframes](#subframe_lpc) must be less than or equal to 12, i.e.
        the subframe type bits in the [subframe
        header](#subframe_header) may not be 101100-111111.
    -   The Rice partition order in a [Rice-coded residual
        section](#partitioned_rice) must be less than or equal to 8.

The following tables constitute a formal description of the FLAC format.
Numbers in angle brackets indicate how many bits are used for a given
field.

## STREAM
- <32> "fLaC", the FLAC stream marker in ASCII, meaning byte 0 of the stream is 0x66, followed by 0x4C 0x61 0x43
- [*METADATA\_BLOCK*](#metadata_block_streaminfo) This is the mandatory STREAMINFO metadata block that has the basic properties of the stream
- [*METADATA\_BLOCK*](#metadata_block) Zero or more metadata blocks
- [*FRAME*](#frame)+ One or more audio frames

## METADATA_BLOCK
- [METADATA\_BLOCK\_HEADER](#metadata_block_header) A block header that specifies the type and size of the metadata block data.
- [METADATA\_BLOCK\_DATA](#metadata_block_data)

## METADATA_BLOCK_HEADER
- <1> Last-metadata-block flag: '1' if this block is the last metadata block before the audio blocks, '0' otherwise.
- <7> BLOCK\_TYPE
  -   0 : STREAMINFO
  -   1 : PADDING
  -   2 : APPLICATION
  -   3 : SEEKTABLE
  -   4 : VORBIS\_COMMENT
  -   5 : CUESHEET
  -   6 : PICTURE
  -   7-126 : reserved
  -   127 : invalid, to avoid confusion with a frame sync code
- <24> Length (in bytes) of metadata to follow (does not include the size of the METADATA\_BLOCK\_HEADER)

## METADATA_BLOCK_DATA
- [METADATA\_BLOCK\_STREAMINFO](#metadata_block_streaminfo)
- [*METADATA\_BLOCK\_PADDING*](#metadata_block_padding)
- [*METADATA\_BLOCK\_APPLICATION*](#metadata_block_application)
- [*METADATA\_BLOCK\_SEEKTABLE*](#metadata_block_seektable)
- [*METADATA\_BLOCK\_VORBIS\_COMMENT*](#metadata_block_vorbis_comment)
- [*METADATA\_BLOCK\_CUESHEET*](#metadata_block_cuesheet)
- [*METADATA\_BLOCK\_PICTURE*](#metadata_block_picture) The block data must match the block type in the block header.

## METADATA_BLOCK_STREAMINFO
- <16> The minimum block size (in samples) used in the stream.
- <16> The maximum block size (in samples) used in the stream. (Minimum blocksize == maximum blocksize) implies a fixed-blocksize stream.
- <24> The minimum frame size (in bytes) used in the stream. May be 0 to imply the value is not known.
- <24> The maximum frame size (in bytes) used in the stream. May be 0 to imply the value is not known.
- <20> Sample rate in Hz. Though 20 bits are available, the maximum sample rate is limited by the structure of frame headers to 655350Hz. Also, a value of 0 is invalid.
- <3> (number of channels)-1. FLAC supports from 1 to 8 channels
- <5> (bits per sample)-1. FLAC supports from 4 to 32 bits per sample. Currently the reference encoder and decoders only support up to 24 bits per sample.
- <36> Total samples in stream. 'Samples' means inter-channel sample, i.e. one second of 44.1Khz audio will have 44100 samples regardless of the number of channels. A value of zero here means the number of total samples is unknown.
- <128> MD5 signature of the unencoded audio data. This allows the decoder to determine if an error exists in the audio data even when the error does not result in an invalid bitstream.

NOTES
- FLAC specifies a minimum block size of 16 and a maximum block size of 65535, meaning the bit patterns corresponding to the numbers 0-15 in the minimum blocksize and maximum blocksize fields are invalid.

## METADATA_BLOCK_PADDING
- < n > n '0' bits (n must be a multiple of 8)

## METADATA_BLOCK_APPLICATION
- <32> Registered application ID. (Visit the [registration page](id.html) to register an ID with FLAC.)
- < n > Application data (n must be a multiple of 8)

## METADATA_BLOCK_SEEKTABLE
- [*SEEKPOINT*](#seekpoint)+ One or more seek points.

NOTE
- The number of seek points is implied by the metadata header 'length' field, i.e. equal to length / 18.

## SEEKPOINT
- <64> Sample number of first sample in the target frame, or 0xFFFFFFFFFFFFFFFF for a placeholder point.
- <64> Offset (in bytes) from the first byte of the first frame header to the first byte of the target frame's header.
- <16> Number of samples in the target frame.

NOTES
-   For placeholder points, the second and third field values are
    undefined.
-   Seek points within a table must be sorted in ascending order by
    sample number.
-   Seek points within a table must be unique by sample number, with the
    exception of placeholder points.
-   The previous two notes imply that there may be any number of
    placeholder points, but they must all occur at the end of the table.

## METADATA_BLOCK_VORBIS_COMMENT
- < n > Also known as FLAC tags, the contents of a vorbis comment packet as specified [here](http://www.xiph.org/vorbis/doc/v-comment.html) (without the framing bit). Note that the vorbis comment spec allows for on the order of 2 \^ 64 bytes of data where as the FLAC metadata block is limited to 2 \^ 24 bytes. Given the stated purpose of vorbis comments, i.e. human-readable textual information, this limit is unlikely to be restrictive. Also note that the 32-bit field lengths are little-endian coded according to the vorbis spec, as opposed to the usual big-endian coding of fixed-length integers in the rest of FLAC.

## METADATA_BLOCK_CUESHEET
- <128\*8> Media catalog number, in ASCII printable characters 0x20-0x7e. In general, the media catalog number may be 0 to 128 bytes long; any unused characters should be right-padded with NUL characters. For CD-DA, this is a thirteen digit number, followed by 115 NUL bytes.
- <64> The number of lead-in samples. This field has meaning only for CD-DA cuesheets; for other uses it should be 0. For CD-DA, the lead-in is the TRACK 00 area where the table of contents is stored; more precisely, it is the number of samples from the first sample of the media to the first sample of the first index point of the first track. According to the Red Book, the lead-in must be silence and CD grabbing software does not usually store it; additionally, the lead-in must be at least two seconds but may be longer. For these reasons the lead-in length is stored here so that the absolute position of the first track can be computed. Note that the lead-in stored here is the number of samples up to the first index point of the first track, not necessarily to INDEX 01 of the first track; even the first track may have INDEX 00 data.
- <1> `1` if the CUESHEET corresponds to a Compact Disc, else `0`.
- <7+258\*8> Reserved. All bits must be set to zero.
- <8> The number of tracks. Must be at least 1 (because of the requisite lead-out track). For CD-DA, this number must be no more than 100 (99 regular tracks and one lead-out track).
- [*CUESHEET\_TRACK*](#cuesheet_track)+ One or more tracks. A CUESHEET block is required to have a lead-out track; it is always the last track in the CUESHEET. For CD-DA, the lead-out track number must be 170 as specified by the Red Book, otherwise is must be 255.

## CUESHEET_TRACK
- <64> Track offset in samples, relative to the beginning of the FLAC audio stream. It is the offset to the first index point of the track. (Note how this differs from CD-DA, where the track's offset in the TOC is that of the track's INDEX 01 even if there is an INDEX 00.) For CD-DA, the offset must be evenly divisible by 588 samples (588 samples = 44100 samples/sec \* 1/75th of a sec).
- <8> Track number. A track number of 0 is not allowed to avoid conflicting with the CD-DA spec, which reserves this for the lead-in. For CD-DA the number must be 1-99, or 170 for the lead-out; for non-CD-DA, the track number must for 255 for the lead-out. It is not required but encouraged to start with track 1 and increase sequentially. Track numbers must be unique within a CUESHEET.
- <12\*8> Track ISRC. This is a 12-digit alphanumeric code; see [here](http://isrc.ifpi.org/) and [here](http://www.disctronics.co.uk/technology/cdaudio/cdaud_isrc.htm). A value of 12 ASCII NUL characters may be used to denote absence of an ISRC.
- <1> The track type: 0 for audio, 1 for non-audio. This corresponds to the CD-DA Q-channel control bit 3.
- <1> The pre-emphasis flag: 0 for no pre-emphasis, 1 for pre-emphasis. This corresponds to the CD-DA Q-channel control bit 5; see [here](http://www.chipchapin.com/CDMedia/cdda9.php3).
- <6+13\*8> Reserved. All bits must be set to zero.
- <8> The number of track index points. There must be at least one index in every track in a CUESHEET except for the lead-out track, which must have zero. For CD-DA, this number may be no more than 100.
- [*CUESHEET\_TRACK\_INDEX*](#cuesheet_track_index)+ For all tracks except the lead-out track, one or more track index points.

## CUESHEET_TRACK_INDEX
- <64> Offset in samples, relative to the track offset, of the index point. For CD-DA, the offset must be evenly divisible by 588 samples (588 samples = 44100 samples/sec \* 1/75th of a sec). Note that the offset is from the beginning of the track, not the beginning of the audio data.
- <8> The index point number. For CD-DA, an index number of 0 corresponds to the track pre-gap. The first index in a track must have a number of 0 or 1, and subsequently, index numbers must increase by 1. Index numbers must be unique within a track.
- <3\*8> Reserved. All bits must be set to zero.

## METADATA_BLOCK_PICTURE
- <32> The picture type according to the ID3v2 APIC frame:
  -   0 - Other
  -   1 - 32x32 pixels 'file icon' (PNG only)
  -   2 - Other file icon
  -   3 - Cover (front)
  -   4 - Cover (back)
  -   5 - Leaflet page
  -   6 - Media (e.g. label side of CD)
  -   7 - Lead artist/lead performer/soloist
  -   8 - Artist/performer
  -   9 - Conductor
  -   10 - Band/Orchestra
  -   11 - Composer
  -   12 - Lyricist/text writer
  -   13 - Recording Location
  -   14 - During recording
  -   15 - During performance
  -   16 - Movie/video screen capture
  -   17 - A bright coloured fish
  -   18 - Illustration
  -   19 - Band/artist logotype
  -   20 - Publisher/Studio logotype

Others are reserved and should not be used. There may only be one each
of picture type 1 and 2 in a file.

- <32> The length of the MIME type string in bytes.
- <n\*8> The MIME type string, in printable ASCII characters 0x20-0x7e. The MIME type may also be `-->` to signify that the data part is a URL of the picture instead of the picture data itself.
- <32> The length of the description string in bytes.
- <n\*8> The description of the picture, in UTF-8.
- <32> The width of the picture in pixels.
- <32> The height of the picture in pixels.
- <32> The color depth of the picture in bits-per-pixel.
- <32> For indexed-color pictures (e.g. GIF), the number of colors used, or `0` for non-indexed pictures.
- <32> The length of the picture data in bytes.
- <n\*8> The binary picture data.

## FRAME
- [*FRAME\_HEADER*](#frame_header)
 
- [*SUBFRAME*](#subframe)+ One SUBFRAME per channel.
- <?> Zero-padding to byte alignment.
- `FRAME_FOOTER`
 

## FRAME_HEADER
- <14> Sync code '11111111111110'
- <1> Reserved: [\[1\]](#frame_header_notes)
   -   0 : mandatory value
   -   1 : reserved for future use

- <1> Blocking strategy: [\[2\]](#frame_header_notes) [\[3\]](#frame_header_notes)\
  -   0 : fixed-blocksize stream; frame header encodes the frame number
  -   1 : variable-blocksize stream; frame header encodes the sample number

- <4> Block size in inter-channel samples:
  -   0000 : reserved
  -   0001 : 192 samples
  -   0010-0101 : 576 \* (2\^(n-2)) samples, i.e. 576/1152/2304/4608
  -   0110 : get 8 bit (blocksize-1) from end of header
  -   0111 : get 16 bit (blocksize-1) from end of header
  -   1000-1111 : 256 \* (2\^(n-8)) samples, i.e. 256/512/1024/2048/4096/8192/16384/32768
- <4> Sample rate:
  -   0000 : get from STREAMINFO metadata block
  -   0001 : 88.2kHz
  -   0010 : 176.4kHz
  -   0011 : 192kHz
  -   0100 : 8kHz
  -   0101 : 16kHz
  -   0110 : 22.05kHz
  -   0111 : 24kHz
  -   1000 : 32kHz
  -   1001 : 44.1kHz
  -   1010 : 48kHz
  -   1011 : 96kHz
  -   1100 : get 8 bit sample rate (in kHz) from end of header
  -   1101 : get 16 bit sample rate (in Hz) from end of header
  -   1110 : get 16 bit sample rate (in tens of Hz) from end of header
  -   1111 : invalid, to prevent sync-fooling string of 1s
- <4> Channel assignment
  -   0000-0111 : (number of independent channels)-1. Where defined, the channel order follows SMPTE/ITU-R recommendations. The assignments are as follows:
      -   1 channel: mono
      -   2 channels: left, right
      -   3 channels: left, right, center
      -   4 channels: front left, front right, back left, back right
      -   5 channels: front left, front right, front center, back/surround left, back/surround right
      -   6 channels: front left, front right, front center, LFE, back/surround left, back/surround right
      -   7 channels: front left, front right, front center, LFE, back center, side left, side right
      -   8 channels: front left, front right, front center, LFE, back left, back right, side left, side right
  - 1000 : left/side stereo: channel 0 is the left channel, channel 1 is the side(difference) channel
  - 1001 : right/side stereo: channel 0 is the side(difference) channel, channel 1 is the right channel
  - 1010 : mid/side stereo: channel 0 is the mid(average) channel, channel 1 is the side(difference) channel
  - 1011-1111 : reserved

- <3> Sample size in bits:
- 000 : get from STREAMINFO metadata block
- 001 : 8 bits per sample
- 010 : 12 bits per sample
- 011 : reserved
- 100 : 16 bits per sample
- 101 : 20 bits per sample
- 110 : 24 bits per sample
- 111 : reserved

- <1> Reserved:
  - 0 : mandatory value
  - 1 : reserved for future use

- <?> if(variable blocksize)
- <8-56>:"UTF-8" coded sample number (decoded number is 36 bits) [\[4\]](#frame_header_notes)

else

- <8-48>:"UTF-8" coded frame number (decoded number is 31 bits) [\[4\]](#frame_header_notes)
- <?> if(blocksize bits == 011x) 8/16 bit (blocksize-1)
- <?> if(sample rate bits == 11xx) 8/16 bit sample rate
- <8> CRC-8 (polynomial = x\^8 + x\^2 + x\^1 + x\^0, initialized with 0) of everything before the crc, including the sync code

- [NOTES](#frame_header_notes)
1.  This bit must remain reserved for `0` in order for a FLAC frame's
    initial 15 bits to be distinguishable from the start of an MPEG
    audio frame ([see
    also](http://lists.xiph.org/pipermail/flac-dev/2008-December/002607.html)).
2.  The "blocking strategy" bit must be the same throughout the entire
    stream.
3.  The "blocking strategy" bit determines how to calculate the sample
    number of the first sample in the frame. If the bit is `0`
    (fixed-blocksize), the frame header encodes the frame number as
    above, and the frame's starting sample number will be the frame
    number times the blocksize. If it is `1` (variable-blocksize), the
    frame header encodes the frame's starting sample number itself. (In
    the case of a fixed-blocksize stream, only the last block may be
    shorter than the stream blocksize; its starting sample number will
    be calculated as the frame number times the previous frame's
    blocksize, or zero if it is the first frame).
4.  The "UTF-8" coding used for the sample/frame number is the same
    variable length code used to store compressed UCS-2, extended to
    handle larger input.

## FRAME_FOOTER
- <16> CRC-16 (polynomial = x\^16 + x\^15 + x\^2 + x\^0, initialized with 0) of everything before the crc, back to and including the frame header sync code

- [*SUBFRAME\_HEADER*](#subframe_header)
- [*SUBFRAME\_CONSTANT*](#subframe_constant) The SUBFRAME\_HEADER specifies which one.
- [*SUBFRAME\_FIXED*](#subframe_fixed)
- [*SUBFRAME\_LPC*](#subframe_lpc)\
- [*SUBFRAME\_VERBATIM*](#subframe_verbatim)
## SUBFRAME

## SUBFRAME_HEADER
- <1> Zero bit padding, to prevent sync-fooling string of 1s
- <6> Subframe type:
  -   000000 : [SUBFRAME\_CONSTANT](#subframe_constant)
  -   000001 : [SUBFRAME\_VERBATIM](#subframe_verbatim)
  -   00001x : reserved
  -   0001xx : reserved
  -   001xxx : if(xxx &lt;= 4) [SUBFRAME\_FIXED](#subframe_fixed), xxx=order ; else reserved
  -   01xxxx : reserved
  -   1xxxxx : [SUBFRAME\_LPC](#subframe_lpc), xxxxx=order-1

- <1+k> 'Wasted bits-per-sample' flag:
  - 0 : no wasted bits-per-sample in source subblock, k=0
  - 1 : k wasted bits-per-sample in source subblock, k-1 follows, unary coded; e.g. k=3 =&gt; 001 follows, k=7 =&gt; 0000001 follows.

## SUBFRAME_CONSTANT
- < n > Unencoded constant value of the subblock, n = frame's bits-per-sample.

## SUBFRAME_FIXED
- < n > Unencoded warm-up samples (n = frame's bits-per-sample \* predictororder).
- [*RESIDUAL*](#residual) Encoded residual

## SUBFRAME_LPC
- < n > Unencoded warm-up samples (n = frame's bits-per-sample \* lpc order).
- <4> (Quantized linear predictor coefficients' precision in bits)-1 (1111 = invalid).
- <5> Quantized linear predictor coefficient shift needed in bits (NOTE: this number is signed two's-complement).
- < n > Unencoded predictor coefficients (n = qlp coeff precision \* lpc order) (NOTE: the coefficients are signed two's-complement).
- [*RESIDUAL*](#residual) Encoded residual

## SUBFRAME_VERBATIM
- <n\*i> Unencoded subblock; n = frame's bits-per-sample, i = frame's blocksize.

## RESIDUAL
- <2> Residual coding method:
  - 00 : partitioned Rice coding with 4-bit Rice parameter; RESIDUAL\_CODING\_METHOD\_PARTITIONED\_RICE follows
  - 01 : partitioned Rice coding with 5-bit Rice parameter; RESIDUAL\_CODING\_METHOD\_PARTITIONED\_RICE2 follows
  - 10-11 : reserved

- [*RESIDUAL\_CODING\_METHOD\_PARTITIONED\_RICE*](#partitioned_rice) ||
- [*RESIDUAL\_CODING\_METHOD\_PARTITIONED\_RICE2*](#partitioned_rice2)
 

## RESIDUAL_CODING_METHOD_PARTITIONED_RICE
- <4> Partition order.
- [*RICE\_PARTITION*](#rice_partition)+ There will be 2\^order partitions.

## RICE_PARTITION
- <4(+5)> Encoding parameter:
  - 0000-1110 : Rice parameter.
  - 1111 : Escape code, meaning the partition is in unencoded binary form using n bits per sample; n follows as a 5-bit number.
- <?> Encoded residual. The number of samples (n) in the partition is determined as follows:
  - if the partition order is zero, n = frame's blocksize - predictor order
  - else if this is not the first partition of the subframe, n = (frame's blocksize / (2\^partition order))
  - else n = (frame's blocksize / (2\^partition order)) - predictor order

## RESIDUAL_CODING_METHOD_PARTITIONED_RICE2
- <4> Partition order.
- [*RICE2\_PARTITION*](#rice2_partition)+ There will be 2\^order partitions.


## RICE2_PARTITION
- <5(+5)> Encoding parameter:
  - 00000-11110 : Rice parameter.
  - 11111 : Escape code, meaning the partition is in unencoded binary form using n bits per sample; n follows as a 5-bit number.

- <?> Encoded residual. The number of samples (n) in the partition is determined as follows:
  - if the partition order is zero, n = frame's blocksize - predictor order
  - else if this is not the first partition of the subframe, n = (frame's blocksize / (2\^partition order))
  - else n = (frame's blocksize / (2\^partition order)) - predictor order
- - -
  Copyright (c) 2000-2009 Josh Coalson, 2011-2014 Xiph.Org Foundation
