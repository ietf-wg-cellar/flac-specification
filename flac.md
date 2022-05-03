# Introduction

This document defines the FLAC format. FLAC files and streams can code for pulse-code modulated (PCM) audio with 1 to 8 channels, sample rates from 1 to 1048576 Hertz and bit depths between 4 and 32 bits. Most tools for coding to and decoding from the FLAC format have been optimized for CD-audio, which is PCM audio with 2 channels, a sample rate of 44.1 kHz and a bit depth of 16 bits.

FLAC is able to achieve lossless compression because samples in audio signals tend to be highly correlated with their close neighbors. In contrast with general purpose compressors, which often use dictionaries, do run-length coding or exploit long-term repetition, FLAC removes redundancy solely in the very short term, looking back at most 32 samples.

The coding methods provided by the FLAC format work best on PCM audio signals of which the samples have a signed representation and are centered around zero. Audio signals in which samples have an unsigned representation must be transformed to a signed representation as described in this document in order to achieve reasonable compression. The FLAC format is not suited to compress audio that is not PCM. Pulse-density modulated audio, e.g. DSD, cannot be compressed by FLAC.

# Notation and Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they appear in all capitals, as shown here.

Values expressed as `u(n)` represent unsigned big-endian integer using `n` bits. Values expressed as `s(n)` represent signed big-endian integer using `n` bits, signed two's complement. `n` may be expressed as an equation using `*` (multiplication), `/` (division), `+` (addition), or `-` (subtraction). An inclusive range of the number of bits expressed may be represented with an ellipsis, such as `u(m...n)`. The name of a value followed by an asterisk `*` indicates zero or more occurrences of the value. The name of a value followed by a plus sign `+` indicates one or more occurrences of the value.

# Acknowledgments

FLAC owes much to the many people who have advanced the audio compression field so freely. For instance:

