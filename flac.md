# Introduction

This document defines the FLAC format and its streamable subset. FLAC files and streams can code for pulse-code modulated (PCM) audio with 1 to 8 channels, sample rates from 1 up to 1048575 hertz and bit depths from 4 up to 32 bits. Most tools for coding to and decoding from the FLAC format have been optimized for CD-audio, which is PCM audio with 2 channels, a sample rate of 44.1 kHz, and a bit depth of 16 bits.

FLAC is able to achieve lossless compression because samples in audio signals tend to be highly correlated with their close neighbors. In contrast with general-purpose compressors, which often use dictionaries, do run-length coding, or exploit long-term repetition, FLAC removes redundancy solely in the very short term, looking back at at most 32 samples.

The coding methods provided by the FLAC format work best on PCM audio signals, of which the samples have a signed representation and are centered around zero. Audio signals in which samples have an unsigned representation must be transformed to a signed representation as described in this document in order to achieve reasonable compression. The FLAC format is not suited for compressing audio that is not PCM.

# Notation and Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they appear in all capitals, as shown here.

Values expressed as `u(n)` represent unsigned big-endian integer using `n` bits. Values expressed as `s(n)` represent signed big-endian integer using `n` bits, signed two's complement. Where necessary `n` is expressed as an equation using `*` (multiplication), `/` (division), `+` (addition), or `-` (subtraction). An inclusive range of the number of bits expressed is represented with an ellipsis, such as `u(m...n)`.

While the FLAC format can store digital audio as well as other digital signals, this document uses terminology specific to digital audio. The use of more generic terminology was deemed less clear, so a reader interested in non-audio use of the FLAC format is expected to make the translation from audio-specific terms to more generic terminology.

# Definitions

- **Lossless compression**: reducing the amount of computer storage space needed to store data without needing to remove or irreversibly alter any of this data in doing so. In other words, decompressing losslessly compressed information returns exactly the original data.

- **Lossy compression**: like lossless compression, but instead removing, irreversibly altering, or only approximating information for the purpose of further reducing the amount of computer storage space needed. In other words, decompressing lossy compressed information returns an approximation of the original data.

- **Block**: A (short) section of linear pulse-code modulated audio with one or more channels.

- **Subblock**: All samples within a corresponding block for one channel. One or more subblocks form a block, and all subblocks in a certain block contain the same number of samples.

- **Frame**: A frame header, one or more subframes, and a frame footer. It encodes the contents of a corresponding block.

- **Subframe**: An encoded subblock. All subframes within a frame code for the same number of samples. When interchannel decorrelation is used, a subframe can correspond to either the (per-sample) average of two subblocks or the (per-sample) difference between two subblocks, instead of to a subblock directly, see [section interchannel decorrelation](#interchannel-decorrelation).

- **Interchannel samples**: A sample count that applies to all channels. For example, one second of 44.1 kHz audio has 44100 interchannel samples, meaning each channel has that number of samples.

- **Block size**: The number of interchannel samples contained in a block or coded in a frame.

- **Bit depth** or **bits per sample**: the number of bits used to contain each sample. This MUST be the same for all subblocks in a block but MAY be different for different subframes in a frame because of [interchannel decorrelation](#interchannel-decorrelation).

- **Predictor**: a model used to predict samples in an audio signal based on past samples. FLAC uses such predictors to remove redundancy in a signal in order to be able to compress it.

- **Linear predictor**: a predictor using linear prediction (see [@LinearPrediction]). This is also called **linear predictive coding (LPC)**. With a linear predictor, each prediction is a linear combination of past samples, hence the name. A linear predictor has a causal discrete-time finite impulse response (see [@FIR]).

<reference anchor="LinearPrediction" target="https://en.wikipedia.org/wiki/Linear_prediction">
  <front>
    <title>Linear prediction - Wikipedia</title>
    <author/>
    <date/>
  </front>
</reference>

<reference anchor="FIR" target="https://en.wikipedia.org/wiki/Finite_impulse_response">
  <front>
    <title>Finite impulse response - Wikipedia</title>
    <author/>
    <date/>
  </front>
</reference>

- **Fixed predictor**: a linear predictor in which the model parameters are the same across all FLAC files, and thus do not need to be stored.

- **Predictor order**: the number of past samples that a predictor uses. For example, a 4th order predictor uses the 4 samples directly preceding a certain sample to predict it. In FLAC, samples used in a predictor are always consecutive, and are always the samples directly before the sample that is being predicted.

- **Residual**: The audio signal that remains after a predictor has been subtracted from a subblock. If the predictor has been able to remove redundancy from the signal, the samples of the remaining signal (the **residual samples**) will have, on average, a smaller numerical value than the original signal.

- **Rice code**: A variable-length code (see [@VarLengthCode]) that compresses data by making use of the observation that, after using an effective predictor, most residual samples are closer to zero than the original samples, while still allowing for a small part of the samples to be much larger.

<reference anchor="VarLengthCode" target="https://en.wikipedia.org/wiki/Variable-length_code">
  <front>
    <title>Variable-length code - Wikipedia</title>
    <author/>
    <date/>
  </front>
</reference>

# Conceptual overview

Similar to many other audio coders, a FLAC file is encoded following the steps below. On decoding a FLAC file, these steps are undone in reverse order, i.e., from bottom to top.

- `Blocking` (see [section blocking](#blocking)). The input is split up into many contiguous blocks.

- `Interchannel Decorrelation` (see [section interchannel decorrelation](#interchannel-decorrelation)). In the case of stereo streams, the FLAC format allows for transforming the left-right signal into a mid-side signal, a left-side signal or a side-right signal to remove redundancy between channels. Choosing between any of these transformations is done independently for each block.

- `Prediction` (see [section prediction](#prediction)). To remove redundancy in a signal, a predictor is stored for each subblock or its transformation as formed in the previous step. A predictor consists of a simple mathematical description that can be used, as the name implies, to predict a certain sample from the samples that preceded it. As this prediction is rarely exact, the error of this prediction is passed on to the next stage. The predictor of each subblock is completely independent from other subblocks. Since the methods of prediction are known to both the encoder and decoder, only the parameters of the predictor need to be included in the compressed stream. If no usable predictor can be found for a certain subblock, the signal is stored uncompressed and the next stage is skipped.

- `Residual Coding` (see [section residual coding](#residual-coding)). As the predictor does not describe the signal exactly, the difference between the original signal and the predicted signal (called the error or residual signal) is coded losslessly. If the predictor is effective, the residual signal will require fewer bits per sample than the original signal. FLAC uses Rice coding, a subset of Golomb coding, with either 4-bit or 5-bit parameters to code the residual signal.

In addition, FLAC specifies a metadata system (see [section file-level metadata](#file-level-metadata)), which allows arbitrary information about the stream to be included at the beginning of the stream.

## Blocking

The size used for blocking the audio data has a direct effect on the compression ratio. If the block size is too small, the resulting large number of frames means that a disproportionate amount of bytes will be spent on frame headers. If the block size is too large, the characteristics of the signal may vary so much that the encoder will be unable to find a good predictor. In order to simplify encoder/decoder design, FLAC imposes a minimum block size of 16 samples, except for the last block, and a maximum block size of 65535 samples. The last block is allowed to be smaller than 16 samples to be able to match the length of the encoded audio without using padding.

While the block size does not have to be constant in a FLAC file, it is often difficult to find the optimal arrangement of block sizes for maximum compression. Because of this, the FLAC format explicitly stores whether a file has a constant or a variable block size throughout the stream, and stores a block number instead of a sample number to slightly improve compression if a stream has a constant block size.

## Interchannel Decorrelation

In many audio files, channels are correlated. The FLAC format can exploit this correlation in stereo files by not directly coding subblocks into subframes, but instead coding an average of all samples in both subblocks (a mid channel) or the difference between all samples in both subblocks (a side channel). The following combinations are possible:

- **Independent**. All channels are coded independently. All non-stereo files MUST be encoded this way.

- **Mid-side**. A left and right subblock are converted to mid and side subframes. To calculate a sample for a mid subframe, the corresponding left and right samples are summed and the result is shifted right by 1 bit. To calculate a sample for a side subframe, the corresponding right sample is subtracted from the corresponding left sample. On decoding, all mid channel samples have to be shifted left by 1 bit. Also, if a side channel sample is odd, 1 has to be added to the corresponding mid channel sample after it has been shifted left by one bit. To reconstruct the left channel, the corresponding samples in the mid and side subframes are added and the result shifted right by 1 bit, while for the right channel the side channel has to be subtracted from the mid channel and the result shifted right by 1 bit.

- **Left-side**. The left subblock is coded and the left and right subblocks are used to code a side subframe. The side subframe is constructed in the same way as for mid-side. To decode, the right subblock is restored by subtracting the samples in the side subframe from the corresponding samples in the the left subframe.

- **Right-side**. The right subblock is coded and the left and right subblocks are used to code a side subframe. Note that the actual coded subframe order is side-right. The side subframe is constructed in the same way as for mid-side. To decode, the left subblock is restored by adding the samples in the side subframe to the corresponding samples in the right subframe.

The side channel needs one extra bit of bit depth as the subtraction can produce sample values twice as large as the maximum possible in any given bit depth. The mid channel in mid-side stereo does not need one extra bit, as it is shifted right one bit. The right shift of the mid channel does not lead to non-lossless behavior, because an odd sample in the mid subframe must always be accompanied by a corresponding odd sample in the side subframe, which means the lost least-significant bit can be restored by taking it from the sample in the side subframe.

## Prediction

The FLAC format has four methods for modeling the input signal:

1. **Verbatim**. Samples are stored directly, without any modeling. This method is used for inputs with little correlation, like white noise. Since the raw signal is not actually passed through the residual coding stage (it is added to the stream 'verbatim'), this method is different from using a zero-order fixed predictor.

1. **Constant**. A single sample value is stored. This method is used whenever a signal is pure DC ("digital silence"), i.e., a constant value throughout.

1. **Fixed predictor**. Samples are predicted with one of five fixed (i.e., predefined) predictors, and the error of this prediction is processed by the residual coder. These fixed predictors are well suited for predicting simple waveforms. Since the predictors are fixed, no predictor coefficients are stored. From a mathematical point of view, the predictors work by extrapolating the signal from the previous samples. The number of previous samples used is equal to the predictor order. For more information, see [section fixed predictor subframe](#fixed-predictor-subframe).

1. **Linear predictor**. Samples are predicted using past samples and a set of predictor coefficients, and the error of this prediction is processed by the residual coder. Compared to a fixed predictor, using a generic linear predictor adds overhead as predictor coefficients need to be stored. Therefore, this method of prediction is best suited for predicting more complex waveforms, where the added overhead is offset by space savings in the residual coding stage resulting from more accurate prediction. A linear predictor in FLAC has two parameters besides the predictor coefficients and the predictor order: the number of bits with which each coefficient is stored (the coefficient precision) and a prediction right shift. A prediction is formed by taking the sum of multiplying each predictor coefficient with the corresponding past sample, and dividing that sum by applying the specified right shift. For more information, see [section linear predictor subframe](#linear-predictor-subframe).

A FLAC encoder is free to select any of the above methods to model the input. However, to ensure lossless coding, the following exceptions apply:

- When the samples that need to be stored do not all have the same value (i.e., the signal is not constant), a constant subframe cannot be used.
- When an encoder is unable to find a fixed or linear predictor for which all residual samples are representable in 32-bit signed integers as stated in [section coded residual](#coded-residual), a verbatim subframe is used.

For more information on fixed and linear predictors, see [@HPL-1999-144] and [@robinson-tr156].

<reference anchor="HPL-1999-144" target="https://www.hpl.hp.com/techreports/1999/HPL-1999-144.pdf">
    <front>
        <title>Lossless Compression of Digital Audio</title>
        <author initials="M" surname="Hans" fullname="Mat Hans">
            <organization>Client and Media Systems Laboratory, HP Laboratories Palo Alto</organization>
        </author>
        <author initials="RW" surname="Schafer" fullname="Ronald W. Schafer">
            <organization>Center for Signal &amp; Image Processing at the School of Electrical and Computer Engineering, Georgia Institute of the Technology, Atlanta, Georgia</organization>
        </author>
        <date month="11" year="1999"/>
    </front>
    <seriesInfo name="DOI" value="10.1109/79.939834"/>
</reference>

<reference anchor="robinson-tr156" target="https://mi.eng.cam.ac.uk/reports/abstracts/robinson_tr156.html">
    <front>
        <title>SHORTEN: Simple lossless and near-lossless waveform compression</title>
        <author initials="T" surname="Robinson" fullname="Tony Robinson">
            <organization>Cambridge University Engineering Department</organization>
        </author>
        <date month="12" year="1994"/>
    </front>
</reference>

## Residual Coding

If a subframe uses a predictor to approximate the audio signal, a residual is stored to 'correct' the approximation to the exact value. When an effective predictor is used, the average numerical value of the residual samples is smaller than that of the samples before prediction. While having smaller values on average, it is possible that a few 'outlier' residual samples are much larger than any of the original samples. Sometimes these outliers even exceed the range the bit depth of the original audio offers.

To be able to efficiently code such a stream of relatively small numbers with an occasional outlier, Rice coding (a subset of Golomb coding) is used. Depending on how small the numbers are that have to be coded, a Rice parameter is chosen. The numerical value of each residual sample is split into two parts by dividing it by `2^(Rice parameter)`, creating a quotient and a remainder. The quotient is stored in unary form, the remainder in binary form. If indeed most residual samples are close to zero and a suitable Rice parameter is chosen, this form of coding, a so-called variable-length code, fewer less bits to store than storing the residual in unencoded form.

As Rice codes can only handle unsigned numbers, signed numbers are zigzag encoded to a so-called folded residual. See [section coded residual](#coded-residual) for a more thorough explanation.

Quite often, the optimal Rice parameter varies over the course of a subframe. To accommodate this, the residual can be split up into partitions, where each partition has its own Rice parameter. To keep overhead and complexity low, the number of partitions used in a subframe is limited to powers of two.

The FLAC format uses two forms of Rice coding, which only differ in the number of bits used for encoding the Rice parameter, either 4 or 5 bits.

# Format principles

FLAC has no format version information, but it does contain reserved space in several places. Future versions of the format MAY use this reserved space safely without breaking the format of older streams. Older decoders MAY choose to abort decoding when encountering data encoded using methods they do not recognize. Apart from reserved patterns, the format specifies forbidden patterns in certain places, meaning that the patterns MUST NOT appear in any bitstream. They are listed in the following table.

{anchor="tableforbiddenpatterns"}
Description                                 | Reference
:-------------------------------------------|:------------
Metadata block type 127                     | [Metadata block header](#metadata-block-header)
Minimum and maximum block sizes smaller than 16 in streaminfo metadata block | [Streaminfo metadata block](#streaminfo)
Sample rate bits 0b1111                     | [Sample rate bits](#sample-rate-bits)
Uncommon blocksize 65536                    | [Uncommon block size](#uncommon-block-size)
Predictor coefficient precision bits 0b1111 | [Linear predictor subframe](#linear-predictor-subframe)
Negative predictor right shift              | [Linear predictor subframe](#linear-predictor-subframe)

All numbers used in a FLAC bitstream are integers, there are no floating-point representations. All numbers are big-endian coded, except the field lengths used in Vorbis comments (see [section Vorbis comment](#vorbis-comment)), which are little-endian coded. All numbers are unsigned except linear predictor coefficients, the linear prediction shift (see [section linear predictor subframe](#linear-predictor-subframe)), and numbers that directly represent samples, which are signed. None of these restrictions apply to application metadata blocks or to Vorbis comment field contents.

All samples encoded to and decoded from the FLAC format MUST be in a signed representation.

There are several ways to convert unsigned sample representations to signed sample representations, but the coding methods provided by the FLAC format work best on audio signals of which the numerical values of the samples are centered around zero, i.e., have no DC offset. In most unsigned audio formats, signals are centered around halfway the range of the unsigned integer type used. If that is the case, converting sample representations by first copying the number to a signed integer with sufficient range and then subtracting half of the range of the unsigned integer type, results in a signal with samples centered around 0.

Unary coding in a FLAC bitstream is done with zero bits terminated with a one bit, e.g., the number 5 is coded unary as 0b000001. This prevents the frame sync code from appearing in unary coded numbers.

When a FLAC file contains data that is forbidden or otherwise not valid, decoder behavior is left unspecified. A decoder MAY choose to stop decoding upon encountering such data. Examples of such data are

- One or more decoded sample values exceed the range offered by the bit depth as coded for that frame. E.g., in a frame with a bit depth of 8 bits, any samples not in the inclusive range from -128 to 127 are not valid.
- The number of wasted bits (see [section wasted bits per sample](#wasted-bits-per-sample)) used by a subframe is such that the bit depth of that subframe (see [section constant subframe](#constant-subframe) for a description of subframe bit depth) equals zero or is negative.
- A frame header CRC (see [section frame header CRC](#frame-header-crc)) or frame footer CRC (see [section frame footer](#frame-footer)) does not validate.
- One of the forbidden bit patterns described in table (#tableforbiddenpatterns, use counter) above is used.

# Format layout

Before the formal description of the stream, an overview of the layout of the FLAC format might be helpful.

A FLAC bitstream consists of the `fLaC` (i.e., 0x664C6143) marker at the beginning of the stream, followed by a mandatory metadata block (called the STREAMINFO block), any number of other metadata blocks, and then the audio frames.

FLAC supports up to 127 kinds of metadata blocks; currently, 7 kinds are defined in [section file-level metadata](#file-level-metadata).

The audio data is composed of one or more audio frames. Each frame consists of a frame header, which contains a sync code, information about the frame like the block size, sample rate, number of channels, et cetera, and an 8-bit CRC. The frame header also contains either the sample number of the first sample in the frame (for variable block size streams), or the frame number (for fixed block size streams). This allows for fast, sample-accurate seeking to be performed. Following the frame header are encoded subframes, one for each channel. The frame is then zero-padded to a byte boundary and finished with a frame footer containing a checksum for the frame. Each subframe has its own header that specifies how the subframe is encoded.

In order to allow a decoder to start decoding at any place in the stream, each frame starts with a byte-aligned 15-bit sync code. However, since it is not guaranteed that the sync code does not appear elsewhere in the frame, the decoder can check that it synced correctly by parsing the rest of the frame header and validating the frame header CRC.

Furthermore, to allow a decoder to start decoding at any place in the stream even without having received a streaminfo metadata block, each frame header contains some basic information about the stream. This information includes sample rate, bits per sample, number of channels, etc. Since the frame header is pure overhead, it has a direct effect on the compression ratio. To keep the frame header as small as possible, FLAC uses lookup tables for the most commonly used values for frame properties. When a certain property has a value that is not covered by the lookup table, the decoder is directed to find the value of that property (for example, the sample rate) at the end of the frame header or in the streaminfo metadata block. If a frame header refers to the streaminfo metadata block, the file is not 'streamable', see [section streamable subset](#streamable-subset) for details. In this way, the file is streamable and the frame header size small for all of the most common forms of audio data.

Individual subframes (one for each channel) are coded separately within a frame, and appear serially in the stream. In other words, the encoded audio data is NOT channel-interleaved. This reduces decoder complexity at the cost of requiring larger decode buffers. Each subframe has its own header specifying the attributes of the subframe, like prediction method and order, residual coding parameters, etc. Each subframe header is followed by the encoded audio data for that channel.

# Streamable subset
The FLAC format specifies a subset of itself as the FLAC streamable subset. The purpose of this is to ensure that any streams encoded according to this subset are truly "streamable", meaning that a decoder that cannot seek within the stream can still pick up in the middle of the stream and start decoding. It also makes hardware decoder implementations more practical by limiting the encoding parameters in such a way that decoder buffer sizes and other resource requirements can be easily determined. The `flac` command-line tool, part of the FLAC reference implementation (see [section implementation status](#implementation-status)), generates streamable subset files by default unless the `--lax` command-line option is used. The streamable subset makes the following limitations on what MAY be used in the stream:

- The [sample rate bits](#sample-rate-bits) in the frame header MUST be 0b0001-0b1110, i.e., the frame header MUST NOT refer to the streaminfo metadata block to describe the sample rate.
- The [bit depth bits](#bit-depth-bits) in the frame header MUST be 0b001-0b111, i.e., the frame header MUST NOT refer to the streaminfo metadata block to describe the bit depth.
- The stream MUST NOT contain blocks with more than 16384 interchannel samples, i.e., the maximum block size must not be larger than 16384.
- Audio with a sample rate less than or equal to 48000 Hz MUST NOT be contained in blocks with more than 4608 interchannel samples, i.e., the maximum block size used for this audio must not be larger than 4608.
- Linear prediction subframes (see [section linear predictor subframe](#linear-predictor-subframe)) containing audio with a sample rate less than or equal to 48000 Hz MUST have a predictor order less than or equal to 12, i.e., the subframe type bits in the subframe header (see [section subframe header](#subframe-header)) MUST NOT be 0b101100-0b111111.
- The Rice partition order (see [section coded residual](#coded-residual)) MUST be less than or equal to 8.
- The channel ordering MUST be equal to one defined in [section channels bits](#channels-bits), i.e., the FLAC file MUST NOT need a WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK tag to describe the channel ordering. See [section channel mask](#channel-mask) for details.

# File-level metadata

At the start of a FLAC file or stream, following the `fLaC` ASCII file signature, one or more metadata blocks MUST be present before any audio frames appear. The first metadata block MUST be a streaminfo block.

## Metadata block header

Each metadata block starts with a 4 byte header. The first bit in this header flags whether a metadata block is the last one: it is a 0 when other metadata blocks follow, otherwise it is a 1. The 7 remaining bits of the first header byte contain the type of the metadata block as an unsigned number between 0 and 126 according to the following table. A value of 127 (i.e., 0b1111111) is forbidden. The three bytes that follow code for the size of the metadata block in bytes, excluding the 4 header bytes, as an unsigned number coded big-endian.

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
127     | forbidden, to avoid confusion with a frame sync code


## Streaminfo

The streaminfo metadata block has information about the whole stream, like sample rate, number of channels, total number of samples, etc. It MUST be present as the first metadata block in the stream. Other metadata blocks MAY follow. There MUST be no more than one streaminfo metadata block per FLAC stream.

If the streaminfo metadata block contains incorrect or incomplete information, decoder behavior is left unspecified (i.e., up to the decoder implementation). A decoder MAY choose to stop further decoding when the information supplied by the streaminfo metadata block turns out to be incorrect or contains forbidden values. A decoder accepting information from the streaminfo block (most-significantly the maximum frame size, maximum block size, number of audio channels, number of bits per sample, and total number of samples) without doing further checks during decoding of audio frames could be vulnerable to buffer overflows. See also [section security considerations](#security-considerations).

Data     | Description
:--------|:-----------
`u(16)`  | The minimum block size (in samples) used in the stream, excluding the last block.
`u(16)`  | The maximum block size (in samples) used in the stream.
`u(24)`  | The minimum frame size (in bytes) used in the stream. A value of `0` signifies that the value is not known.
`u(24)`  | The maximum frame size (in bytes) used in the stream. A value of `0` signifies that the value is not known.
`u(20)`  | Sample rate in Hz.
`u(3)`   | (number of channels)-1. FLAC supports from 1 to 8 channels.
`u(5)`   | (bits per sample)-1. FLAC supports from 4 to 32 bits per sample.
`u(36)`  | Total number of interchannel samples in the stream. A value of zero here means the number of total samples is unknown.
`u(128)` | MD5 signature of the unencoded audio data. This allows the decoder to determine if an error exists in the audio data even when, despite the error, the bitstream itself is valid. A value of `0` signifies that the value is not known.

The minimum block size and the maximum block size MUST be in the 16-65535 range. The minimum block size MUST be equal to or less than the maximum block size.

Any frame but the last one MUST have a block size equal to or greater than the minimum block size and MUST have a block size equal to or lesser than the maximum block size. The last frame MUST have a block size equal to or lesser than the maximum block size, it does not have to comply to the minimum block size because the block size of that frame must be able to accommodate the length of the audio data the stream contains. 

If the minimum block size is equal to the maximum block size, the file contains a fixed block size stream, as the minimum block size excludes the last block. Note that in the case of a stream with a variable block size, the actual maximum block size MAY be smaller than the maximum block size listed in the streaminfo block, and the actual smallest block size excluding the last block MAY be larger than the minimum block size listed in the streaminfo block. This is because the encoder has to write these fields before receiving any input audio data, and cannot know beforehand what block sizes it will use, only between what bounds these will be chosen.

The sample rate MUST NOT be 0 when the FLAC file contains audio. A sample rate of 0 MAY be used when non-audio is represented. This is useful if data is encoded that is not along a time axis, or when the sample rate of the data lies outside the range that FLAC can represent in the streaminfo metadata block. If a sample rate of 0 is used it is recommended to store the meaning of the encoded content in a Vorbis comment field (see [section Vorbis comment](#vorbis-comment)) or an application metadata block (see [section application](#application)). This document does not define such metadata.

The MD5 signature is made by performing an MD5 transformation on the samples of all channels interleaved, represented in signed, little-endian form. This interleaving is on a per-sample basis, so for a stereo file this means first the first sample of the first channel, then the first sample of the second channel, then the second sample of the first channel etc. Before performing the MD5 transformation, all samples must be byte-aligned. If the bit depth is not a whole number of bytes, the value of each sample is sign extended to the next whole number of bytes.

So, in the case of a 2-channel stream with 6-bit samples, bits will be lined up as follows.

```
SSAAAAAASSBBBBBBSSCCCCCC
^   ^   ^   ^   ^   ^
|   |   |   |   |  Bits of 2nd sample of 1st channel
|   |   |   |  Sign extension bits of 2nd sample of 2nd channel
|   |   |  Bits of 1st sample of 2nd channel
|   |  Sign extension bits of 1st sample of 2nd channel
|  Bits of 1st sample of 1st channel
Sign extention bits of 1st sample of 1st channel

```

As another example, in the case of a 1-channel with 12-bit samples, bits are lined up as follows, showing the little-endian byte order

```
AAAAAAAASSSSAAAABBBBBBBBSSSSBBBB
   ^     ^   ^   ^       ^   ^
   |     |   |   |       |  Most-significant 4 bits of 2nd sample
   |     |   |   | Sign extension bits of 2nd sample
   |     |   |  Least-significant 8 bits of 2nd sample
   |     |  Most-significant 4 bits of 1st sample
   |    Sign extension bits of 1st sample
  Least-significant 8 bits of 1st sample

```


## Padding

The padding metadata block allows for an arbitrary amount of padding. This block is useful when it is known that metadata will be edited after encoding; the user can instruct the encoder to reserve a padding block of sufficient size so that when metadata is added, it will simply overwrite the padding (which is relatively quick) instead of having to insert it into the existing file (which would normally require rewriting the entire file). There MAY be one or more padding metadata blocks per FLAC stream.

Data     | Description
:--------|:-----------
`u(n)`   | n '0' bits (n MUST be a multiple of 8, i.e., a whole number of bytes, and MAY be zero)

## Application

The application metadata block is for use by third-party applications. The only mandatory field is a 32-bit identifier. An ID registry is being maintained at https://xiph.org/flac/id.html.

Data     | Description
:--------|:-----------
`u(32)`  | Registered application ID. (Visit the [registration page](https://xiph.org/flac/id.html) to register an ID with FLAC.)
`u(n)`   | Application data (n MUST be a multiple of 8, i.e., a whole number of bytes)

## Seektable

The seektable metadata block can be used to store seek points. It is possible to seek to any given sample in a FLAC stream without a seek table, but the delay can be unpredictable since the bitrate may vary widely within a stream. By adding seek points to a stream, this delay can be significantly reduced. There MUST NOT be more than one seektable metadata block in a stream, but the table can have any number of seek points.

Each seek point takes 18 bytes, so a seek table with 1% resolution within a stream adds less than 2 kilobyte of data. The number of seek points is implied by the metadata header 'length' field, i.e., equal to length / 18. There is also a special 'placeholder' seekpoint that will be ignored by decoders but can be used to reserve space for future seek point insertion.

Data       | Description
:----------|:-----------
Seekpoints | Zero or more seek points as defined in [section seekpoint](#seekpoint).

A seektable is generally not usable for seeking in a FLAC file embedded in a container (see [section container mappings](#container-mappings)), as such containers usually interleave FLAC data with other data and the offsets used in seekpoints are those of an unmuxed FLAC stream. Also, containers often provide their own seeking methods. It is, however, possible to store the seektable in the container along with other metadata when muxing a FLAC file, so this stored seektable can be restored when demuxing the FLAC stream into a standalone FLAC file.

### Seekpoint
Data     | Description
:--------|:-----------
`u(64)`  | Sample number of the first sample in the target frame, or `0xFFFFFFFFFFFFFFFF` for a placeholder point.
`u(64)`  | Offset (in bytes) from the first byte of the first frame header to the first byte of the target frame's header.
`u(16)`  | Number of samples in the target frame.

NOTES

- For placeholder points, the second and third field values are undefined.
- Seek points within a table MUST be sorted in ascending order by sample number.
- Seek points within a table MUST be unique by sample number, with the exception of placeholder points.
- The previous two notes imply that there MAY be any number of placeholder points, but they MUST all occur at the end of the table.
- The sample offsets are those of an unmuxed FLAC stream. The offsets MUST NOT be updated on muxing to reflect the new offsets of FLAC frames in a container.

## Vorbis comment

A Vorbis comment metadata block contains human-readable information coded in UTF-8. The name Vorbis comment points to the fact that the Vorbis codec stores such metadata in almost the same way, see [@Vorbis]. A Vorbis comment metadata block consists of a vendor string optionally followed by a number of fields, which are pairs of field names and field contents. Many users refer to these fields as FLAC tags or simply as tags. A FLAC file MUST NOT contain more than one Vorbis comment metadata block.

<reference anchor="Vorbis" target="https://xiph.org/vorbis/doc/v-comment.html">
  <front>
    <title>Ogg Vorbis I format specification: comment field and header specification</title>
    <author>
      <organization>Xiph.Org</organization>
    </author>
    <date/>
  </front>
</reference>

In a Vorbis comment metadata block, the metadata block header is directly followed by 4 bytes containing the length in bytes of the vendor string as an unsigned number coded little-endian. The vendor string follows UTF-8 coded, and is not terminated in any way.

Following the vendor string are 4 bytes containing the number of fields that are in the Vorbis comment block, stored as an unsigned number, coded little-endian. If this number is non-zero, it is followed by the fields themselves, each of which is stored with a 4 byte length. First, the 4 byte field length in bytes is stored as an unsigned number, coded little-endian. The field itself is, like the vendor string, UTF-8 coded, not terminated in any way.

Each field consists of a field name and a field content, separated by an = character. The field name MUST only consist of UTF-8 code points U+0020 through U+007E, excluding U+003D, which is the = character. In other words, the field name can contain all printable ASCII characters except the equals sign. The evaluation of the field names MUST be case insensitive, so U+0041 through 0+005A (A-Z) MUST be considered equivalent to U+0061 through U+007A (a-z) respectively. The field contents can contain any UTF-8 character.

Note that the Vorbis comment as used in Vorbis allows for on the order of 2\^64 bytes of data whereas the FLAC metadata block is limited to 2\^24 bytes. Given the stated purpose of Vorbis comments, i.e., human-readable textual information, the FLAC metadata block limit is unlikely to be restrictive. Also note that the 32-bit field lengths are coded little-endian, as opposed to the usual big-endian coding of fixed-length integers in the rest of the FLAC format.

### Standard field names

Except for the one defined in [section channel mask](#channel-mask), no standard field names are defined. In general, most FLAC playback devices and software recognize the following field names:

- Title: name of the current work.
- Artist: name of the artist generally responsible for the current work. For orchestral works, this is usually the composer; otherwise, it is often the performer.
- Album: name of the collection the current work belongs to.

For a more comprehensive list of possible field names, [the list of tags used in the MusicBrainz project](http://picard-docs.musicbrainz.org/en/variables/variables.html) is recommended.

### Channel mask

Besides fields containing information about the work itself, one field is defined for technical reasons, of which the field name is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK. This field is used to communicate that the channels in a file differ from the default channels defined in [section channels bits](#channels-bits). For example, by default, a FLAC file containing two channels is interpreted to contain a left and right channel, but with this field, it is possible to describe different channel contents.

The channel mask consists of flag bits indicating which channels are present, stored in a hexadecimal representation preceded by 0x. The flags only signal which channels are present, not in which order, so if a file has to be encoded in which channels are ordered differently, they have to be reordered. Please note that a file in which the channel order is defined through the WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK is not streamable (see [section streamable subset](#streamable-subset)), as the field is not found in each frame header. The mask bits can be found in the following table.

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

Following are three examples:

- If a file has a single channel, being a LFE channel, the Vorbis comment field is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x8.
- If a file has four channels, being front left, front right, top front left, and top front right, the Vorbis comment field is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x5003.
- If an input has four channels, being back center, top front center, front center, and top rear center in that order, they have to be reordered to front center, back center, top front center and top rear center. The Vorbis comment field added is WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x12104.

WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK fields MAY be padded with zeros, for example, 0x0008 for a single LFE channel. Parsing of WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK fields MUST be case-insensitive for both the field name and the field contents.

A WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK field of 0x0 can be used to indicate that none of the audio channels of a file correlate with speaker positions. This is the case when audio needs to be decoded into speaker positions (e.g., Ambisonics B-format audio) or when a multitrack recording is contained.

It is possible for a WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK field to code for fewer channels than are present in the audio. If that is the case, the remaining channels SHOULD NOT be rendered by a playback application unfamiliar with their purpose. For example, the Ambisonics UHJ format is compatible with stereo playback: its first two channels can be played back on stereo equipment, but all four channels together can be decoded into surround sound. For that example, the Vorbis comment field WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK=0x3 would be set, indicating the first two channels are front left and front right, and other channels do not correlate with speaker positions directly.

If audio channels not assigned to any speaker are contained and decoding to speaker positions is possible, it is recommended to provide metadata on how this decoding should take place in another Vorbis comment field or an application metadata block. This document does not define such metadata.

## Cuesheet

To either store the track and index point structure of a Compact Disc Digital Audio (CD-DA) along with its audio or to provide a mechanism to store locations of interest within a FLAC file, a cuesheet metadata block can be used. Certain aspects of this metadata block follow directly from the CD-DA specification, called Red Book, which is standardized as [@IEC.60908.1999].  The description below is complete and further reference to [IEC.60908.1999] is not needed to implement this metadata block.

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
`u(1)`            | `1` if the cuesheet corresponds to a CD-DA, else `0`.
`u(7+258*8)`      | Reserved. All bits MUST be set to zero.
`u(8)`            | Number of tracks in this cuesheet.
Cuesheet tracks   | A number of structures as specified in the [section cuesheet track](#cuesheet-track) equal to the number of tracks specified previously.

If the media catalog number is less than 128 bytes long, it is right-padded with NUL characters. For CD-DA, this is a thirteen digit number, followed by 115 NUL bytes.

The number of lead-in samples has meaning only for CD-DA cuesheets; for other uses, it should be 0. For CD-DA, the lead-in is the TRACK 00 area where the table of contents is stored; more precisely, it is the number of samples from the first sample of the media to the first sample of the first index point of the first track. According to [@IEC.60908.1999], the lead-in MUST be silence and CD grabbing software does not usually store it; additionally, the lead-in MUST be at least two seconds but MAY be longer. For these reasons, the lead-in length is stored here so that the absolute position of the first track can be computed. Note that the lead-in stored here is the number of samples up to the first index point of the first track, not necessarily to INDEX 01 of the first track; even the first track MAY have INDEX 00 data.

The number of tracks MUST be at least 1, as a cuesheet block MUST have a lead-out track. For CD-DA, this number MUST be no more than 100 (99 regular tracks and one lead-out track). The lead-out track is always the last track in the cuesheet. For CD-DA, the lead-out track number MUST be 170 as specified by [@IEC.60908.1999], otherwise it MUST be 255.

### Cuesheet track
Data                          | Description
:-----------------------------|:-----------
`u(64)`                       | Track offset of the first index point in samples, relative to the beginning of the FLAC audio stream.
`u(8)`                        | Track number.
`u(12*8)`                     | Track ISRC.
`u(1)`                        | The track type: 0 for audio, 1 for non-audio. This corresponds to the CD-DA Q-channel control bit 3.
`u(1)`                        | The pre-emphasis flag: 0 for no pre-emphasis, 1 for pre-emphasis. This corresponds to the CD-DA Q-channel control bit 5.
`u(6+13*8)`                   | Reserved. All bits MUST be set to zero.
`u(8)`                        | The number of track index points.
Cuesheet track index points   | For all tracks except the lead-out track, a number of structures as specified in the [section cuesheet track index point](#cuesheet-track-index-point) equal to the number of index points specified previously.

Note that the track offset differs from the one in CD-DA, where the track's offset in the TOC is that of the track's INDEX 01 even if there is an INDEX 00. For CD-DA, the track offset MUST be evenly divisible by 588 samples (588 samples = 44100 samples/s \* 1/75 s).

A track number of 0 is not allowed, because the CD-DA specification reserves this for the lead-in. For CD-DA the number MUST be 1-99, or 170 for the lead-out; for non-CD-DA, the track number MUST be 255 for the lead-out. It is recommended to start with track 1 and increase sequentially. Track numbers MUST be unique within a cuesheet.

The track ISRC (International Standard Recording Code) is a 12-digit alphanumeric code; see [@ISRC-handbook]. A value of 12 ASCII NUL characters MAY be used to denote the absence of an ISRC.

<reference anchor="ISRC-handbook" target="https://www.ifpi.org/isrc_handbook/">
    <front>
        <title>International Standard Recording Code (ISRC) Handbook, 4th edition</title>
        <author>
            <organization>International ISRC Registration Authority</organization>
        </author>
        <date year="2021"/>
    </front>
</reference>

There MUST be at least one index point in every track in a cuesheet except for the lead-out track, which MUST have zero. For CD-DA, the number of index points MUST NOT be more than 100.


#### Cuesheet track index point
Data      | Description
:---------|:-----------
`u(64)`   | Offset in samples, relative to the track offset, of the index point.
`u(8)`    | The track index point number.
`u(3*8)`  | Reserved. All bits MUST be set to zero.

For CD-DA, the track index point offset MUST be evenly divisible by 588 samples (588 samples = 44100 samples/s \* 1/75 s). Note that the offset is from the beginning of the track, not the beginning of the audio data.

For CD-DA, a track index point number of 0 corresponds to the track pre-gap. The first index point in a track MUST have a number of 0 or 1, and subsequently, index point numbers MUST increase by 1. Index point numbers MUST be unique within a track.

## Picture

The picture metadata block contains image data of a picture in some way belonging to the audio contained in the FLAC file. Its format is derived from the APIC frame in the ID3v2 specification. However, contrary to the APIC frame in ID3v2, the media type and description are prepended with a 4-byte length field instead of being null delimited strings. A FLAC file MAY contain one or more picture metadata blocks.

Note that while the length fields for media type, description, and picture data are 4 bytes in length and could in theory code for a size up to 4 GiB, the total metadata block size cannot exceed what can be described by the metadata block header, i.e., 16 MiB.

The structure of a picture metadata block is enumerated in the following table.

Data      | Description
:---------|:-----------
`u(32)`   | The picture type according to next table
`u(32)`   | The length of the media type string in bytes.
`u(n*8)`  | The media type string, in printable ASCII characters 0x20-0x7E. The media type MAY also be `-->` to signify that the data part is a URI of the picture instead of the picture data itself.
`u(32)`   | The length of the description string in bytes.
`u(n*8)`  | The description of the picture, in UTF-8.
`u(32)`   | The width of the picture in pixels.
`u(32)`   | The height of the picture in pixels.
`u(32)`   | The color depth of the picture in bits per pixel.
`u(32)`   | For indexed-color pictures (e.g., GIF), the number of colors used, or `0` for non-indexed pictures.
`u(32)`   | The length of the picture data in bytes.
`u(n*8)`  | The binary picture data.

The height, width, color depth, and 'number of colors' fields are for informational purposes only. Applications MUST NOT use them in decoding the picture or deciding how to display it, but MAY use them to decide whether to process a block or not (e.g., when selecting between different picture blocks) and MAY show them to the user. If a picture has no concept for any of these fields (e.g., vector images may not have a height or width in pixels) or the content of any field is unknown, the affected fields MUST be set to zero.

The following table contains all the defined picture types. Values other than those listed in the table are reserved. There MAY only be one each of picture types 1 and 2 in a file. In general practice, many FLAC playback devices and software display the contents of a picture metadata block with picture type 3 (front cover) during playback, if present.

Value | Picture type
:-----|:-----------
0     | Other
1     | PNG file icon of 32x32 pixels
2     | General file icon
3     | Front cover
4     | Back cover
5     | Liner notes page
6     | Media label (e.g., CD, Vinyl or Cassette label)
7     | Lead artist, lead performer, or soloist
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

If not a picture but a URI is contained in this block, the following points apply:

- The URI can be either in absolute or relative form. If an URI is in relative form, it is related to the URI of the FLAC content processed.
- Applications MUST obtain explicit user approval to retrieve images via remote protocols and to retrieve local images not located in the same directory as the FLAC file being processed.
- Applications supporting linked images MUST handle unavailability of URIs gracefully. They MAY report unavailability to the user.
- Applications MAY reject processing URIs for any reason, in particular for security or privacy reasons.

# Frame structure

Directly after the last metadata block, one or more frames follow. Each frame consists of a frame header, one or more subframes, padding zero bits to achieve byte-alignment, and a frame footer. The number of subframes in each frame is equal to the number of audio channels.

Each frame header stores the audio sample rate, number of bits per sample, and number of channels independently of the streaminfo metadata block and other frame headers. This was done to permit multicasting of FLAC files, but it also allows these properties to change mid-stream. Because not all environments in which FLAC decoders are used are able to cope with changes to these properties during playback, a decoder MAY choose to stop decoding on such a change. A decoder that does not check for such a change could be vulnerable to buffer overflows. See also [section security considerations](#security-considerations).

Note that storing audio with changing audio properties in FLAC results in various practical problems. For example, these changes of audio properties must happen on a frame boundary, or the process will not be lossless. When a variable block size is chosen to accommodate this, note that blocks smaller than 16 samples are not allowed and it is therefore not possible to store an audio stream in which these properties change within 16 samples of the last change or the start of the file. Also, since the streaminfo metadata block can only accommodate a single set of properties, it is only valid for part of such an audio stream. Instead, it is RECOMMENDED to store an audio stream with changing properties in FLAC encapsulated in a container capable of handling such changes, as these do not suffer from the mentioned limitations. See [section container mappings](#container-mappings) for details.

## Frame header
Each frame MUST start on a byte boundary and starts with the 15-bit frame sync code 0b111111111111100. Following the sync code is the blocking strategy bit, which MUST NOT change during the audio stream. The blocking strategy bit is 0 for a fixed block size stream or 1 for a variable block size stream. If the blocking strategy is known, a decoder can include this bit when searching for the start of a frame to reduce the possibility of encountering a false positive, as the first two bytes of a frame are either 0xFFF8 for a fixed block size stream or 0xFFF9 for a variable block size stream.

### Block size bits

Following the frame sync code and blocking strategy bit are 4 bits (the first 4 bits of the third byte of each frame) referred to as the block size bits. Their value relates to the block size according to the following table, where v is the value of the 4 bits as an unsigned number. If the block size bits code for an uncommon block size, this is stored after the coded number, see [section uncommon block size](#uncommon-block-size).

Value           | Block size
:---------------|:-----------
0b0000          | reserved
0b0001          | 192
0b0010 - 0b0101 | 144 \* (2\^v), i.e., 576, 1152, 2304, or 4608
0b0110          | uncommon block size minus 1 stored as an 8-bit number
0b0111          | uncommon block size minus 1 stored as a 16-bit number
0b1000 - 0b1111 | 2\^v, i.e., 256, 512, 1024, 2048, 4096, 8192, 16384, or 32768

### Sample rate bits

The next 4 bits (the last 4 bits of the third byte of each frame), referred to as the sample rate bits, contain the sample rate of the audio according to the following table. If the sample rate bits code for an uncommon sample rate, this is stored after the uncommon block size or after the coded number if no uncommon block size was used. See [section uncommon sample rate](#uncommon-sample-rate).

Value   | Sample rate
:-------|:-----------
0b0000  | sample rate only stored in the streaminfo metadata block
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
0b1111  | forbidden

### Channels bits

The next 4 bits (the first 4 bits of the fourth byte of each frame), referred to as the channels bits, contain both the number of channels of the audio as well as any stereo decorrelation used according to the following table.

If a channel layout different than the ones listed in the following table is used, this can be signaled with a WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK tag in a Vorbis comment metadata block, see [section channel mask](#channel-mask) for details. Note that even when such a different channel layout is specified with a WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK and the channel ordering in the following table is overridden, the channels bits still contain the actual number of channels coded in the frame. For details on the way left/side, right/side, and mid/side stereo are coded, see [section interchannel decorrelation](#interchannel-decorrelation).

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
0b1000          | 2 channels, left, right, stored as left/side stereo
0b1001          | 2 channels, left, right, stored as right/side stereo
0b1010          | 2 channels, left, right, stored as mid/side stereo
0b1011 - 0b1111 | reserved

### Bit depth bits

The next 3 bits (bits 5, 6 and 7 of each fourth byte of each frame) contain the bit depth of the audio according to the following table.

Value   | Bit depth
:-------|:-----------
0b000   | bit depth only stored in the streaminfo metadata block
0b001   | 8 bits per sample
0b010   | 12 bits per sample
0b011   | reserved
0b100   | 16 bits per sample
0b101   | 20 bits per sample
0b110   | 24 bits per sample
0b111   | 32 bits per sample

The next bit is reserved and MUST be zero.

### Coded number

Following the reserved bit (starting at the fifth byte of the frame) is either a sample or a frame number, which will be referred to as the coded number. When dealing with variable block size streams, the sample number of the first sample in the frame is encoded. When the file contains a fixed block size stream, the frame number is encoded. See [section frame header](#frame-header) on the blocking strategy bit which signals whether a stream is a fixed block size stream or a variable block size stream. Also see [section addition of blocking strategy bit](#addition-of-blocking-strategy-bit).

The coded number is stored in a variable length code like UTF-8 as defined in [@!RFC3629], but extended to a maximum of 36 bits unencoded, 7 bytes encoded.

When a frame number is encoded, the value MUST NOT be larger than what fits a value of 31 bits unencoded or 6 bytes encoded. Please note that as most general purpose UTF-8 encoders and decoders follow [@!RFC3629], they will not be able to handle these extended codes. Furthermore, while UTF-8 is specifically used to encode characters, FLAC uses it to encode numbers instead. To encode or decode a coded number, follow the procedures of section 3 of [@!RFC3629], but instead of using a character number, use a frame or sample number, and instead of the table in section 3 of [@!RFC3629], use the extended table below.

Number range (hexadecimal)          | Octet sequence (binary)
:-----------------------------------|:--------------------------------------------------------------
0000 0000 0000 -<br/>0000 0000 007F | 0xxxxxxx
0000 0000 0080 -<br/>0000 0000 07FF | 110xxxxx 10xxxxxx
0000 0000 0800 -<br/>0000 0000 FFFF | 1110xxxx 10xxxxxx 10xxxxxx
0000 0001 0000 -<br/>0000 001F FFFF | 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
0000 0020 0000 -<br/>0000 03FF FFFF | 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
0000 0400 0000 -<br/>0000 7FFF FFFF | 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
0000 8000 0000 -<br/>000F FFFF FFFF | 11111110 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx

If the coded number is a frame number, it MUST be equal to the number of frames preceding the current frame. If the coded number is a sample number, it MUST be equal to the number of samples preceding the current frame. In a stream where these requirements are not met, seeking is not (reliably) possible.

For example, a frame that belongs to a variable block size stream and has exactly 51 billion samples preceding it, has its coded number constructed as follows.

```
Octets 1-5
0b11111110 0b10101111 0b10011111 0b10110101 0b10100011
               ^^^^^^     ^^^^^^     ^^^^^^     ^^^^^^
                 |          |          |      Bits 18-13
                 |          |      Bits 24-19
                 |      Bits 30-25
             Bits 36-31

Octets 6-7
0b10111000 0b10000000
    ^^^^^^     ^^^^^^
      |       Bits 6-1
  Bits 12-7
```

A decoder that relies on the coded number during seeking could be vulnerable to buffer overflows or getting stuck in an infinite loop if it seeks in a stream where the coded numbers are non-consecutive or otherwise not valid. See also [section security considerations](#security-considerations).

### Uncommon block size

If the block size bits defined earlier in this section were 0b0110 or 0b0111 (uncommon block size minus 1 stored), this follows the coded number as either an 8-bit or a 16-bit unsigned number coded big-endian. A value of 65535 (corresponding to a block size of 65536) is forbidden and MUST NOT be used, because such a block size cannot be represented in the streaminfo metadata block. A value from 0 up to (and including) 14, which corresponds to a block size from 1 to 15, is only valid for the last frame in a stream and MUST NOT be used for any other frame. See also [section streaminfo](#streaminfo).

### Uncommon sample rate

Following the uncommon block size (or the coded number if no uncommon block size is stored) is the sample rate, if the sample rate bits were 0b1100, 0b1101, or 0b1110 (uncommon sample rate stored), as either an 8-bit or a 16-bit unsigned number coded big-endian.

The sample rate MUST NOT be 0 when the subframe contains audio. A sample rate of 0 MAY be used when non-audio is represented. See [section streaminfo](#streaminfo) for details.

### Frame header CRC

Finally, after either the frame/sample number, an uncommon block size, or an uncommon sample rate, depending on whether the latter two are stored, is an 8-bit CRC. This CRC is initialized with 0 and has the polynomial x^8 + x^2 + x^1 + x^0. This CRC covers the whole frame header before the CRC, including the sync code.

## Subframes

Following the frame header are a number of subframes equal to the number of audio channels. Note that as subframes contain a bitstream that does not necessarily has to be a whole number of bytes, only the first subframe always starts at a byte boundary.

### Subframe header
Each subframe starts with a header. The first bit of the header MUST be 0, followed by 6 bits describing which subframe type is used according to the following table, where v is the value of the 6 bits as an unsigned number.

Value               | Subframe type
:-------------------|:-----------
0b000000            | Constant subframe
0b000001            | Verbatim subframe
0b000010 - 0b000111 | reserved
0b001000 - 0b001100 | Subframe with a fixed predictor of order v-8, i.e., 0, 1, 2, 3 or 4
0b001101 - 0b011111 | reserved
0b100000 - 0b111111 | Subframe with a linear predictor of order v-31, i.e., 1 through 32 (inclusive)

Following the subframe type bits is a bit that flags whether the subframe uses any wasted bits (see [section wasted bits per sample](#wasted-bits-per-sample)). If it is 0, the subframe doesn't use any wasted bits and the subframe header is complete. If it is 1, the subframe does use wasted bits and the number of used wasted bits follows unary coded.

### Wasted bits per sample

Most uncompressed audio file formats can only store audio samples with a bit depth that is an integer number of bytes. Samples of which the bit depth is not an integer number of bytes are usually stored in such formats by padding them with least-significant zero bits to a bit depth that is an integer number of bytes. For example, shifting a 14-bit sample right by 2 pads it to a 16-bit sample, which then has two zero least-significant bits. In this specification, these least-significant zero bits are referred to as wasted bits per sample or simply wasted bits. They are wasted in the sense that they contain no information, but are stored anyway.

The FLAC format can optionally take advantage of these wasted bits by signaling their presence and coding the subframe without them. To do this, the wasted bits per sample flag in a subframe header is set to 0 and the number of wasted bits per sample (k) minus 1 follows the flag in an unary encoding. For example, if k is 3, 0b001 follows. If k = 0, the wasted bits per sample flag is 0 and no unary coded k follows. In this document, if a subframe header signals a certain number of wasted bits, it is said it 'uses' these wasted bits.

If a subframe uses wasted bits (i.e., k is not equal to 0), samples are coded ignoring k least-significant bits. For example, if a frame not employing stereo decorrelation specifies a sample size of 16 bits per sample in the frame header and k of a subframe is 3, samples in the subframe are coded as 13 bits per sample. For more details, see [section constant subframe](#constant-subframe) on how the bit depth of a subframe is calculated. A decoder MUST add k least-significant zero bits by shifting left (padding) after decoding a subframe sample. If the frame has left/side, right/side, or mid/side stereo, a decoder MUST perform padding on the subframes before restoring the channels to left and right. The number of wasted bits per sample MUST be such that the resulting number of bits per sample (of which the calculation is explained in [section constant subframe](#constant-subframe)) is larger than zero.

Besides audio files that have a certain number of wasted bits for the whole file, there exist audio files in which the number of wasted bits varies. There are DVD-Audio discs in which blocks of samples have had their least-significant bits selectively zeroed to slightly improve the compression of their otherwise lossless Meridian Lossless Packing codec. There are also audio processors like lossyWAV that enable users to improve compression of their files by a lossless audio codec in a non-lossless way. Because of this, the number of wasted bits k MAY change between frames and MAY differ between subframes. If the number of wasted bits changes halfway through a subframe (e.g., the first part has 2 wasted bits and the second part has 4 wasted bits) the subframe uses the lowest number of wasted bits, as otherwise non-zero bits would be discarded and the process would not be lossless.

### Constant subframe
In a constant subframe, only a single sample is stored. This sample is stored as an integer number coded big-endian, signed two's complement. The number of bits used to store this sample depends on the bit depth of the current subframe. The bit depth of a subframe is equal to the [bit depth as coded in the frame header](#bit-depth-bits), minus the number of used [wasted bits coded in the subframe header](#wasted-bits-per-sample). If a subframe is a side subframe (see [section interchannel decorrelation](#interchannel-decorrelation)), the bit depth of that subframe is increased by 1 bit.

### Verbatim subframe
A verbatim subframe stores all samples unencoded in sequential order. See [section constant subframe](#constant-subframe) on how a sample is stored unencoded. The number of samples that need to be stored in a subframe is given by the block size in the frame header.

### Fixed predictor subframe
Five different fixed predictors are defined in the following table, one for each prediction order 0 through 4. In the table is also a derivation, which explains the rationale for choosing these fixed predictors.

Order | Prediction                                    | Derivation
:-----|:----------------------------------------------|:----------------------------------------
0     | 0                                             | N/A
1     | a(n-1)                                        | N/A
2     | 2 * a(n-1) - a(n-2)                           | a(n-1) + a'(n-1)
3     | 3 * a(n-1) - 3 * a(n-2) + a(n-3)              | a(n-1) + a'(n-1) + a''(n-1)
4     | 4 * a(n-1) - 6 * a(n-2) + 4 * a(n-3) - a(n-4) | a(n-1) + a'(n-1) + a''(n-1) + a'''(n-1)

Where

- n is the number of the sample being predicted.
- a(n) is the sample being predicted.
- a(n-1) is the sample before the one being predicted.
- a'(n-1) is the difference between the previous sample and the sample before that, i.e., a(n-1) - a(n-2). This is the closest available first-order discrete derivative.
- a''(n-1) is a'(n-1) - a'(n-2) or the closest available second-order discrete derivative.
- a'''(n-1) is a''(n-1) - a''(n-2) or the closest available third-order discrete derivative.

As a predictor makes use of samples preceding the sample that is predicted, it can only be used when enough samples are known. As each subframe in FLAC is coded completely independently, the first few samples in each subframe cannot be predicted. Therefore, a number of so-called warm-up samples equal to the predictor order is stored. These are stored unencoded, bypassing the predictor and residual coding stages. See [section constant subframe](#constant-subframe) on how samples are stored unencoded. The table below defines how a fixed predictor subframe appears in the bitstream.

Data             | Description
:----------------|:-----------
`s(n)`           | Unencoded warm-up samples (n = subframe's bits per sample \* predictor order).
Coded residual   | Coded residual as defined in [section coded residual](#coded-residual)

As the fixed predictors are specified, they do not have to be stored. The fixed predictor order, which is stored in the subframe header, specifies which predictor is used.

To encode a signal with a fixed predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a fixed predictor, the residual is decoded, and then the prediction can be added for each sample. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough fully decoded previous samples are needed to calculate the prediction.

For fixed predictor order 0, the prediction is always 0, thus each residual sample is equal to its corresponding input or decoded sample. The difference between a fixed predictor with order 0 and a verbatim subframe, is that a verbatim subframe stores all samples unencoded, while a fixed predictor with order 0 has all its samples processed by the residual coder.

The first order fixed predictor is comparable to how DPCM encoding works, as the resulting residual sample is the difference between the corresponding sample and the sample before it. The higher order fixed predictors can be understood as polynomials fitted to the previous samples.

### Linear predictor subframe
Whereas fixed predictors are well suited for simple signals, using a (non-fixed) linear predictor on more complex signals can improve compression by making the residual samples even smaller. There is a certain trade-off however, as storing the predictor coefficients takes up space as well.

In the FLAC format, a predictor is defined by up to 32 predictor coefficients and a shift. To form a prediction, each coefficient is multiplied by its corresponding past sample, the results are summed, and this sum is then shifted. To encode a signal with a linear predictor, each sample has the corresponding prediction subtracted and sent to the residual coder. To decode a signal with a linear predictor, the residual is decoded, and then the prediction can be added for each sample. This means that decoding MUST be a sequential process within a subframe, as for each sample, enough decoded samples are needed to calculate the prediction.

The table below defines how a linear predictor subframe appears in the bitstream.

Data             | Description
:----------------|:-----------
`s(n)`           | Unencoded warm-up samples (n = subframe's bits per sample \* lpc order).
`u(4)`           | (Predictor coefficient precision in bits)-1 (NOTE: 0b1111 is forbidden).
`s(5)`           | Prediction right shift needed in bits.
`s(n)`           | Unencoded predictor coefficients (n = predictor coefficient precision \* lpc order).
Coded residual   | Coded residual as defined in [section coded residual](#coded-residual)

See [section constant subframe](#constant-subframe) on how the warm-up samples are stored unencoded. The unencoded predictor coefficients are stored the same way as the warm-up samples, but the number of bits needed for each coefficient is defined by the predictor coefficient precision. While the prediction right shift is signed two's complement, this number MUST NOT be negative, see [section past changes](#restriction-of-lpc-shift-to-non-negative-values) for an explanation why this is.

Please note that the order in which the predictor coefficients appear in the bitstream corresponds to which **past** sample they belong to. In other words, the order of the predictor coefficients is opposite to the chronological order of the samples. So, the first predictor coefficient has to be multiplied with the sample directly before the sample that is being predicted, the second predictor coefficient has to be multiplied with the sample before that, etc.

### Coded residual
The first two bits in a coded residual indicate which coding method is used. See the table below`.

Value       | Description
-----------:|:-----------
0b00        | partitioned Rice code with 4-bit parameters
0b01        | partitioned Rice code with 5-bit parameters
0b10 - 0b11 | reserved

Both defined coding methods work the same way, but differ in the number of bits used for Rice parameters. The 4 bits that directly follow the coding method bits form the partition order, which is an unsigned number. The rest of the coded residual consists of 2^(partition order) partitions. For example, if the 4 bits are 0b1000, the partition order is 8 and the residual is split up into 2^8 = 256 partitions.

Each partition contains a certain number of residual samples. The number of residual samples in the first partition is equal to (block size >> partition order) - predictor order, i.e., the block size divided by the number of partitions minus the predictor order. In all other partitions, the number of residual samples is equal to (block size >> partition order).

The partition order MUST be such that the block size is evenly divisible by the number of partitions. This means, for example, that for all odd block sizes, only partition order 0 is allowed.  The partition order also MUST be such that the (block size >> partition order) is larger than the predictor order. This means, for example, that with a block size of 4096 and a predictor order of 4, the partition order cannot be larger than 9.

Each partition starts with a parameter. If the coded residual of a subframe is one with 4-bit Rice parameters (see the table at the start of this section), the first 4 bits of each partition are either a Rice parameter or an escape code. These 4 bits indicate an escape code if they are 0b1111, otherwise they contain the Rice parameter as an unsigned number. If the coded residual of the current subframe is one with 5-bit Rice parameters, the first 5 bits of each partition indicate an escape code if they are 0b11111, otherwise, they contain the Rice parameter as an unsigned number as well.

#### Escaped partition

If an escape code was used, the partition does not contain a variable-length Rice coded residual, but a fixed-length unencoded residual. Directly following the escape code are 5 bits containing the number of bits with which each residual sample is stored, as an unsigned number. The residual samples themselves are stored signed two's complement. For example, when a partition is escaped and each residual sample is stored with 3 bits, the number -1 is represented as 0b111.

Note that it is possible that the number of bits with which each sample is stored is 0, which means all residual samples in that partition have a value of 0 and that no bits are used to store the samples. In that case, the partition contains nothing except the escape code and 0b00000.

#### Rice code

If a Rice parameter was provided for a certain partition, that partition contains a Rice coded residual. The residual samples, which are signed numbers, are represented by unsigned numbers in the Rice code. For positive numbers, the representation is the number doubled, for negative numbers, the representation is the number multiplied by -2 and has 1 subtracted. This representation of signed numbers is also known as zigzag encoding. The zigzag encoded residual is called the folded residual.

Each folded residual sample is then split into two parts, a most-significant part and a least-significant part. The Rice parameter at the start of each partition determines where that split lies: it is the number of bits in the least-significant part. Each residual sample is then stored by coding the most-significant part as unary, followed by the least-significant part as binary.

For example, take a partition with Rice parameter 3 containing a folded residual sample with 38 as its value, which is 0b100110 in binary. The most-significant part is 0b100 (4) and is stored unary as 0b00001. The least-significant part is 0b110 (6) and is stored as is. The Rice code word is thus 0b00001110. The Rice code words for all residual samples in a partition are stored consecutively.

To decode a Rice code word, zero bits must be counted until encountering a one bit, after which a number of bits given by the Rice parameter must be read. The count of zero bits is shifted left by the Rice parameter (i.e., multiplied by 2 raised to the power Rice parameter) and bitwise ORed with (i.e., added to) the read value. This is the folded residual value. An even folded residual value is shifted right 1 bit (i.e., divided by two) to get the (unfolded) residual value. An odd folded residual value is shifted right 1 bit and then has all bits flipped (1 added to and divided by -2) to get the (unfolded) residual value, subject to negative numbers being signed two's complement on the decoding machine.

[Appendix examples](#examples) shows decoding of a complete coded residual.

#### Residual sample value limit

All residual sample values MUST be representable in the range offered by a 32-bit integer, signed one's complement. Equivalently, all residual sample values MUST fall in the range offered by a 32-bit integer signed two's complement excluding the most negative possible value of that range. This means residual sample values MUST NOT have an absolute value equal to, or larger than, 2 to the power 31. A FLAC encoder MUST make sure of this. If a FLAC encoder is, for a certain subframe, unable to find a suitable predictor for which all residual samples fall within said range, it MUST default to writing a verbatim subframe. [Appendix numerical considerations](#numerical-considerations) explains in which circumstances residual samples are already implicitly representable in said range and thus an additional check is not needed.

The reason for this limit is to ensure that decoders can use 32-bit integers when processing residuals, simplifying decoding. The reason the most negative value of a 32-bit int signed two's complement is specifically excluded is to prevent decoders from having to implement specific handling of that value, as it cannot be negated within a 32-bit signed int, and most library routines calculating an absolute value have undefined behavior on processing that value.

## Frame footer

Following the last subframe is the frame footer. If the last subframe is not byte aligned (i.e., the number of bits required to store all subframes put together is not divisible by 8), zero bits are added until byte alignment is reached. Following this is a 16-bit CRC, initialized with 0, with the polynomial x^16 + x^15 + x^2 + x^0. This CRC covers the whole frame excluding the 16-bit CRC, including the sync code.

# Container mappings

The FLAC format can be used without any container, as it already provides for a very thin transport layer. However, the functionality of this transport is rather limited, and to be able to combine FLAC audio with video, it needs to be encapsulated by a more capable container. This presents a problem: the transport layer provided by the FLAC format mixes data that belongs to the encoded data (like block size and sample rate) with data that belongs to the transport (like checksum and timecode). The choice was made to encapsulate FLAC frames as they are, which means some data will be duplicated and potentially deviating between the FLAC frames and the encapsulating container.

As FLAC frames are completely independent of each other, container format features handling dependencies do not need to be used. For example, all FLAC frames embedded in Matroska are marked as keyframes when they are stored in a SimpleBlock, and tracks in an MP4 file containing only FLAC frames do not need a sync sample box.

## Ogg mapping

The Ogg container format is defined in [@?RFC3533]. The first packet of a logical bitstream carrying FLAC data is structured according to the following table.

Data     | Description
:--------|:-----------
5 bytes  | Bytes `0x7F 0x46 0x4C 0x41 0x43` (as also defined by [@?RFC5334])
2 bytes  | Version number of the FLAC-in-Ogg mapping. These bytes are `0x01 0x00`, meaning version 1.0 of the mapping.
2 bytes  | Number of header packets (excluding the first header packet) as an unsigned number coded big-endian.
4 bytes  | The `fLaC` signature
4 bytes  | A metadata block header for the streaminfo block
34 bytes | A streaminfo metadata block

The number of header packets MAY be 0, which means the number of packets that follow is unknown. This first packet MUST NOT share a Ogg page with any other packets. This means the first page of a logical stream of FLAC-in-Ogg is always 79 bytes.

Following the first packet are one or more header packets, each of which contains a single metadata block. The first of these packets SHOULD be a vorbis comment metadata block, for historic reasons. This is contrary to unencapsulated FLAC streams, where the order of metadata blocks is not important except for the streaminfo block and where a vorbis comment metadata block is optional.

Following the header packets are audio packets. Each audio packet contains a single FLAC frame. The first audio packet MUST start on a new Ogg page, i.e., the last metadata block MUST finish its page before any audio packets are encapsulated.

The granule position of all pages containing header packets MUST be 0. For pages containing audio packets, the granule position is the number of the last sample contained in the last completed packet in the frame. The sample numbering considers interchannel samples. If a page contains no packet end (e.g., when it only contains the start of a large packet, which continues on the next page), then the granule position is set to the maximum value possible, i.e., `0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF`.

The granule position of the first audio data page with a completed packet MAY be larger than the number of samples contained in packets that complete on that page. In other words, the apparent sample number of the first sample in the stream following from the granule position and the audio data MAY be larger than 0. This allows, for example, a server to cast a live stream to several clients that joined at different moments, without rewriting the granule position for each client.

If an audio stream is encoded where audio properties (sample rate, number of channels, or bit depth) change at some point in the stream, this should be dealt with by finishing encoding of the current Ogg stream and starting a new Ogg stream, concatenated to the previous one. This is called chaining in Ogg. See the Ogg specification [@?RFC3533] for details.

## Matroska mapping

The Matroska container format is defined in [@?I-D.ietf-cellar-matroska]. The codec ID (EBML path `\Segment\Tracks\TrackEntry\CodecID`) assigned to signal tracks carrying FLAC data is `A_FLAC` in ASCII. All FLAC data before the first audio frame (i.e., the `fLaC` ASCII signature and all metadata blocks) is stored as CodecPrivate data (EBML path `\Segment\Tracks\TrackEntry\CodecPrivate`).

Each FLAC frame (including all of its subframes) is treated as a single frame in the Matroska context.

If an audio stream is encoded where audio properties (sample rate, number of channels, or bit depth) change at some point in the stream, this should be dealt with by finishing the current Matroska segment and starting a new one with the new properties.

## ISO Base Media File Format (MP4) mapping

The full encapsulation definition of FLAC audio in MP4 files was deemed too extensive to include in this document. A definition document can be found at [@FLAC-in-MP4-specification]. The definition document is summarized here.

<reference anchor="FLAC-in-MP4-specification" target=" https://github.com/xiph/flac/blob/master/doc/isoflac.txt">
    <front>
        <title>Encapsulation of FLAC in ISO Base Media File Format</title>
        <author initials="C" surname="Montgomery" fullname="Christopher Montgomery" />
        <date month="07" year="2022"/>
    </front>
    <refcontent>commit 78d85dd</refcontent>
</reference>

The sample entry code is 'fLaC'. The channelcount and samplesize fields in the sample entry follow the values found in the FLAC stream. The samplerate field can be different, because FLAC can carry audio with much higher sample rates than can be coded for in the sample entry. When possible, the samplerate field should contain the sample rate as found in the FLAC stream, shifted left by 16 bits to get the 16.16 fixed point representation of the samplerate field. When the FLAC stream contains a sample rate higher than can be coded, the samplerate field contains the greatest expressible regular division of the sample rate, e.g., 48000 for sample rates of 96 kHz and 192 kHz or 44100 for a sample rate of 88200 Hz. When the FLAC stream contains audio with an unusual sample rate that has no regular division, the maximum value of 65535.0 Hz is used. As FLAC streams with a high sample rate are common, a parser or decoder MUST read the value from the FLAC streaminfo metadata block or a frame header to determine the actual sample rate. The sample entry contains one 'FLAC specific box' with code 'dfLa'.

The FLAC specific box extends FullBox, with version number 0 and all flags set to 0, and contains all FLAC data before the first audio frame but `fLaC` ASCII signature (i.e., all metadata blocks).

If an audio stream is encoded where audio properties (sample rate, number of channels or bit depth) change at some point in the stream, this MUST be dealt with in a MP4 generic manner, e.g., with several `stsd` atoms and different sample-description-index values in the `stsc` atom.

Each FLAC frame is a single sample in the context of MP4 files.

# Implementation status

This section records the status of known implementations of the FLAC format, and is based on a proposal described in [@?RFC7942]. Please note that the listing of any individual implementation here does not imply endorsement by the IETF. Furthermore, no effort has been spent to verify the information presented here that was supplied by IETF contributors. This is not intended as, and must not be construed to be, a catalog of available implementations or their features.  Readers are advised to note that other implementations may exist.

A reference encoder and decoder implementation of the FLAC format exists, known as libFLAC, maintained by Xiph.Org. It can be found at https://xiph.org/flac/ Note that while all libFLAC components are licensed under 3-clause BSD, the flac and metaflac command line tools often supplied together with libFLAC are licensed under GPL.

Another completely independent implementation of both encoder and decoder of the FLAC format is available in libavcodec, maintained by FFmpeg, licensed under LGPL 2.1 or later. It can be found at https://ffmpeg.org/

A list of other implementations and an overview of which parts of the format they implement can be found at [@FLAC-wiki-implementations].

<reference anchor="FLAC-wiki-implementations" target="https://github.com/ietf-wg-cellar/flac-specification/wiki/Implementations">
    <front>
        <title>FLAC specification wiki: Implementations</title>
        <author/>
    </front>
</reference>

# Security Considerations

Like any other codec (such as [@?RFC6716]), FLAC should not be used with insecure ciphers or cipher modes that are vulnerable to known plaintext attacks. Some of the header bits as well as the padding are easily predictable.

Implementations of the FLAC codec need to take appropriate security considerations into account, as outlined in [@?RFC4732]. It is extremely important for the decoder to be robust against malformed payloads. Payloads that do not conform to this specification **MUST NOT** cause the decoder to overrun its allocated memory or take an excessive amount of resources to decode. An overrun in allocated memory could lead to arbitrary code execution by an attacker. The same applies to the encoder, even though problems with encoders are typically rarer. Malformed audio streams **MUST NOT** cause the encoder to misbehave because this would allow an attacker to attack transcoding gateways.

As with all compression algorithms, both encoding and decoding can produce an output much larger than the input. For decoding, the most extreme possible case of this is a frame with eight constant subframes of block size 65535 and coding for 32-bit PCM. This frame is only 49 bytes in size, but codes for more than 2 megabytes of uncompressed PCM data. For encoding, it is possible to have an even larger size increase, although such behavior is generally considered faulty. This happens if the encoder chooses a rice parameter that does not fit with the residual that has to be encoded. In such a case, very long unary coded symbols can appear, in the most extreme case, more than 4 gigabytes per sample. Decoder and encoder implementors are advised to take precautions to prevent excessive resource utilization in such cases.

Where metadata is handled, implementors are advised to either thoroughly test the handling of extreme cases or impose reasonable limits beyond the limits of this specification document. For example, a single Vorbis comment metadata block can contain millions of valid fields. It is unlikely such a limit is ever reached except in a potentially malicious file. Likewise, the media type and description of a picture metadata block can be millions of characters long, despite there being no reasonable use of such contents. One possible use case for very long character strings is in lyrics, which can be stored in Vorbis comment metadata block fields.

Various kinds of metadata blocks contain length fields or field counts. While reading a block following these lengths or counts, a decoder MUST make sure higher-level lengths or counts (most importantly, the length field of the metadata block itself) are not exceeded. As some of these length fields code string lengths, memory for which must be allocated, parsers SHOULD first verify that a block is valid before allocating memory based on its contents, except when explicitly instructed to salvage data from a malformed file.

Metadata blocks can also contain references, e.g., the picture metadata block can contain a URI. Applications MUST obtain explicit user approval to retrieve resources via remote protocols and to retrieve local resources not located in the same directory as the FLAC file being processed.

Seeking in a FLAC stream that is not in a container relies on the coded number in frame headers and optionally a seektable metadata block. Parsers MUST employ thorough checks on whether a found coded number or seekpoint is at all possible. Without these checks, seeking might get stuck in an infinite loop when numbers in frames are non-consecutive or otherwise not valid, which could be used in denial of service attacks.

Implementors are advised to employ fuzz testing combined with different sanitizers on FLAC decoders to find security problems. Ignoring the results of CRC checks improves the efficiency of decoder fuzz testing.

See [@FLAC-decoder-testbench] for a non-exhaustive list of FLAC files with extreme configurations that lead to crashes or reboots on some known implementations. Besides providing a starting point for security testing, this set of files can also be used to test conformance with this specification.

<reference anchor="FLAC-decoder-testbench" target="https://github.com/ietf-wg-cellar/flac-test-files">
    <front>
        <title>FLAC decoder testbench</title>
        <author/>
        <date month="08" year="2023"/>
    </front>
    <refcontent>commit aa7b0c6</refcontent>
</reference>

FLAC files may contain executable code, although the FLAC format is not designed for it and it is uncommon. One use case where FLAC is occasionally used to store executable code is when compressing images of mixed mode CDs, which contain both audio and non-audio data, of which the non-audio portion can contain executable code.

# IANA Considerations

In accordance with the procedures set forth in [@?RFC6838], this document registers one new media type, "audio/flac", as defined in the following section.

## Media type registration

The following information serves as the registration form for the "audio/flac" media type. This media type is applicable for FLAC audio that is not packaged in a container as described in [section container mappings](#container-mappings). FLAC audio packaged in such a container will take on the media type of that container, for example, audio/ogg when packaged in an Ogg container, or video/mp4 when packaged in an MP4 container alongside a video track.

```
Type name: audio

Subtype name: flac

Required parameters: N/A

Optional parameters: N/A

Encoding considerations: as per THISRFC

Security considerations: see the security considerations in section
12 of THISRFC

Interoperability considerations: see the descriptions of past format
changes in Appendix B of THISRFC

Published specification: THISRFC

Applications that use this media type: ffmpeg, apache, firefox

Fragment identifier considerations: none

Additional information:

  Deprecated alias names for this type: audio/x-flac

  Magic number(s): fLaC

  File extension(s): flac

  Macintosh file type code(s): none

  Uniform Type Identifier: org.xiph.flac conforms to public.audio

  Windows Clipboard Format Name: audio/flac

Person & email address to contact for further information:
IETF CELLAR WG cellar@ietf.org

Intended usage: COMMON

Restrictions on usage: N/A

Author: IETF CELLAR WG

Change controller: Internet Engineering Task Force
(mailto:iesg@ietf.org)

Provisional registration? (standards tree only): NO
```

# Acknowledgments

FLAC owes much to the many people who have advanced the audio compression field so freely. For instance:

- A. J. Robinson for his work on Shorten; his paper (see [@robinson-tr156]) is a good starting point on some of the basic methods used by FLAC. FLAC trivially extends and improves the fixed predictors, LPC coefficient quantization, and Rice coding used in Shorten.
- S. W. Golomb and Robert F. Rice; their universal codes are used by FLAC's entropy coder, see [@Rice].
- N. Levinson and J. Durbin; the FLAC reference encoder (see [section implementation status](#implementation-status)) uses an algorithm developed and refined by them for determining the LPC coefficients from the autocorrelation coefficients, see [@Durbin].
- And of course, Claude Shannon, see [@Shannon].

<reference anchor="Rice" target="https://ieeexplore.ieee.org/document/1090789">
    <front>
        <title>Adaptive Variable-Length Coding for Efficient Compression of Spacecraft Television Data</title>
        <author initials="RF" surname="Rice" fullname="Robert Rice">
            <organization>Jet Propulsion Laboratory, California Institute of Technology, Pasadena, CA, USA</organization>
        </author>
        <author initials="JR" surname="Plaunt">
            <organization>Jet Propulsion Laboratory, California Institute of Technology, Pasadena, CA, USA</organization>
        </author>
        <date month="12" year="1971"/>
    </front>
    <seriesInfo name="DOI" value="10.1109/TCOM.1971.1090789"/>
</reference>

<reference anchor="Durbin" target="https://www.jstor.org/stable/1401322">
    <front>
        <title>The Fitting of Time-Series Models </title>
        <author initials="J" surname="Durbin" fullname="James Durbin">
            <organization>University of North Carolina</organization>
            <organization>University of London</organization>
        </author>
        <date month="12" year="1959"/>
    </front>
    <seriesInfo name="DOI" value="10.2307/1401322"/>
</reference>

<reference anchor="Shannon" target="https://ieeexplore.ieee.org/document/1697831">
    <front>
        <title>Communication in the Presence of Noise</title>
        <author initials="CE" surname="Shannon" fullname="Claude Shannon">
            <organization>Bell Telephone Laboratories, Inc., Murray Hill, NJ, USA</organization>
        </author>
        <date month="01" year="1949"/>
    </front>
    <seriesInfo name="DOI" value="10.1109/JRPROC.1949.232969"/>
</reference>

The FLAC format, the FLAC reference implementation, and this document were originally developed by Josh Coalson. While many others have contributed since, this original effort is deeply appreciated.