- [A. J. Robinson](https://web.archive.org/web/20160315141134/http://mi.eng.cam.ac.uk/~ajr/) for his work on Shorten; his paper ([@robinson-tr156]) is a good starting point on some of the basic methods used by FLAC. FLAC trivially extends and improves the fixed predictors, LPC coefficient quantization, and Rice coding used in Shorten.
- [S. W. Golomb](https://web.archive.org/web/20040215005354/http://csi.usc.edu/faculty/golomb.html) and Robert F. Rice; their universal codes are used by FLAC's entropy coder.
- N. Levinson and J. Durbin; the reference encoder uses an algorithm developed and refined by them for determining the LPC coefficients from the autocorrelation coefficients.
- And of course, [Claude Shannon](https://en.wikipedia.org/wiki/Claude_Shannon)

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

# Conceptual overview

Similar to many audio coders, a FLAC file is encoded following the steps below. On decoding a FLAC file, these steps are undone in reverse order, i.e. from bottom to top.

- `Blocking` (see [section on Blocking](#blocking)). The input is split up into many contiguous blocks. With FLAC, the blocks MAY vary in size. The optimal size of the block is usually affected by many factors, including the sample rate, spectral characteristics over time, etc. However, as finding the optimal block size arrangement is a rather complex problem, the FLAC format allows for a constant block size throughout a stream as well.

- `Interchannel Decorrelation` (see [section on Interchannel Decorrelation](#interchannel-decorrelation)). In the case of stereo streams, the FLAC format allows for transforming the left-right signal into a mid-side signal to remove redundancy, if there is any. Besides coding as left-right and mid-side, it is also possible to code left-side and side-right, whichever ordering results in the highest compression. Choosing between any of these transformation is done independently for each block.

- `Prediction` (see [section on Prediction](#prediction)). To remove redundancy in a signal, a predictor is stored for each subblock or its transformation as formed in the previous step. A predictor consists of a simple mathematical description that can be used, as the name implies, to predict a certain sample from the samples that preceded it. As this prediction is rarely exact, the error of this prediction is passed to the next stage. The predictor of each subblock is completely independent from other subblocks. Since the methods of prediction are known to both the encoder and decoder, only the parameters of the predictor need be included in the compressed stream. In case no usable predictor can be found for a certain subblock, the signal is stored instead of compressed and the next stage is skipped.

- `Residual Coding` (See [section on Residual Coding](#residual-coding)). As the predictor does not describe the signal exactly, the difference between the original signal and the predicted signal (called the error or residual signal) MUST be coded losslessly. If the predictor is effective, the residual signal will require fewer bits per sample than the original signal. FLAC uses Rice coding, a subset of Golomb coding, with either 4-bit or 5-bit parameters to code the residual signal.

In addition, FLAC specifies a metadata system (see [section on File-level metadata](#file-level-metadata)), which allows arbitrary information about the stream to be included at the beginning of the stream.

## Blocking

The size used for blocking the audio data has a direct effect on the compression ratio. If the block size is too small, the resulting large number of frames mean that excess bits will be wasted on frame headers. If the block size is too large, the characteristics of the signal may vary so much that the encoder will be unable to find a good predictor. In order to simplify encoder/decoder design, FLAC imposes a minimum block size of 16 samples, and a maximum block size of 65535 samples. This range covers the optimal size for all of the audio data FLAC supports.

While the block size MAY vary in a FLAC file, it is often difficult to find the optimal arrangement of block sizes for maximum compression. Because of this the FLAC format explicitly stores whether a file has a constant or a variable blocksize throughout the stream, and stores a block number instead of a sample number to slighly improve compression in case a stream has a constant block size.

Blocked data is passed to the predictor stage one subblock at a time. Each subblock is independently coded into a subframe, and the subframes are concatenated into a frame. Because each channel is coded separately, subframes MAY use different predictors, even within a frame.

## Interchannel Decorrelation

In many audio files, channels are correlated. The FLAC format can exploit this correlation in stereo files by not directly coding subblocks into subframes, but instead coding an average of all samples in both subblocks (a mid channel) or the difference between all samples in both subblocks (a side channel). The following combinations are possible:

- **Independent**. All channels are coded independently. All non-stereo files MUST be encoded this way.

- **Mid-side**. A left and right subblock are converted to mid and side subframes. To calculate a sample for a mid subframe, the corresponding left and right samples are summed and the result is shifted right by 1 bit. To calculate a sample for a side subframe, the corresponding right sample is subtracted from the corresponding left sample. On decoding, the mid channel has to be shifted left by 1 bit. Also, if the side channel is uneven, 1 has to be added to the mid channel after the left shift. To reconstruct the left channel, the corresponding samples in the mid and side subframes are added and the result shifted right by 1 bit, while for the right channel the side channel has to be subtracted from the mid channel and the result shifted right by 1 bit.

- **Left-side**. The left subblock is coded and the left and right subblock are used to code a side subframe. The side subframe is constructed in the same way as for mid-side. To decode, the right subblock is restored by subtracting the samples in the side subframe from the corresponding samples the left subframe.

- **Right-side**. The right subblock is coded and the left and right subblock are used to code a side subframe. Note that the actual coded subframe order is side-right. The side subframe is constructed in the same way as for mid-side. To decode, the left subblock is restored by adding the samples in the side subframe to the corresponding samples in the right subframe.

The side channel needs one extra bit of bit depth as the subtraction can produce sample values twice as large as the maximum possible in any given bit depth. The mid channel in mid-side stereo does not need one extra bit, as it is shifted right one bit. The right shift of the mid channel does not lead to non-lossless behavior, because an uneven sample in the mid subframe must always be accompanied by a corresponding uneven sample in the side subframe, which means the lost least significant bit can be restored by taking it from the sample in the side subframe.

## Prediction

The FLAC format has four methods for modeling the input signal:

1. **Verbatim**. Samples are stored directly, without any modelling. This method is used for inputs with little correlation like white noise. Since the raw signal is not actually passed through the residual coding stage (it is added to the stream 'verbatim'), the method is different from using a zero-order fixed predictor.

1. **Constant**. A single sample value is stored. This method is used whenever a signal is pure DC ("digital silence"), i.e. a constant value throughout.

1. **Fixed predictor**. Samples are predicted with one of five fixed (i.e. predefined) predictors, the error of this prediction is processed by the residual coder. These fixed predictors are well suited for predicting simple waveforms. Since the predictors are fixed, no predictor coefficients are stored. From a mathematical point of view, the predictors work by extrapolating the signal from the previous samples. The number of previous samples used is equal to the predictor order. For more information see the [section on the fixed predictor subframe](#fixed-predictor-subframe)

1. **Linear predictor**. Samples are predicted using past samples and a set of predictor coefficients, the error of this prediction is processed by the residual coder. Compared to a fixed predictor, using a generic linear predictor adds overhead as predictor coefficients need to be stored. Therefore, this method of prediction is best suited for predicting more complex waveforms, where the added overhead is offset by space savings in the residual coding stage resulting from more accurate prediction. A linear predictor in FLAC has two parameters besides the predictor coefficients and the predictor order: the number of bits with which each coefficient is stored (the coefficient precision) and a prediction right shift. A prediction is formed by taking the sum of multiplying each predictor coefficient with the corresponding past sample, and dividing that sum by applying the specified right shift. For more information see the [section on the linear predictor subframe](#linear-predictor-subframe)

For more information on fixed and linear predictors, see [@HPL-1999-144] and [@robinson-tr156].

<reference anchor="HPL-1999-144" target="https://www.hpl.hp.com/techreports/1999/HPL-1999-144.pdf">
    <front>
        <title>Lossless Compression of Digital Audio</title>
        <author initials="M" surname="Hans" fullname="Mat Hans">
            <organisation>Client and Media Systems Laboratory, HP Laboratories Palo Alto</organisation>
        </author>
        <author initials="RW" surname="Schafer" fullname="Ronald W. Schafer">
            <organisation>Center for Signal &amp; Image Processing at the School of Electrical and Computer Engineering, Georgia Institute of the Technology, Atlanta, Georgia</organisation>
        </author>
        <date month="11" year="1999"/>
    </front>
    <seriesInfo name="DOI" value="10.1109/79.939834"/>
</reference>

<reference anchor="robinson-tr156" target="https://mi.eng.cam.ac.uk/reports/abstracts/robinson_tr156.html">
    <front>
        <title>SHORTEN: Simple lossless and near-lossless waveform compression</title>
        <author initials="T" surname="Robinson" fullname="Tony Robinson">
            <organisation>Cambridge University Engineering Department</organisation>
        </author>
        <date month="12" year="1994"/>
    </front>
</reference>

## Residual Coding

In case a subframe uses a predictor to approximate the audio signal, a residual needs to be stored to 'correct' the approximation to the exact value. When an effective predictor is used, the average numerical value of the residual samples is smaller than that of the samples before prediction. While having smaller values on average, it is possible a few 'outlier' residual samples are much larger than any of the original samples. Sometimes these outliers even exceed the range the bit depth of the original audio offers.

To be able to efficiently code such a stream of relatively small numbers with an occasional outlier, Rice coding (a subset of Golomb coding) is used. Depending on how small the numbers are that have to be coded, a Rice parameter is chosen. The numerical value of each residual sample is split in two parts by dividing it with `2^(Rice parameter)`, creating a quotient and a remainder. The quotient is stored in unary form, the remainder in binary form. If indeed most residual samples are close to zero and the Rice parameter is chosen right, this form of coding, a so-called variable-length code, needs less bits to store than storing the residual in unencoded form.

As Rice codes can only handle unsigned numbers, signed numbers are zigzag encoded to a so-called folded residual. For more information see section [coded residual](#coded-residual) for a more thorough explanation.

Quite often the optimal Rice parameter varies over the course of a subframe. To accommodate this, the residual can be split up into partitions, where each partition has its own Rice parameter. To keep overhead and complexity low, the number of partitions used in a subframe is limited to powers of two.

The FLAC format uses two forms of Rice coding, which only differ in the number of bits used for encoding the Rice parameter, either 4 or 5 bits.

# Format principles

FLAC has no format version information, but it does contain reserved space in several places. Future versions of the format MAY use this reserved space safely without breaking the format of older streams. Older decoders MAY choose to abort decoding or skip data encoded with newer methods. Apart from reserved patterns, in places the format specifies invalid patterns, meaning that the patterns MAY never appear in any valid bitstream, in any prior, present, or future versions of the format. These invalid patterns are usually used to make the synchronization mechanism more robust.

All numbers used in a FLAC bitstream MUST be integers, there are no floating-point representations. All numbers MUST be big-endian coded, except the field length used in Vorbis comments, which MUST be little-endian coded. All numbers MUST be unsigned except linear predictor coefficients, the linear prediction shift and numbers which directly represent samples, which MUST be signed. None of these restrictions apply to application metadata blocks or to Vorbis comment field contents.

All samples encoded to and decoded from the FLAC format MUST be in a signed representation.

There are several ways to convert unsigned sample representations to signed sample representations, but the coding methods provided by the FLAC format work best on audio signals of which the numerical values of the samples are centered around zero, i.e. have no DC offset. In most unsigned audio formats, signals are centered around halfway the range of the unsigned integer type used. If that is the case, all sample representations SHOULD be converted by first copying the number to a signed integer with sufficient range and then subtracting half of the range of the unsigned integer type, which should result in a signal with samples centered around 0.

# Format lay-out

Before the formal description of the stream, an overview of the lay-out of FLAC file might be helpful.

- A FLAC bitstream consists of the "fLaC" (i.e. 0x664C6143) marker at the beginning of the stream, followed by a mandatory metadata block (called the STREAMINFO block), any number of other metadata blocks, then the audio frames.
- FLAC supports up to 128 kinds of metadata blocks; currently 7 kinds are defined in the section [file-level metadata](#file-level-metadata).
- The audio data is composed of one or more audio frames. Each frame consists of a frame header, which contains a sync code, information about the frame like the block size, sample rate, number of channels, et cetera, and an 8-bit CRC. The frame header also contains either the sample number of the first sample in the frame (for variable-blocksize streams), or the frame number (for fixed-blocksize streams). This allows for fast, sample-accurate seeking to be performed. Following the frame header are encoded subframes, one for each channel, and finally, the frame is zero-padded to a byte boundary. Each subframe has its own header that specifies how the subframe is encoded.
- Since a decoder MAY start decoding in the middle of a stream, there MUST be a method to determine the start of a frame. A 14-bit sync code begins each frame. The sync code will not appear anywhere else in the frame header. However, since it MAY appear in the subframes, the decoder has two other ways of ensuring a correct sync. The first is to check that the rest of the frame header contains no invalid data. Even this is not foolproof since valid header patterns can still occur within the subframes. The decoder's final check is to generate an 8-bit CRC of the frame header and compare this to the CRC stored at the end of the frame header.
- Again, since a decoder MAY start decoding at an arbitrary frame in the stream, each frame header MUST contain some basic information about the stream because the decoder MAY not have access to the STREAMINFO metadata block at the start of the stream. This information includes sample rate, bits per sample, number of channels, etc. Since the frame header is pure overhead, it has a direct effect on the compression ratio. To keep the frame header as small as possible, FLAC uses lookup tables for the most commonly used values for frame parameters. When a certain parameter has a value that is covered by the lookup table, the deocder is directed find the exact sample rate at the end of the frame header or in the streaminfo metadata block. In case a frame header refers to the streaminfo metadata block, the file is not 'streamable', see [section format subset](#format-subset) for details. In this way, the file is streamable and the frame header size small for all of the most common forms of audio data.
- Individual subframes (one for each channel) are coded separately within a frame, and appear serially in the stream. In other words, the encoded audio data is NOT channel-interleaved. This reduces decoder complexity at the cost of requiring larger decode buffers. Each subframe has its own header specifying the attributes of the subframe, like prediction method and order, residual coding parameters, etc. The header is followed by the encoded audio data for that channel

# Format subset
`FLAC` specifies a subset of itself as the Subset format. The purpose of this is to ensure that any streams encoded according to the Subset are truly "streamable", meaning that a decoder that cannot seek within the stream can still pick up in the middle of the stream and start decoding. It also makes hardware decoder implementations more practical by limiting the encoding parameters such that decoder buffer sizes and other resource requirements can be easily determined. __flac__ generates Subset streams by default unless the "--lax" command-line option is used. The Subset makes the following limitations on what MAY be used in the stream:

- The [blocksize bits](#blocksize-bits) in the frame header MUST be 0b0001-0b1110. The blocksize MUST be <= 16384; if the sample rate is <= 48000 Hz, the blocksize MUST be <= 4608 = 2\^9 \* 3\^2.
- The [sample rate bits](#sample-rate-bits) in the frame header MUST be 0b0001-0b1110.
- The [bits depth bits](#bit-depth-bits) in the frame header MUST be 0b001-0b111.
- If the sample rate is <= 48000 Hz, the filter order in linear subframes (see section [linear predictor subframe](#linear-predictor-subframe)) MUST be less than or equal to 12, i.e. the subframe type bits in the subframe header (see [subframe header section](#subframe-header)) SHOULD NOT be 0b101100-0b111111.
- The Rice partition order (see [coded residual section](#coded-residual)) MUST be less than or equal to 8.

# File-level metadata

At the start of a FLAC file or stream, following the fLaC ASCII file signature, one or more metadata blocks MUST be present before any audio frames appear. The first metadata block MUST be a streaminfo block.

## Metadata block header

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
7 - 126 | reserved
127     | invalid, to avoid confusion with a frame sync code


## Streaminfo

The streaminfo metadata block has information about the whole stream, like sample rate, number of channels, total number of samples, etc. It MUST be present as the first metadata block in the stream. Other metadata blocks MAY follow, and ones that the decoder doesn't understand, it will skip. There MUST be no more than one streaminfo metadata block per FLAC stream.

In case the streaminfo metadata block contains incorrect or incomplete information, decoder behaviour is left unspecified (i.e. up to the decoder implementation). A decoder MAY choose to stop further decoding in case the information supplied by the streaminfo metadata block turns out to be incorrect or invalid. A decoder accepting information from the streaminfo block (most significantly the maximum frame size, maximum block size, number of audio channels, number of bits per sample and total number of samples) without doing further checks during decoding of audio frames could be vulnerable to buffer overflows. See also [the section on security considerations](#security-considerations).

Data     | Description
:--------|:-----------
`u(16)`  | The minimum block size (in samples) used in the stream, excluding the last block.
`u(16)`  | The maximum block size (in samples) used in the stream.
`u(24)`  | The minimum frame size (in bytes) used in the stream. A value of `0` signifies that the value is not known.
`u(24)`  | The maximum frame size (in bytes) used in the stream. A value of `0` signifies that the value is not known.
`u(20)`  | Sample rate in Hz. Though 20 bits are available, the maximum sample rate is limited by the structure of frame headers to 655350 Hz. Also, a value of 0 is invalid.
`u(3)`   | (number of channels)-1. FLAC supports from 1 to 8 channels
`u(5)`   | (bits per sample)-1. FLAC supports from 4 to 32 bits per sample. Currently the reference encoder and decoders only support up to 24 bits per sample.
`u(36)`  | Total samples in stream. 'Samples' means inter-channel sample, i.e. one second of 44.1 kHz audio will have 44100 samples regardless of the number of channels. A value of zero here means the number of total samples is unknown.
`u(128)` | MD5 signature of the unencoded audio data. This allows the decoder to determine if an error exists in the audio data even when the error does not result in an invalid bitstream. A value of `0` signifies that the value is not known.

The minimum block size is excluding the last block of a FLAC file, which may be smaller. If the minimum block size is equal to the maximum block size, the file contains a fixed block size stream. Note that the actual maximum block size might be smaller than the maximum block size listed in the streaminfo block, and the actual smallest block size excluding the last block might be larger than the minimum block size listed in the streaminfo block. This is because the encoder has to write these fields before receiving any input audio data, and cannot know beforehand what block sizes it will use, only between what bounds these will be chosen.

FLAC specifies a minimum block size of 16 and a maximum block size of 65535, meaning the bit patterns corresponding to the numbers 0-15 in the minimum block size and maximum block size fields are invalid.

The MD5 signature is made by performing an MD5 transformation on the samples of all channels interleaved, represented in signed, little-endian form. This interleaving is on a per-sample basis, so for a stereo file this means first the first sample of the first channel, then the first sample of the second channel, then the second sample of the first channel etc. Before performing the MD5 transformation, all samples must be byte-aligned. So, in case the bit depth is not a whole number of bytes, additional zero bits are inserted at the most-significant position until each sample representation is a whole number of bytes.

## Padding

The padding metadata block allows for an arbitrary amount of padding. The contents of a padding block have no meaning. This block is useful when it is known that metadata will be edited after encoding; the user can instruct the encoder to reserve a padding block of sufficient size so that when metadata is added, it will simply overwrite the padding (which is relatively quick) instead of having to insert it into the right place in the existing file (which would normally require rewriting the entire file).

Data     | Description
:--------|:-----------
`u(n)`   | n '0' bits (n MUST be a multiple of 8)

## Application

The application metadata block is for use by third-party applications. The only mandatory field is a 32-bit identifier, much like a FourCC but not restricted to ASCII characters. This ID is granted upon request to an application by the FLAC maintainers. The remainder is of the block is defined by the registered application. Visit the [registration page](https://xiph.org/flac/id.html) if you would like to register an ID for your application with FLAC.

Data     | Description
:--------|:-----------
`u(32)`  | Registered application ID. (Visit the [registration page](https://xiph.org/flac/id.html) to register an ID with FLAC.)
`u(n)`   | Application data (n MUST be a multiple of 8)

## Seektable

The seektable metadata block can be used to store seek points. It is possible to seek to any given sample in a FLAC stream without a seek table, but the delay can be unpredictable since the bitrate MAY vary widely within a stream. By adding seek points to a stream, this delay can be significantly reduced. Each seek point takes 18 bytes, so a seek table with 1% resolution within a stream adds less than 2KB of data. There can be only one seektable metadata block in a stream, but the table can have any number of seek points. There is also a special 'placeholder' seekpoint which will be ignored by decoders but which can be used to reserve space for future seek point insertion.

Data         | Description
:------------|:-----------
`SEEKPOINT`+ | One or more seek points.

NOTE
- The number of seek points is implied by the metadata header 'length' field, i.e. equal to length / 18.

### Seekpoint
Data     | Description
:--------|:-----------
`u(64)`  | Sample number of first sample in the target frame, or `0xFFFFFFFFFFFFFFFF` for a placeholder point.
`u(64)`  | Offset (in bytes) from the first byte of the first frame header to the first byte of the target frame's header.
`u(16)`  | Number of samples in the target frame.

NOTES

- For placeholder points, the second and third field values are undefined.
- Seek points within a table MUST be sorted in ascending order by sample number.
- Seek points within a table MUST be unique by sample number, with the exception of placeholder points.
- The previous two notes imply that there MAY be any number of placeholder points, but they MUST all occur at the end of the table.

## Vorbis comment

A Vorbis comment metadata block contains human-readable information coded in UTF-8. The name Vorbis comment points to the fact that the Vorbis codec stores such metadata in almost the same way. A Vorbis comment metadata block consists of a vendor string optionally followed by a number of fields, which are pairs of field names and field contents. Many users refer to these fields as FLAC tags or simply as tags. A FLAC file MUST NOT contain more than one Vorbis comment metadata block.

In a Vorbis comment metadata block, the metadata block header is directly followed by 4 bytes containing the length in bytes of the vendor string as an unsigned number coded little-endian. The vendor string follows UTF-8 coded, and is not terminated in any way.

Following the vendor string are 4 bytes containing the number of fields that are in the Vorbis comment block, stored as an unsigned number, coded little-endian. If this number is non-zero, it is followed by the fields themselves, each field stored with a 4 byte length. First, the 4 byte field length in bytes is stored as an unsigned number, coded little-endian. The field itself is, like the vendor string, UTF-8 coded, not terminated in any way.

Each field consists of a field name and a field content, separated by an = character. The field name MUST only consist of UTF-8 code points U+0020 through U+0074, excluding U+003D, which is the = character. In other words, the field name can contain all printable ASCII characters except the equals sign. The evaluation of the field names MUST be case insensitive, so U+0041 through 0+005A (A-Z) MUST be considered equivalent to U+0061 through U+007A (a-z) respectively. The field contents can contain any UTF-8 character.

Note that the Vorbis comment as used in Vorbis allows for on the order of 2\^64 bytes of data whereas the FLAC metadata block is limited to 2\^24 bytes. Given the stated purpose of Vorbis comments, i.e. human-readable textual information, this limit is unlikely to be restrictive. Also note that the 32-bit field lengths are coded little-endian, as opposed to the usual big-endian coding of fixed-length integers in the rest of the FLAC format.

### Standard field names

Except the one defined in the [section channel mask](#channel-mask), no standard field names are defined. In general, most software recognizes the following field names

- Title: name of the current work
- Artist: name of the artist generally responsible for the current work. For orchestral works this is usually the composer, otherwise is it often the performer
- Album: name of the collection the current work belongs to

For a more comprehensive list of possible field names, [the list of tags used in the MusicBrainz project](http://picard-docs.musicbrainz.org/en/variables/variables.html) is recommended.

### Channel mask

Besides fields containing information about the work itself, one field is defined for technical reasons, of which the field name is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK. This field contains information on which channels the file contains. Use of this field is RECOMMENDED in case these differ from the channels defined in [the section channels bits](#channels-bits).

The channel mask consists of flag bits indicating which channels are present, stored in a hexadecimal representation preceded by 0x. The flags only signal which channels are present, not in which order, so in case a file has to be encoded in which channels are ordered differently, they have to be reordered. Please note that a file in which the channel order is defined through the WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK is not streamable, i.e. non-subset, as the field is not found in each frame header. The mask bits can be found in the following table

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

- if a file has a single channel, being a LFE channel, the Vorbis comment field is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x8
- if a file has 4 channels, being front left, front right, top front left and top front right, the Vorbis comment field is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x5003
- if an input has 4 channels, being back center, top front center, front center and top rear center in that order, they have to be reordered to front center, back center, top front center and top rear center. The Vorbis comment field added is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x12004.

WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK fields MAY be padded with zeros, for example, 0x0008 for a single LFE channel. Parsing of WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK fields MUST be case-insensitive for both the field name and the field contents.

## Cuesheet

To either store the track and index point structure of a CD-DA along with its audio or to provide a mechanism to store locations of interest within a FLAC file, a cuesheet metadata block can be used. Certain aspects of this metadata block follow directly from the CD-DA specification, called Red Book, which is standardized as [@IEC.60908.1999]. For more information on the function and history of these aspects, please refer to [@IEC.60908.1999].

<reference anchor="IEC.60908.1999">
    <front>
        <title>Audio recording - Compact disc digital audio system</title>
        <author>
            <organization>International Electrotechnical Commission</organization>
        </author>
        <date year="1999"/>
    </front>
    <seriesInfo name="IEC" value="International standard 60908 second edition"/>
</reference>

The structure of a cuesheet metadata block is enumerated in the following table.

Data              | Description
:-----------------|:-----------
`u(128*8)`        | Media catalog number, in ASCII printable characters 0x20-0x7E.
`u(64)`           | Number of lead-in samples.
`u(1)`            | `1` if the cuesheet corresponds to a Compact Disc, else `0`.
`u(7+258*8)`      | Reserved. All bits MUST be set to zero.
`u(8)`            | Number of tracks in this cuesheet.
Cuesheet tracks   | A number of structures as specified in the [section cuesheet track](#cuesheet-track) equal to the number of tracks specified previously.

If the media catalog number is less than 128 bytes long, it SHOULD be right-padded with NUL characters. For CD-DA, this is a thirteen digit number, followed by 115 NUL bytes.

The number of lead-in samples has meaning only for CD-DA cuesheets; for other uses it SHOULD be 0. For CD-DA, the lead-in is the TRACK 00 area where the table of contents is stored; more precisely, it is the number of samples from the first sample of the media to the first sample of the first index point of the first track. According to [@IEC.60908.1999], the lead-in MUST be silence and CD grabbing software does not usually store it; additionally, the lead-in MUST be at least two seconds but MAY be longer. For these reasons the lead-in length is stored here so that the absolute position of the first track can be computed. Note that the lead-in stored here is the number of samples up to the first index point of the first track, not necessarily to INDEX 01 of the first track; even the first track MAY have INDEX 00 data.

The number of tracks MUST be at least 1, as a cuesheet block MUST have a lead-out track. For CD-DA, this number MUST be no more than 100 (99 regular tracks and one lead-out track). The lead-out track is always the last track in the cuesheet. For CD-DA, the lead-out track number MUST be 170 as specified by [@IEC.60908.1999], otherwise it MUST be 255.

### Cuesheet track
Data                          | Description
:-----------------------------|:-----------
`u(64)`                       | Track offset of first index point in samples, relative to the beginning of the FLAC audio stream.
`u(8)`                        | Track number.
`u(12*8)`                     | Track ISRC.
`u(1)`                        | The track type: 0 for audio, 1 for non-audio. This corresponds to the CD-DA Q-channel control bit 3.
`u(1)`                        | The pre-emphasis flag: 0 for no pre-emphasis, 1 for pre-emphasis. This corresponds to the CD-DA Q-channel control bit 5.
`u(6+13*8)`                   | Reserved. All bits MUST be set to zero.
`u(8)`                        | The number of track index points.
Cuesheet track index points   | For all tracks except the lead-out track, a number of structures as specified in the [section cuesheet track index point](#cuesheet-track-index-point) equal to the number of index points specified previously.

Note that the track offset differs from the one in CD-DA, where the track's offset in the TOC is that of the track's INDEX 01 even if there is an INDEX 00. For CD-DA, the track offset MUST be evenly divisible by 588 samples (588 samples = 44100 samples/s \* 1/75 s).

A track number of 0 is not allowed to avoid conflicting with the CD-DA spec, which reserves this for the lead-in. For CD-DA the number MUST be 1-99, or 170 for the lead-out; for non-CD-DA, the track number MUST for 255 for the lead-out. It is RECOMMENDED to start with track 1 and increase sequentially. Track numbers MUST be unique within a cuesheet.

The track ISRC (International Standard Recording Code) is a 12-digit alphanumeric code; see [@ISRC-handbook]. A value of 12 ASCII NUL characters MAY be used to denote absence of an ISRC.

<reference anchor="ISRC-handbook" target="https://www.ifpi.org/isrc_handbook/">
    <front>
        <title>International Standard Recording Code (ISRC) Handbook, 4th edition</title>
        <author>
            <organisation>International ISRC Registration Authority</organisation>
        </author>
        <date year="2021"/>
    </front>
</reference>

There MUST be at least one index point in every track in a cuesheet except for the lead-out track, which MUST have zero. For CD-DA, the number of index points SHOULD NOT be more than 100.


#### Cuesheet track index point
Data      | Description
:---------|:-----------
`u(64)`   | Offset in samples, relative to the track offset, of the index point.
`u(8)`    | The track index point number.
`u(3*8)`  | Reserved. All bits MUST be set to zero.

For CD-DA, the track index point offset MUST be evenly divisible by 588 samples (588 samples = 44100 samples/s \* 1/75 s). Note that the offset is from the beginning of the track, not the beginning of the audio data.

For CD-DA, an track index point number of 0 corresponds to the track pre-gap. The first index point in a track MUST have a number of 0 or 1, and subsequently, index point numbers MUST increase by 1. Index point numbers MUST be unique within a track.

## Picture

The picture metadata block contains image data of a picture in some way belonging to the audio contained in the FLAC file. Its format is derived from the APIC frame in the ID3v2 specification. However, contrary to the APIC frame in ID3v2, the MIME type and description are prepended with a 4-byte length field instead of being null delimited strings. A FLAC file MAY contain one or more picture metadata blocks.

Note that while the length fields for MIME type, description and picture data are 4 bytes in length and could in theory code for a size up to 4 GiB, the total metadata block size cannot exceed what can be described by the metadata block header, i.e. 16 MiB.

Data      | Description
:---------|:-----------
`u(32)`   | The picture type according to next table
`u(32)`   | The length of the MIME type string in bytes.
`u(n*8)`  | The MIME type string, in printable ASCII characters 0x20-0x7E. The MIME type MAY also be `-->` to signify that the data part is a URL of the picture instead of the picture data itself.
`u(32)`   | The length of the description string in bytes.
`u(n*8)`  | The description of the picture, in UTF-8.
`u(32)`   | The width of the picture in pixels.
`u(32)`   | The height of the picture in pixels.
`u(32)`   | The color depth of the picture in bits-per-pixel.
`u(32)`   | For indexed-color pictures (e.g. GIF), the number of colors used, or `0` for non-indexed pictures.
`u(32)`   | The length of the picture data in bytes.
`u(n*8)`  | The binary picture data.

The following table contains all defined picture types. Values other than those listed in the table are reserved and SHOULD NOT be used. There MAY only be one each of picture type 1 and 2 in a file. In general practice, many decoders display the contents of a picture metadata block with picture type 3 (front cover) during playback, if present.

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

# Frame structure

Directly after the last metadata block, one or more frames follow. Each frame consists of a frame header, one or more subframes, padding zero bits to achieve byte-alignment and a frame footer. The number of subframes in each frame is equal to the number of audio channels.

## Frame header
Each frame starts with the 15-bit frame sync code 0b111111111111100. Following the sync code is the blocking strategy bit, which MUST NOT change during the audio stream. The blocking strategy bit is 0 for a fixed blocksize stream or 1 for variable blocksize stream. If the blocking strategy is known, a decoder can search for a 16-bit sync code, either 0xF8 for a fixed blocksize stream or 0xF9 for a variable blocksize stream. To ease the search for the sync code and further reduction of false positives, all frames MUST start on a byte boundary.

### Blocksize bits

Following the frame sync code and blocksize strategy bit are 4 bits referred to as the blocksize bits. Their value relates to the blocksize according to the following table, where v is the value of the 4 bits as an unsigned number. Uncommon blocksizes are stored after the coded number.

Value           | Blocksize
:---------------|:-----------
0b0000          | reserved
0b0001          | 192
0b0010 - 0b0101 | 144 \* (2\^v), i.e. 576, 1152, 2304 or 4608
0b0110          | uncommon blocksize minus 1 stored as an 8-bit number
0b0111          | uncommon blocksize minus 1 stored as a 16-bit number
0b1000 - 0b1111 | 2\^v, i.e. 256, 512, 1024, 2048, 4096, 8192, 16384 or 32768

### Sample rate bits

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
0b1100  | uncommon sample rate in kHz stored as an 8-bit number
0b1101  | uncommon sample rate in Hz stored as a 16-bit number
0b1110  | uncommon sample rate in Hz divided by 10, stored as a 16-bit number
0b1111  | invalid

### Channels bits

The next 4 bits (the first 4 bits of the fourth byte of each frame), referred to as the channel bits, code for both the number of channels as well as any stereo decorrelation used according to the following table, where v is the value of the 4 bits as an unsigned number. See also [the section on interchannel decorrelation](#interchannel-decorrelation).

Value           | Channels
:---------------|:-----------
0b0000          | 1 channel: mono
0b0001          | 2 channels: left, right
0b0010          | 3 channels: left, right, center
0b0011          | 4 channels: front left, front right, back left, back right
0b0100          | 5 channels: front left, front right, front center, back/surround left, back/surround right
0b0101          | 6 channels: front left, front right, front center, LFE, back/surround left, back/surround right
0b0110          | 7 channels: front left, front right, front center, LFE, back center, side left, side right
0b0111          | 8 channels: front left, front right, front center, LFE, back left, back right, side left, side right
0b1000          | 2 channels, stored as left/side stereo
0b1001          | 2 channels, stored as right/side stereo
0b1010          | 2 channels, stored as mid/side stereo
0b1011 - 0b1111 | reserved

### Bit depth bits

The next 3 bits code for the bit depth of the samples in the subframe according to the following table.

Value   | Bit depth
:-------|:-----------
0b000   | bit depth only stored in streaminfo metadata block
0b001   | 8 bits per sample
0b010   | 12 bits per sample
0b011   | reserved
0b100   | 16 bits per sample
0b101   | 20 bits per sample
0b110   | 24 bits per sample
0b111   | reserved

The next bit is reserved and MUST be zero.

### Coded number

Following the reserved bit (starting at the fifth byte of the frame) is either a sample or a frame number, which will be referred to as the coded number. When dealing with variable blocksize streams, the sample number of the first sample in the frame is encoded. When the file contains a fixed blocksize stream, the frame number is encoded. The coded number is stored in a variable length code like UTF-8, but extended to a maximum of 36 bits unencoded, 7 byte encoded. When a frame number is encoded, the value MUST NOT be larger than what fits a value 31 bits unencoded or 6 byte encoded. Please note that most general purpose UTF-8 encoders and decoders will not be able to handle these extended codes.

### Uncommon blocksize

If the blocksize bits defined earlier in this section were 0b0110 or 0b0111 (uncommon blocksize minus 1 stored), this follows the coded number as either an 8-bit or a 16-bit unsigned number coded big-endian.

### Uncommon sample rate

Following either the coded number or an uncommon blocksize is the sample rate, if the sample rate bits were 0b1100, 0b1101 or 0b1110 (uncommon sample rate stored), as either an 8-bit or a 16-bit unsigned number coded big-endian.

### Frame header CRC

Finally, after either the frame/sample number, the blocksize or the sample rate, is a 8-bit CRC. This CRC is initialized with 0 and has the polynomial x^8 + x^2 + x^1 + x^0. This CRC covers the whole frame header before the CRC, including the sync code.

## Subframes

Following the frame header are a number subframes equal to the number of audio channels.

### Subframe header
Each subframe starts with a header. The first bit of the header is always 0, followed by 6 bits describing which subframe type is used according to the following table, where v is the value of the 6 bits as an unsigned number.

Value               | Subframe type
:-------------------|:-----------
0b000000            | Constant subframe
0b000001            | Verbatim subframe
0b000010 - 0b000111 | reserved
0b001000 - 0b001100 | Subframe with a fixed predictor v-8, i.e. 0, 1, 2, 3 or 4
0b001101 - 0b011111 | reserved
0b100000 - 0b111111 | Subframe with a linear predictor v-31, i.e. 1 through 32 (inclusive)

Following the subframe type bits is a bit that flags whether the subframe has any wasted bits. If it is 0, the subframe doesn't have any wasted bits and the subframe header is complete. If it is 1, the subframe does have wasted bits and the number of wasted bits follows unary coded.

### Wasted bits per sample

Certain file formats, like AIFF, can store audio samples with a bit depth that is not an integer number of bytes by padding them with least significant zero bits to a bit depth that is an integer number of bytes. For example, shifting a 14-bit sample right by 2 pads it to a 16-bit sample, which then has two zero least-significant bits. In this specification, these least-significant zero bits are referred to as wasted bits-per-sample or simply wasted bits. They are wasted in a sense that they contain no information, but are stored anyway.

The wasted bits-per-sample flag in a subframe header is set to 1 if a certain number of least-significant bits of all samples in the current subframe are zero. If this is the case, the number of wasted bits-per-sample (k) minus 1 follows the flag in an unary encoding. For example, if k is 3, 0b001 follows. If k = 0, the wasted bits-per-sample flag is 0 and no unary coded k follows.

In case k is not equal to 0, samples are coded ignoring k least-significant bits. For example, if the preceding frame header specified a sample size of 16 bits per sample and k is 3, samples in the subframe are coded as 13 bits per sample. A decoder MUST add k least-significant zero bits by shifting left (padding) after decoding a subframe sample. In case the frame has left/side, right/side or mid/side stereo, padding MUST happen to a sample before it is used to reconstruct a left or right sample.

Besides audio files that have a certain number of wasted bits for the whole file, there exist audio files in which the number of wasted bits varies. There are DVD-Audio discs in which blocks of samples have had their least-significant bits selectively zeroed, as to slightly improve the compression of their otherwise lossless Meridian Lossless Packing codec. There are also audio processors like lossyWAV that enable users to improve compression of their files by a lossless audio codec in a non-lossless way. Because of this the number of wasted bits k MAY change between frames and MAY differ between subframes.

### Constant subframe
In a constant subframe only a single sample is stored. This sample is stored as a integer number coded big-endian, signed two's complement. The number of bits used to store this sample depends on the bit depth of the current subframe. The bit depth of a subframe is equal to the [bit depth as coded in the frame header](#bit-depth-bits), minus the number of [wasted bits coded in the subframe header](#wasted-bits-per-sample). In case a subframe is a side subframe (see the [section on interchannel decorrelation](#interchannel-decorrelation), the bit depth of that subframe is increased by 1 bit.

### Verbatim subframe
A verbatim subframe stores all samples unencoded in sequential order. See [section on Constant subframe](#constant-subframe) on how a sample is stored unencoded. The number of samples that need to be stored in a subframe is given by the blocksize in the frame header.

### Fixed predictor subframe
Five different fixed predictors are defined in the following table, one for each prediction order 0 through 4. In the table is also a derivation, which explains the rationale for choosing these fixed predictors.

Order | Prediction                                    | Derivation
:-----|:----------------------------------------------|:----------------------------------------
0     | 0                                             | N/A
1     | s(n-1)                                        | N/A
2     | 2 * s(n-1) - s(n-2)                           | s(n-1) + s'(n-1)
3     | 3 * s(n-1) - 3 * s(n-2) + s(n-3)              | s(n-1) + s'(n-1) + s''(n-1)
4     | 4 * s(n-1) - 6 * s(n-2) + 4 * s(n-3) - s(n-4) | s(n-1) + s'(n-1) + s''(n-1) + s'''(n-1)

Where

- n is the number of the sample being predicted
- s(n) is the sample being predicted
- s(n-1) is the sample before the one being predicted
- s'(n-1) is the difference between the previous sample and the sample before that, i.e. s(n-1) - s(n-2). This is the closest available first-order discrete derivative
- s''(n-1) is s'(n-1) - s'(n-2) or the closest available second-order discrete derivative
- s'''(n-1) is s''(n-1) - s''(n-2) or the closest available third-order discrete derivative

To encode a signal with a fixed predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a fixed predictor, first the residual has to be decoded, after which for each sample the prediction can be added. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough fully decoded previous samples are needed to calculate the prediction.

For fixed predictor order 0, the prediction is always 0, thus each residual sample is equal to its corresponding input or decoded sample. The difference between a fixed predictor with order 0 and a verbatim subframe, is that a verbatim subframe stores all samples unencoded, while a fixed predictor with order 0 has all its samples processed by the residual coder.

The first order fixed predictor is comparable to how DPCM encoding works, as the resulting residual sample is the difference between the corresponding sample and the sample before it. The higher fixed predictors can be understood as polynomials fitted to the previous samples.

As the fixed predictors are specified, they do not have to be stored. The fixed predictor order specifies which predictor is used. To be able to predict samples, warm-up samples are stored, as the predictor needs previous samples in its prediction. The number of warm-up samples is equal to the predictor order. See [section on Constant subframe](#constant-subframe) on how samples are stored unencoded. Directly following the warm-up samples is the coded residual.

### Linear predictor subframe
Whereas fixed predictors are well suited for simple signals, using a (non-fixed) linear predictor on more complex signals can improve compression by making the residual samples even smaller. There is a certain trade-off however, as storing the predictor coefficients takes up space as well.

In the FLAC format, a predictor is defined by up to 32 predictor coefficients and a shift. To form a prediction, each coefficient is multiplied with its corresponding past sample, the results are added and this addition is then shifted. To encode a signal with a linear predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a linear predictor, first the residual has to be decoded, after which for each sample the prediction can be added. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough fully decoded previous samples are needed to calculate the prediction.

The table below defines how a linear predictor subframe appears in the bitstream

Data             | Description
:----------------|:-----------
`s(n)`           | Unencoded warm-up samples (n = frame's bits-per-sample \* lpc order).
`u(4)`           | (Predictor coefficient precision in bits)-1 (NOTE: 0b1111 is invalid).
`s(5)`           | Prediction right shift needed in bits.
`s(n)`           | Unencoded predictor coefficients (n = predictor coefficient precision \* lpc order).
`Coded residual` | Encoded residual

See [section on Constant subframe](#constant-subframe) on how the warm-up samples are stored unencoded. The unencoded predictor coefficients are stored the same way as the warm-up samples, but the number of bits needed for each coefficient is defined by the predictor coefficient precision. While the prediction right shift is signed two's complement, this number MUST be positive.

Please note that the order in which the predictor coefficients appear in the bitstream corresponds to which **past** sample they belong. In other words, the order of the predictor coefficients is opposite to the chronological order of the samples. So, the first predictor coefficient has to be multiplied with the sample directly before the sample that is being predicted, the second predictor coefficient has to be multiplied with the sample before that etc.

### Coded residual
The first two bits in a coded residual indicate which coding method is used. See the table below

Value       | Description
-----------:|:-----------
0b00        | partitioned Rice code with 4-bit parameters
0b01        | partitioned Rice code with 5-bit parameters
0b10 - 0b11 | reserved

Both defined coding methods work the same way, but differ in the number of bits used for rice parameters. The 4 bits that directly follow the coding method bits form the partition order, which is an unsigned number. The rest of the coded residual consists of 2^(partition order) partitions. For example, if the 4 bits are 0b1000, the partition order is 8 and the residual is split up into 2^8 = 256 partitions.

Each partition contains a certain amount of residual samples. The number of residual samples in the first partition is equal to (blocksize >> partition order) - predictor order, i.e. the blocksize divided by the number of partitions minus the predictor order. In all other partitions the number of residual samples is equal to (blocksize >> partition order).

The partition order MUST be so that the blocksize is evenly divisible by the number of partitions. This means for example that for all odd blocksizes, only partition order 0 is allowed.  The partition order also MUST be so that the (blocksize >> partition order) is larger than the predictor order. This means for example that with a blocksize of 4096 and a predictor order of 4, partition order cannot be larger than 9.

In case the coded residual of a subframe is one with a 4-bit Rice parameter (see table at the start of this section), the first 4 bits of each partition are either a rice parameter or an escape code. These 4 bits indicate an escape code if they are 0b1111, otherwise they contain the rice parameter as an unsigned number. In case the coded residual of the current subframe is one with a 5-bit Rice parameter, the first 5 bits indicate an escape code if they are 0b11111, otherwise they contain the rice parameter as an unsigned number as well.

In case an escape code was used, the partition does not contain a variable-length rice coded residual, but a fixed-length unencoded residual. Directly following the escape code are 5 bits containing the number of bits with which each residual sample is stored, as an unsigned number. The residual samples themselves are stored signed two's complement.

In case a rice parameter was provided, the partition contains a rice coded residual. The residual samples, which are signed numbers, are represented by unsigned numbers in the rice code. For positive numbers, the representation is the number doubled, for negative numbers, the representation is the number multiplied by -2 and has 1 subtracted. This representation of signed numbers is also known as zigzag encoding and the zigzag encoded residual is called the folded residual. The folded residual samples are then each divided by the rice parameter. The result of each division rounded down (the quotient) is stored unary, the remainder is stored binary.

Decoding the coded residual thus involves selecting the right coding method, finding the number of partitions, reading unary and binary parts of each codeword one-by-one and keeping track of when a new partition starts and thus when a new rice parameter needs to be read.

## Frame footer

Following the last subframe is the frame footer. If the last subframe is not byte aligned (i.e. the bits required to store all subframes put together are not divisible by 8), zero bits are added until byte alignment is reached. Following this is a 16-bit CRC, initialized with 0, with polynomial x^16 + x^15 + x^2 + x^0. This CRC covers the whole frame excluding the 16-bit CRC, including the sync code.

# Implementation status

This section records the status of known implementations of the FLAC format, and is based on a proposal described in [@?RFC7942]. Please note that the listing of any individual implementation here does not imply endorsement by the IETF. Furthermore, no effort has been spent to verify the information presented here that was supplied by IETF contributors. This is not intended as, and must not be construed to be, a catalog of available implementations or their features.  Readers are advised to note that other implementations may exist.

A reference encoder and decoder implementation of the FLAC format exists, known as libFLAC, maintained by Xiph.Org. It can be found at https://xiph.org/flac/ Note that while all libFLAC components are licensed under 3-clause BSD, the flac and metaflac command line tools often supplied together with libFLAC are licensed under GPL.

Another completely independent implementation of both encoder and decoder of the FLAC format is available in libavcodec, maintained by FFmpeg, licensed under LGPL 2.1 or later. It can be found at https://ffmpeg.org/

A list of other implementations and an overview of which parts of the format they implement can be found here: https://github.com/ietf-wg-cellar/flac-specification/wiki/Implementations

# Security Considerations

Like any other codec (such as [@?RFC6716]), FLAC should not be used with insecure ciphers or cipher modes that are vulnerable to known plaintext attacks. Some of the header bits as well as the padding are easily predictable.

Implementations of the FLAC codec need to take appropriate security considerations into account. Those related to denial of service are outlined in Section 2.1 of [@!RFC4732]. It is extremely important for the decoder to be robust against malicious payloads. Malicious payloads **MUST NOT** cause the decoder to overrun its allocated memory or to take an excessive amount of resources to decode. An overrun in allocated memory could lead to arbitrary code execution by an attacker. The same applies to the encoder, even though problems in encoders are typically rarer. Malicious audio streams **MUST NOT** cause the encoder to misbehave because this would allow an attacker to attack transcoding gateways. An example is allocating more memory than available especially with blocksizes of more than 10000 or with big metadata blocks, or not allocating enough memory before copying data, which lead to execution of malicious code, crashes, freezes or reboots on some known implementations.
See the [FLAC decoder testbench](https://wiki.hydrogenaud.io/index.php?title=FLAC_decoder_testbench) for a non-exhaustive list of FLAC files with extreme configurations which lead to crashes or reboots on some known implementations.

None of the content carried in FLAC is intended to be executable.
