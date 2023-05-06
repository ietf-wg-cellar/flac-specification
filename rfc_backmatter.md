
{backmatter}

# Numerical considerations

In order to maintain lossless behavior, all arithmetic used in encoding and decoding sample values MUST be done with integer data types to eliminate the possibility of introducing rounding errors associated with floating-point arithmetic. Use of floating-point representations in analysis (e.g. finding a good predictor or Rice parameter) is not a concern, as long as the process of using the found predictor and Rice parameter to encode audio samples is implemented with only integer math.

Furthermore, the possibility of integer overflow can be eliminated by using large enough data types. Choosing a 64-bit signed data type for all arithmetic involving sample values would make sure the possibility for overflow is eliminated, but usually smaller data types are chosen for increased performance, especially in embedded devices. This section provides guidelines for choosing the right data type in each step of encoding and decoding FLAC files.

## Determining necessary data type size
To find the smallest data type size that is guaranteed not to overflow for a certain sequence of arithmetic operations, the combination of values producing the largest possible result should be considered.

If for example two 16-bit signed integers are added, the largest possible result forms if both values are the largest number that can be represented with a 16-bit signed integer. To store the result, an signed integer data type with at least 17 bits is needed. Similarly, when adding 4 of these values, 18 bits are needed, when adding 8, 19 bits are needed etc. In general, the number of bits necessary when adding numbers together is increased by the log base 2 of the number of values rounded up to the nearest integer. So, when adding 18 unknown values stored in 8 bit signed integers, we need a signed integer data type of at least 13 bits to store the result, as the log base 2 of 18 rounded up is 5.

In case of multiplication, the number of bits needed for the result is the size of the first variable plus the size of the second variable, but counting only one sign bit if working with signed data types. If for example a 16-bit signed integer is multiplied by a 16-bit signed integer, the result needs at least 31 bits to store without overflowing.

## Stereo decorrelation
When stereo decorrelation is used, the side channel will have one extra bit of bit depth, see  [section on Interchannel Decorrelation](#interchannel-decorrelation).

This means that while 16-bit signed integers have sufficient range to store samples from a fully decoded FLAC frame with a bit depth of 16 bit, the decoding of a side subframe in such a file will need a data type with at least 17 bit to store decoded subframe samples before undoing stereo decorrelation.

Most FLAC decoders store decoded (subframe) samples as 32-bit values, which is sufficient for files with bit depths up to (and including) 31 bit.

## Prediction
A prediction (which is used to calculate the residual on encoding or added to the residual to calculate the sample value on decoding) is formed by multiplying and summing preceding sample values. In order to eliminate the possibility of integer overflow, the combination of preceding sample values and predictor coefficients producing the largest possible value should be considered.

To determine the size of the data type needed to calculate either a residual sample (on encoding) or an audio sample value (on decoding) in a fixed predictor subframe, the maximal possible value for these is calculated as described in the [section determining necessary data type size](#determining-necessary-data-type-size) in the following table. For example: if a frame codes for 16-bit audio and has some form of stereo decorrelation, the subframe coding for the side channel would need 16+1+3 bits if a third order fixed predictor is used.

Order | Calculation of residual                              | Sample values summed | Extra bits
:-----|:-----------------------------------------------------|:---------------------|:-----------
0     | a(n)                                                 | 1                    | 0
1     | a(n) - a(n-1)                                        | 2                    | 1
2     | a(n) - 2 * a(n-1) + a(n-2)                           | 4                    | 2
3     | a(n) - 3 * a(n-1) + 3 * a(n-2) - a(n-3)              | 8                    | 3
4     | a(n) - 4 * a(n-1) + 6 * a(n-2) - 4 * a(n-3) + a(n-4) | 16                   | 4

Where

- n is the number of the sample being predicted
- a(n) is the sample being predicted
- a(n-1) is the sample before the one being predicted, a(n-2) is the sample before that etc.

For subframes with a linear predictor, calculation is a little more complicated. Each prediction is a sum of several multiplications. Each of these multiply a sample value with a predictor coefficient. The extra bits needed can be calculated by adding the predictor coefficient precision (in bits) to the bit depth of the audio samples. As both are signed numbers and only one 'sign bit' is necessary, 1 bit can be subtracted. To account for the summing of these multiplications, the log base 2 of the predictor order rounded up is added.

For example, if the sample bit depth of the source is 24, the current subframe encodes a side channel (see the [section on interchannel decorrelation](#interchannel-decorrelation)), the predictor order is 12 and the predictor coefficient precision is 15 bits, the minimum required size of the used signed integer data type is at least (24 + 1) + (15 - 1) + ceil(log2(12)) = 43 bits. As another example, with a side-channel subframe bit depth of 16, a predictor order of 8 and a predictor coefficient precision of 12 bits, the minimum required size of the used signed integer data type is (16 + 1) + (12 - 1)  + ceil(log2(8)) = 31 bits.

## Residual

As stated in the section [coded residual](#coded-residual), an encoder must make sure residual samples are representable by a 32-bit integer, signed two's complement, excluding the most negative value. Continuing as in the previous section, it is possible to calculate when residual samples already implicitly fit and when an additional check is needed. This implicit fit is achieved when residuals would fit a theoretical 31-bit signed int, as that satisfies both mentioned criteria.

For the residual of a fixed predictor, the maximum size of a residual was already calculated in the previous section. However, for a linear predictor, the prediction is shifted right by a certain amount. The number of bits needed for the residual is the number of bits calculated in the previous section, reduced by the prediction right shift, increased by one bit to account for the subtraction of the prediction from the current sample on encoding.

Taking the last example of the previous section, where 31 bits were needed for the prediction, the required data type size for the residual samples in case of a right shift of 10 bits would be 31 - 10 + 1 = 22 bits, which means it is not necessary to check whether the residuals fit a 32-bit signed integer.

As another example, when encoding 32-bit PCM with fixed predictors, all predictor orders must be checked. While the 0-order fixed predictor is guaranteed to have residuals that fit a 32-bit signed int, it might produce a residual being the most negative representable value of that 32-bit signed int.

Note that on decoding, while the residual samples are limited to the aforementioned range, the predictions are not. This means that while the decoding of the residual samples can happen fully in 32-bit signed integers, decoders must be sure to execute the addition of each residual sample to its accompanying prediction with a wide enough signed integer data type like on encoding.

## Rice coding
When folding (i.e. zig-zag encoding) the residual sample values, no extra bits are needed when the absolute value of each residual sample is first stored in an unsigned data type of the size of the last step, then doubled and then has one subtracted depending on whether the residual sample was positive or negative. Many implementations however choose to require one extra bit of data type size so zig-zag encoding can happen in one step and without a cast instead of the procedure described in the previous sentence.

# Past format changes

This informational appendix documents what changes were made to the FLAC format over the years. This information might be of use when encountering FLAC files that were made with software following the format as it was before the changes documented in this appendix.

The FLAC format was first specified in December 2000 and the bitstream format was considered frozen with the release of FLAC (the reference encoder/decoder) 1.0 in July 2001. Only changes made since this first stable release are considered in this appendix. Changes made to the FLAC streamble subset definition (see [section streamable subset](#streamable-subset)) are not considered.

## Addition of block size strategy flag

Perhaps the largest backwards incompatible change to the specification was published in July 2007. Before this change, variable block size streams were not explicitly marked as such by a flag bit in the frame header. A decoder had two ways to detect a variable block size stream, either by comparing the minimum and maximum block size in the STREAMINFO metadata block (which are equal in case of a fixed block size stream), or, if a decoder did not receive a STREAMINFO metadata block, by detecting a change of block size during a stream, which could in theory not happen at all. As the meaning of the coded number in the frame header depends on whether or not a stream is variable block size, this presented a problem: the meaning of the coded number could not be reliably determined. To fix this problem, one of the reserved bits was changed to be used as a block size strategy flag. [See also the section frame header](#frame-header).

Along with the addition of a new flag, the meaning of the [block size bits](#block-size-bits) was subtly changed. Initially, block size bits 0b0001-0b0101 and 0b1000-0b1111 could only be used for fixed block size streams, while 0b0110 and 0b0111 could be used for both fixed block size and variable block size streams. With the change these restrictions were lifted and 0b0001-0b1111 are now used for both variable block size and fixed block size streams.

## Restriction of encoded residual samples

Another change to the specification was deemed necessary during standardization by the CELLAR working group of the IETF. As specified in [section coded residual](#coded-residual) a limit is imposed on residual samples. This limit was not specified prior to the IETF standardization effort. However, as far as was known to the working group, no FLAC encoder at that time produced FLAC files containing residual samples exceeding this limit. This is mostly because it is very unlikely to encounter residual samples exceeding this limit when encoding 24-bit PCM, and encoding of PCM with higher bit depths was not yet implemented in any known encoder. In fact, these FLAC encoders would produce corrupt files upon being triggered to produce such residual samples and it is unlikely any non-experimental encoder would ever do so, even when presented with crafted material. Therefore, it was not expected existing implementation would be rendered non-compliant by this change.

## Addition of 5-bit Rice parameter

One significant addition to the format was the residual coding method using a 5-bit Rice parameter. Prior to publication of this addition in July 2007, there was only one residual coding method specified, a partitioned Rice code with a 4-bit Rice parameter. The range offered by this proved too small when encoding 24-bit PCM, therefore a second residual coding method was specified identical to the first but with a 5-bit Rice parameter.

## Restriction of LPC shift to non-negative values

As stated in section [linear predictor subframe](#linear-predictor-subframe), the predictor right shift is a number signed two's complement, which MUST NOT be negative. This is because right shifting a number by a negative amount is undefined behavior in the C programming language standard. The intended behavior was that a positive number would be a right shift and a negative number a left shift. The FLAC reference encoder was changed in 2007 to not generate LPC subframes with a negative predictor right shift, as it turned out that the use of such subframes would only very rarely provide any benefit and the decoders that were already widely in use at that point were not able to handle such subframes.

# Interoperability considerations

As documented in appendix [past format changes](#past-format-changes), there have been some changes and additions to the FLAC format. Additionally, implementation of certain features of the FLAC format took many years, meaning early decoder implementations could not be tested against files with these features. Finally, many lower-quality FLAC decoders only implement enough features required for playback of the most common FLAC files.

This appendix provides some considerations for encoder implementations aiming to create highly compatible files. As this topic is one that might change after this document is finished, consult [this web page](https://github.com/ietf-wg-cellar/flac-specification/wiki/Interoperability-considerations) for more up-to-date information.

## Features outside of streamable subset

As described in section [streamable subset](#streamable-subset), FLAC specifies a subset of its capabilities as the FLAC streamable subset. Certain decoders may choose to only decode FLAC files conforming to the limitations imposed by the streamable subset. Therefore, maximum compatibility with decoders is achieved when the limitations of the FLAC streamable subset are followed when creating FLAC files.

## Variable block size

Because it is often difficult to find the optimal arrangement of block sizes for maximum compression, most encoders choose to create files with a fixed block size. Because of this many decoder implementations receive minimal use when handling variable block size streams, and this can reveal bugs, or reveal that implementations do not decode them at all. Furthermore, as is explained in [section addition of block size strategy flag](#addition-of-block-size-strategy-flag), there have been some changes to the way variable block size streams were encoded. Because of this, maximum compatibility with decoders is achieved when FLAC files are created using fixed block size streams.

## 5-bit Rice parameter {#rice-parameter-5-bit}

As the addition of the 5-bit Rice parameter as described in [section addition of 5-bit Rice parameter](#addition-of-5-bit-rice-parameter) was quite a few years after the FLAC format was first introduced, some early decoders might not be able to decode files containing such Rice parameters. The introduction of this was specifically aimed at improving compression of 24-bit PCM audio and compression of 16-bit PCM audio only rarely benefits from using a 5-bit Rice parameters. Therefore, maximum compatibility with decoders is achieved when FLAC files containing audio with a bit depth of 16 bits or lower are created without any use of 5-bit Rice parameters.

## Rice escape code

Escapes Rice partitions are only seldom used as it turned out their use provides only very small compression improvement. As many encoders therefore do not use these by default or are not capable of producing them at all, it is likely many decoder implementation are not able to decode them correctly. Therefore, maximum compatibility with decoders is achieved when FLAC files are created without any use of escaped Rice partitions.

## Uncommon block size

For unknown reasons some decoders have chosen to support only common block sizes except for the last block. Therefore, maximum compatibility with decoders is achieved when creating FLAC files using common block sizes as listed in section [block size bits](#block-size-bits) for all but the last block.

## Uncommon bit depth

Most audio is stored in bit depths that are a whole number of bytes, e.g. 8, 16 or 24 bit. There is however audio with different bit depths. A few examples:

- DVD-Audio has the possibility to store 20 bit PCM audio
- DAT and DV can store 12 bit PCM audio
- NICAM-728 samples at 14 bit, which is companded to 10 bit
- 8-bit µ-law can be losslessly converted to 14 bit (Linear) PCM
- 8-bit A-law can be losslessly converted to 13 bit (Linear) PCM

The FLAC format can contain these bit depths directly, but because they are uncommon, some decoders are not able to process the resulting files correctly. It is possible to store these formats in a FLAC file with a more common bit depth without sacrificing compression by padding each sample with zero bits to a bit depth that is a whole byte. The FLAC format can efficiently compress these wasted bits. This transformation leaves no ambiguity in how it can be reversed and is thus lossless. See [section wasted bits per sample](#wasted-bits-per-sample) for details.

Therefore, maximum compatibility with decoders is achieved when FLAC files are created by padding samples of such audio with zero bits to the bit depth that is the next whole number of bytes.

Besides audio with a 'non-whole byte' bit depth, some decoder implementations have chosen to only accept FLAC files coding for PCM audio with a bit depth of 16 bit. Many implementations support bit depths up to 24 bit but no higher. Consult [this web page](https://github.com/ietf-wg-cellar/flac-specification/wiki/Interoperability-considerations) for more up-to-date information.

## Multi-channel audio and uncommon sample rates

Many FLAC audio players are unable to render multi-channel audio or audio with an uncommon sample rate. While this is not a concern specific to the FLAC format, it is of note when requiring maximum compatibility with decoders. Unlike the previously mentioned interoperability considerations, this is one that cannot be satisfied without sacrificing the lossless nature of the FLAC format.

From a non-exhaustive inquiry, it seems that a non-negligible amount of players, among those especially hardware players, does not support audio with 3 or more channels or sample rates other than those considered common, see [section sample rate bits](#sample-rate-bits).

For those players that do support and are able to render multi-channel audio, many do not parse and use the WAVEFORMATEXTENSIBLE\_CHANNEL\_MASK tag (see [section channel mask](#channel-mask)). This too is a interoperability consideration that cannot be satisfied without sacrificing the lossless nature of the FLAC format.

# Examples

This informational appendix contains short example FLAC files which are decoded step by step. These examples provide a more engaging way to understand the FLAC format than the formal specification. The text explaining these examples assumes the reader has at least cursorily read the specification and that the reader refers to the specification for explanation of the terminology used. These examples mostly focus on the lay-out of several metadata blocks and subframe types and the implications of certain aspects (for example wasted bits and stereo decorrelation) on this lay-out.

The examples feature files generated by various FLAC encoders. These are presented in hexadecimal or binary format, followed by tables and text referring to various features by their starting bit positions in these representations. Each starting position (shortened to 'start' in the tables) is a hexadecimal byte position and a start bit within that byte, separated by a plus sign. Counts for these start at zero. For example, a feature starting at the 3rd bit of the 17th byte is referred to as starting at 0x10+2. The files that are explored in these examples can be found at https://github.com/ietf-wg-cellar/flac-specification.

All data in this appendix has been thoroughly verified. However, as this appendix is informational, if any information here conflicts with statements in the formal specification, the latter takes precedence.

## Decoding example 1

This very short example FLAC file codes for PCM audio that has two channels, each containing 1 sample. The focus of this example is on the essential parts of a FLAC file.

### Example file 1 in hexadecimal representation

```
00000000: 664c 6143 8000 0022 1000 1000  fLaC..."....
0000000c: 0000 0f00 000f 0ac4 42f0 0000  ........B...
00000018: 0001 3e84 b418 07dc 6903 0758  ..>.....i..X
00000024: 6a3d ad1a 2e0f fff8 6918 0000  j=......i...
00000030: bf03 58fd 0312 8baa 9a         ..X......
```

### Example file 1 in binary representation

```
00000000: 01100110 01001100 01100001 01000011  fLaC
00000004: 10000000 00000000 00000000 00100010  ..."
00000008: 00010000 00000000 00010000 00000000  ....
0000000c: 00000000 00000000 00001111 00000000  ....
00000010: 00000000 00001111 00001010 11000100  ....
00000014: 01000010 11110000 00000000 00000000  B...
00000018: 00000000 00000001 00111110 10000100  ..>.
0000001c: 10110100 00011000 00000111 11011100  ....
00000020: 01101001 00000011 00000111 01011000  i..X
00000024: 01101010 00111101 10101101 00011010  j=..
00000028: 00101110 00001111 11111111 11111000  ....
0000002c: 01101001 00011000 00000000 00000000  i...
00000030: 10111111 00000011 01011000 11111101  ..X.
00000034: 00000011 00010010 10001011 10101010  ....
00000038: 10011010
```

### Signature and streaminfo

The first 4 bytes of the file contain the fLaC file signature. Directly following it is a metadata block. The signature and the first metadata block header are broken down in the following table

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x00+0 | 4 byte | 0x664C6143      | fLaC
0x04+0 | 1 bit  | 0b1             | Last metadata block
0x04+1 | 7 bit  | 0b0000000       | Streaminfo metadata block
0x05+0 | 3 byte | 0x000022        | Length 34 byte

As the header indicates that this is the last metadata block, the position of the first audio frame can now be calculated as the position of the first byte after the metadata block header + the length of the block, i.e. 8+34 = 42 or 0x2a. As can be seen 0x2a indeed contains the frame sync code for fixed block size streams, 0xfff8.

The streaminfo metadata block contents are broken down in the following table

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x08+0 | 2 byte  | 0x1000             | Min. block size 4096
0x0a+0 | 2 byte  | 0x1000             | Max. block size 4096
0x0c+0 | 3 byte  | 0x00000f           | Min. frame size 15 byte
0x0f+0 | 3 byte  | 0x00000f           | Max. frame size 15 byte
0x12+0 | 20 bit  | 0x0ac4, 0b0100     | Sample rate 44100 hertz
0x14+4 | 3 bit   | 0b001              | 2 channels
0x14+7 | 5 bit   | 0b01111            | Sample bit depth 16
0x15+4 | 36 bit  | 0b0000, 0x00000001 | Total no. of samples 1
0x1a   | 16 byte | (...)              | MD5 signature

The minimum and maximum block size are both 4096. This was apparently the block size the encoder planned to use, but as only 1 interchannel sample was provided, no frames with 4096 samples are actually present in this file.

Note that anywhere a number of samples is mentioned (block size, total number of samples, sample rate), interchannel samples are meant.

The MD5 sum (starting at 0x1a) is 0x3e84 b418 07dc 6903 0758 6a3d ad1a 2e0f. This will be validated after decoding the samples.

### Audio frames

The frame header starts at position 0x2a and is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x2a+0 | 15 bit | 0xff, 0b1111100 | frame sync
0x2b+7 | 1 bit  | 0b0             | block size strategy
0x2c+0 | 4 bit  | 0b0110          | 8-bit block size further down
0x2c+4 | 4 bit  | 0b1001          | sample rate 44.1kHz
0x2d+0 | 4 bit  | 0b0001          | stereo, no decorrelation
0x2d+4 | 3 bit  | 0b100           | bit depth 16 bit
0x2d+7 | 1 bit  | 0b0             | mandatory 0 bit
0x2e+0 | 1 byte | 0x00            | frame number 0
0x2f+0 | 1 byte | 0x00            | block size 1
0x30+0 | 1 byte | 0xbf            | frame header CRC

As the stream is a fixed block size stream, the number at 0x2e contains a frame number. As the value is smaller than 128, only 1 byte is used for the encoding.

At byte 0x31 the subframe header of the first subframe starts, it is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x31+0 | 1 bit  | 0b0             | mandatory 0 bit
0x31+1 | 6 bit  | 0b000001        | verbatim subframe
0x31+7 | 1 bit  | 0b1             | wasted bits used
0x32+0 | 2 bit  | 0b01            | 2 wasted bits used
0x32+2 | 14 bit | 0b011000, 0xfd  | 14-bit unencoded sample


As the wasted bits flag is 1 in this subframe, an unary coded number follows. Starting at 0x32, we see 0b01, which unary codes for 1, meaning this subframe uses 2 wasted bits.

As this is a verbatim subframe, the subframe only contains unencoded sample values. With a block size of 1, it contains only a single sample. The bit depth of the audio is 16 bit, but as the subframe header signals the use of 2 wasted bits, only 14 bits are stored. As no stereo decorrelation is used, a bit depth increase for the side channel is not applicable. So, the next 14 bit (starting at position 0x32+2) contain the unencoded sample coded big-endian, signed two's complement. The value reads 0b011000 11111101, or 6397. This value needs to be shifted left by 2 bits, to account for the wasted bits. The value is then 0b011000 11111101 00, or 25588.

The second subframe starts at 0x34, it is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x34+0 | 1 bit  | 0b0             | mandatory 0 bit
0x34+1 | 6 bit  | 0b000001        | verbatim subframe
0x34+7 | 1 bit  | 0b1             | wasted bits used
0x35+0 | 4 bit  | 0b0001          | 4 wasted bits used
0x35+4 | 12 bit | 0b0010, 0x8b    | 12-bit unencoded sample

Here the wasted bits flag is also one, but the unary coded number that follows it is 4 bit long, indicating the use of 4 wasted bits. This means the sample is stored in 12 bits. The sample value is 0b0010 10001011, or 651. This value now has to be shifted left by 4 bits, i.e. 0b0010 10001011 0000 or 10416.

At this point, we would do stereo decorrelation if that was applicable.

As the last subframe ends byte-aligned, no padding bits follow it. The next 2 bytes, starting at 0x38, contain the frame CRC. As this is the only frame in the file, the file ends with the CRC.

To validate the MD5, we line up the samples interleaved, byte-aligned, little endian, signed two's complement. The first sample, the value of which was 25588 translates to 0xf463, the second sample had a value of 10416 which translates to 0xb028. When MD5 summing 0xf463b028, we get the MD5 sum found in the header, so decoding was lossless.

## Decoding example 2

This FLAC file is larger than the first example, but still contains very little audio. The focus of this example is on decoding a subframe with a fixed predictor and a coded residual, but it also contains a very short seektable, Vorbis comment and padding metadata block.

### Example file 2 in hexadecimal representation

```
00000000: 664c 6143 0000 0022 0010 0010  fLaC..."....
0000000c: 0000 1700 0044 0ac4 42f0 0000  .....D..B...
00000018: 0013 d5b0 5649 75e9 8b8d 8b93  ....VIu.....
00000024: 0422 757b 8103 0300 0012 0000  ."u{........
00000030: 0000 0000 0000 0000 0000 0000  ............
0000003c: 0000 0010 0400 003a 2000 0000  .......: ...
00000048: 7265 6665 7265 6e63 6520 6c69  reference li
00000054: 6246 4c41 4320 312e 332e 3320  bFLAC 1.3.3
00000060: 3230 3139 3038 3034 0100 0000  20190804....
0000006c: 0e00 0000 5449 544c 453d d7a9  ....TITLE=..
00000078: d79c d795 d79d 8100 0006 0000  ............
00000084: 0000 0000 fff8 6998 000f 9912  ......i.....
00000090: 0867 0162 3d14 4299 8f5d f70d  .g.b=.B..]..
0000009c: 6fe0 0c17 caeb 2100 0ee7 a77a  o.....!....z
000000a8: 24a1 590c 1217 b603 097b 784f  $.Y......{xO
000000b4: aa9a 33d2 85e0 70ad 5b1b 4851  ..3...p.[.HQ
000000c0: b401 0d99 d2cd 1a68 f1e6 b810  .......h....
000000cc: fff8 6918 0102 a402 c382 c40b  ..i.........
000000d8: c14a 03ee 48dd 03b6 7c13 30    .J..H...|.0
```

### Example file 2 in binary representation (only audio frames)

```
00000088: 11111111 11111000 01101001 10011000  ..i.
0000008c: 00000000 00001111 10011001 00010010  ....
00000090: 00001000 01100111 00000001 01100010  .g.b
00000094: 00111101 00010100 01000010 10011001  =.B.
00000098: 10001111 01011101 11110111 00001101  .]..
0000009c: 01101111 11100000 00001100 00010111  o...
000000a0: 11001010 11101011 00100001 00000000  ..!.
000000a4: 00001110 11100111 10100111 01111010  ...z
000000a8: 00100100 10100001 01011001 00001100  $.Y.
000000ac: 00010010 00010111 10110110 00000011  ....
000000b0: 00001001 01111011 01111000 01001111  .{xO
000000b4: 10101010 10011010 00110011 11010010  ..3.
000000b8: 10000101 11100000 01110000 10101101  ..p.
000000bc: 01011011 00011011 01001000 01010001  [.HQ
000000c0: 10110100 00000001 00001101 10011001  ....
000000c4: 11010010 11001101 00011010 01101000  ...h
000000c8: 11110001 11100110 10111000 00010000  ....
000000cc: 11111111 11111000 01101001 00011000  ..i.
000000d0: 00000001 00000010 10100100 00000010  ....
000000d4: 11000011 10000010 11000100 00001011  ....
000000d8: 11000001 01001010 00000011 11101110  .J..
000000dc: 01001000 11011101 00000011 10110110  H...
000000e0: 01111100 00010011 00110000           |.0
```

### Streaminfo metadata block

Most of the streaminfo block, including its header, is the same as in example 1, so only parts that are different are listed in the following table

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x04+0 | 1 bit   | 0b0                | Not the last metadata block
0x08+0 | 2 byte  | 0x0010             | Min. block size 16
0x0a+0 | 2 byte  | 0x0010             | Max. block size 16
0x0c+0 | 3 byte  | 0x000017           | Min. frame size 23 byte
0x0f+0 | 3 byte  | 0x000044           | Max. frame size 68 byte
0x15+4 | 36 bit  | 0b0000, 0x00000013 | Total no. of samples 19
0x1a   | 16 byte | (...)              | MD5 signature

This time, the minimum and maximum block sizes are reflected in the file: there is one block of 16 samples, the last block (which has 3 samples) is not considered for the minimum block size. The MD5 signature is 0xd5b0 5649 75e9 8b8d 8b93 0422 757b 8103, this will be verified at the end of this example.

### Seektable

The seektable metadata block only holds one entry. It is not really useful here, as it points to the first frame, but it is enough for this example. The seektable metadata block is broken down in the following table.

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x2a+0 | 1 bit   | 0b0                | Not the last metadata block
0x2a+1 | 7 bit   | 0b0000011          | Seektable metadata block
0x2b+0 | 3 byte  | 0x000012           | Length 18 byte
0x2e+0 | 8 byte  | 0x0000000000000000 | Seekpoint to sample 0
0x36+0 | 8 byte  | 0x0000000000000000 | Seekpoint to offset 0
0x3e+0 | 2 byte  | 0x0010             | Seekpoint to block size 16

### Vorbis comment

The Vorbis comment metadata block contains the vendor string and a single comment. It is broken down in the following table.

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x40+0 | 1 bit   | 0b0                | Not the last metadata block
0x40+1 | 7 bit   | 0b0000100          | Vorbis comment metadata block
0x41+0 | 3 byte  | 0x00003a           | Length 58 byte
0x44+0 | 4 byte  | 0x20000000         | Vendor string length 32 byte
0x48+0 | 32 byte | (...)              | Vendor string
0x68+0 | 4 byte  | 0x01000000         | Number of fields 1
0x6c+0 | 4 byte  | 0x0e000000         | Field length 14 byte
0x70+0 | 14 byte | (...)              | Field contents

The vendor string is reference libFLAC 1.3.3 20190804, the field contents of the only field is TITLE=שלום. The Vorbis comment field is 14 bytes but only 10 characters in size, because it contains four 2-byte characters.

### Padding

The last metadata block is a (very short) padding block.

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x7e+0 | 1 bit   | 0b1                | Last metadata block
0x7e+1 | 7 bit   | 0b0000001          | Padding metadata block
0x7f+0 | 3 byte  | 0x000006           | Length 6 byte
0x82+0 | 6 byte  | 0x000000000000     | Padding bytes

### First audio frame

The frame header starts at position 0x88 and is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x88+0 | 15 bit | 0xff, 0b1111100 | frame sync
0x89+7 | 1 bit  | 0b0             | block size strategy
0x8a+0 | 4 bit  | 0b0110          | 8-bit block size further down
0x8a+4 | 4 bit  | 0b1001          | sample rate 44.1kHz
0x8b+0 | 4 bit  | 0b1001          | right-side stereo
0x8b+4 | 3 bit  | 0b100           | bit depth 16 bit
0x8b+7 | 1 bit  | 0b0             | mandatory 0 bit
0x8c+0 | 1 byte | 0x00            | frame number 0
0x8d+0 | 1 byte | 0x0f            | block size 16
0x8e+0 | 1 byte | 0x99            | frame header CRC

The first subframe starts at byte 0x8f, it is broken down in the following table excluding the coded residual. As this subframe codes for a side channel, the bit depth is increased by 1 bit from 16 bit to 17 bit. This is most clearly present in the unencoded warm-up sample.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x8f+0 | 1 bit  | 0b0             | mandatory 0 bit
0x8f+1 | 6 bit  | 0b001001        | fixed subframe, 1st order
0x8f+7 | 1 bit  | 0b0             | no wasted bits used
0x90+0 | 17 bit | 0x0867, 0b0     | unencoded warm-up sample

The coded residual is broken down in the following table. All quotients are unary coded, all remainders are stored unencoded with a number of bits specified by the Rice parameter.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x92+1 | 2 bit  | 0b00            | Rice code with 4-bit parameter
0x92+3 | 4 bit  | 0b0000          | Partition order 0
0x92+7 | 4 bit  | 0b1011          | Rice parameter 11
0x93+3 | 4 bit  | 0b0001          | Quotient 3
0x93+7 | 11 bit | 0b00011110100   | Remainder 244
0x95+2 | 2 bit  | 0b01            | Quotient 1
0x95+4 | 11 bit | 0b01000100001   | Remainder 545
0x96+7 | 2 bit  | 0b01            | Quotient 1
0x97+1 | 11 bit | 0b00110011000   | Remainder 408
0x98+4 | 1 bit  | 0b1             | Quotient 0
0x98+5 | 11 bit | 0b11101011101   | Remainder 1885
0x9a+0 | 1 bit  | 0b1             | Quotient 0
0x9a+1 | 11 bit | 0b11101110000   | Remainder 1904
0x9b+4 | 1 bit  | 0b1             | Quotient 0
0x9b+5 | 11 bit | 0b10101101111   | Remainder 1391
0x9d+0 | 1 bit  | 0b1             | Quotient 0
0x9d+1 | 11 bit | 0b11000000000   | Remainder 1536
0x9e+4 | 1 bit  | 0b1             | Quotient 0
0x9e+5 | 11 bit | 0b10000010111   | Remainder 1047
0xa0+0 | 1 bit  | 0b1             | Quotient 0
0xa0+1 | 11 bit | 0b10010101110   | Remainder 1198
0xa1+4 | 1 bit  | 0b1             | Quotient 0
0xa1+5 | 11 bit | 0b01100100001   | Remainder 801
0xa3+0 | 13 bit | 0b0000000000001 | Quotient 12
0xa4+5 | 11 bit | 0b11011100111   | Remainder 1767
0xa6+0 | 1 bit  | 0b1             | Quotient 0
0xa6+1 | 11 bit | 0b01001110111   | Remainder 631
0xa7+4 | 1 bit  | 0b1             | Quotient 0
0xa7+5 | 11 bit | 0b01000100100   | Remainder 548
0xa9+0 | 1 bit  | 0b1             | Quotient 0
0xa9+1 | 11 bit | 0b01000010101   | Remainder 533
0xaa+4 | 1 bit  | 0b1             | Quotient 0
0xaa+5 | 11 bit | 0b00100001100   | Remainder 268

At this point, the decoder should know it is done decoding the coded residual, as it received 16 samples: 1 warm-up sample and 15 residual samples. Each residual sample can be calculated from the quotient and remainder, and undoing the zig-zag encoding. For example, the value of the first zig-zag encoded residual sample is 3 * 2^11 + 244 = 6388. As this is an even number, the zig-zag encoding is undone by dividing by 2, the residual sample value is 3194. This is done for all residual samples in the next table

Quotient | Remainder | Zig-zag encoded | Residual sample value
:--------|:----------|:----------------|:---------------------
3        | 244       | 6388            | 3194
1        | 545       | 2593            | -1297
1        | 408       | 2456            | 1228
0        | 1885      | 1885            | -943
0        | 1904      | 1904            | 952
0        | 1391      | 1391            | -696
0        | 1536      | 1536            | 768
0        | 1047      | 1047            | -524
0        | 1198      | 1198            | 599
0        | 801       | 801             | -401
12       | 1767      | 26343           | -13172
0        | 631       | 631             | -316
0        | 548       | 548             | 274
0        | 533       | 533             | -267
0        | 268       | 268             | 134

It can be calculated that using a Rice code is in this case more efficient than storing values unencoded. The Rice code (excluding the partition order and parameter) is 199 bits in length. The largest residual value (-13172) would need 15 bits to be stored unencoded, so storing all 15 samples with 15 bits results in a sequence with a length of 225 bits.

The next step is using the predictor and the residuals to restore the sample values. As this subframe uses a fixed predictor with order 1, this means adding the residual value to the value of the previous sample.

Residual  | Sample value
----------|:------------
(warm-up) | 4302
3194      | 7496
-1297     | 6199
1228      | 7427
-943      | 6484
952       | 7436
-696      | 6740
768       | 7508
-524      | 6984
599       | 7583
-401      | 7182
-13172    | -5990
-316      | -6306
274       | -6032
-267      | -6299
134       | -6165

With this, decoding of the first subframe is complete. Decoding of the second subframe is very similar, as it also uses a fixed predictor of order 1, so this is left as an exercise for the reader, results are in the next table. The next step is stereo decorrelation, which is done in the following table. As the stereo decorrelation is right-side, in which the actual ordering of the subframes is side-right, the samples in the right channel come directly from the second subframe, while the samples in the left channel are found by adding the values of both subframes for each sample.

Subframe 1 | Subframe 2 | Left   | Right
:----------|:-----------|:-------|:------
4302       | 6070       | 10372  | 6070
7496       | 10545      | 18041  | 10545
6199       | 8743       | 14942  | 8743
7427       | 10449      | 17876  | 10449
6484       | 9143       | 15627  | 9143
7436       | 10463      | 17899  | 10463
6740       | 9502       | 16242  | 9502
7508       | 10569      | 18077  | 10569
6984       | 9840       | 16824  | 9840
7583       | 10680      | 18263  | 10680
7182       | 10113      | 17295  | 10113
-5990      | -8428      | -14418 | -8428
-6306      | -8895      | -15201 | -8895
-6032      | -8476      | -14508 | -8476
-6299      | -8896      | -15195 | -8896
-6165      | -8653      | -14818 | -8653

As the second subframe ends byte-aligned, no padding bits follow it. Finally, the last 2 bytes of the frame contain the frame CRC.

### Second audio frame

The second audio frame is very similar to the frame decoded in the first example, but this time not 1 but 3 samples are present.

The frame header starts at position 0xcc and is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0xcc+0 | 15 bit | 0xff, 0b1111100 | frame sync
0xcd+7 | 1 bit  | 0b0             | block size strategy
0xce+0 | 4 bit  | 0b0110          | 8-bit block size further down
0xce+4 | 4 bit  | 0b1001          | sample rate 44.1kHz
0xcf+0 | 4 bit  | 0b0001          | stereo, no decorrelation
0xcf+4 | 3 bit  | 0b100           | bit depth 16 bit
0xcf+7 | 1 bit  | 0b0             | mandatory 0 bit
0xd0+0 | 1 byte | 0x01            | frame number 1
0xd1+0 | 1 byte | 0x02            | block size 3
0xd2+0 | 1 byte | 0xa4            | frame header CRC

The first subframe starts at 0xd3+0 and is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0xd3+0 | 1 bit  | 0b0             | mandatory 0 bit
0xd3+1 | 6 bit  | 0b000001        | verbatim subframe
0xd3+7 | 1 bit  | 0b0             | no wasted bits used
0xd4+0 | 16 bit | 0xc382          | 16-bit unencoded sample
0xd6+0 | 16 bit | 0xc40b          | 16-bit unencoded sample
0xd8+0 | 16 bit | 0xc14a          | 16-bit unencoded sample

The second subframe starts at 0xda+0 and is broken down in the following table

Start  | Length | Contents          | Description
:------|:-------|:------------------|:-----------------
0xda+0 | 1 bit  | 0b0               | mandatory 0 bit
0xda+1 | 6 bit  | 0b000001          | verbatim subframe
0xda+7 | 1 bit  | 0b1               | wasted bits used
0xdb+0 | 1 bit  | 0b1               | 1 wasted bit used
0xdb+1 | 15 bit | 0b110111001001000 | 15-bit unencoded sample
0xdd+0 | 15 bit | 0b110111010000001 | 15-bit unencoded sample
0xde+7 | 15 bit | 0b110110110011111 | 15-bit unencoded sample

As this subframe uses wasted bits, the 15-bit unencoded samples need to be shifted left by 1 bit. For example, sample 1 is stored as -4536 and becomes -9072 after shifting left 1 bit.

As the last subframe does not end on byte alignment, 2 padding bits are added before the 2 byte frame CRC follows at 0xe1+0.

### MD5 checksum verification

All samples in the file have been decoded, we can now verify the MD5 sum. All sample values must be interleaved and stored signed, coded little-endian. The result of this follows in groups of 12 samples (i.e. 6 interchannel samples) per line.

```
0x8428 B617 7946 3129 5E3A 2722 D445 D128 0B3D B723 EB45 DF28
0x723f 1E25 9D46 4929 B841 7026 5747 B829 8F43 8127 AEC7 14DF
0x9FC4 41DD 54C7 E4DE A5C4 40DD 1EC6 33DE 82C3 90DC 0BC4 02DD
0x4AC1 3EDB
```

The MD5sum of this is indeed the same as the one found in the streaminfo metadata block.


## Decoding example 3

This example is once again a very short FLAC file. The focus of this example is on decoding a subframe with a linear predictor and a coded residual with more than one partition.

### Example file 3 in hexadecimal representation

```
00000000: 664c 6143 8000 0022 1000 1000  fLaC..."....
0000000c: 0000 1f00 001f 07d0 0070 0000  .........p..
00000018: 0018 f8f9 e396 f5cb cfc6 dc80  ............
00000024: 7f99 7790 6b32 fff8 6802 0017  ..w.k2..h...
00000030: e944 004f 6f31 3d10 47d2 27cb  .D.Oo1=.G.'.
0000003c: 6d09 0831 452b dc28 2222 8057  m..1E+.("".W
00000048: a3                             .
```

### Example file 3 in binary representation (only audio frame)

```
0000002a: 11111111 11111000 01101000 00000010  ..h.
0000002e: 00000000 00010111 11101001 01000100  ...D
00000032: 00000000 01001111 01101111 00110001  .Oo1
00000036: 00111101 00010000 01000111 11010010  =.G.
0000003a: 00100111 11001011 01101101 00001001  '.m.
0000003e: 00001000 00110001 01000101 00101011  .1E+
00000042: 11011100 00101000 00100010 00100010  .(""
00000046: 10000000 01010111 10100011           .W.
```

### Streaminfo metadata block

Most of the streaminfo metadata block, including its header, is the same as in example 1, so only parts that are different are listed in the following table

Start  | Length  | Contents           | Description
:------|:--------|:-------------------|:-----------------
0x0c+0 | 3 byte  | 0x00001f           | Min. frame size 31 byte
0x0f+0 | 3 byte  | 0x00001f           | Max. frame size 31 byte
0x12+0 | 20 bit  | 0x07d0, 0x0000     | Sample rate 32000 hertz
0x14+4 | 3 bit   | 0b000              | 1 channel
0x14+7 | 5 bit   | 0b00111            | Sample bit depth 8 bit
0x15+4 | 36 bit  | 0b0000, 0x00000018 | Total no. of samples 24
0x1a   | 16 byte | (...)              | MD5 signature


### Audio frame

The frame header starts at position 0x2a and is broken down in the following table.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x2a+0 | 15 bit | 0xff, 0b1111100 | Frame sync
0x2b+7 | 1 bit  | 0b0             | Block size strategy
0x2c+0 | 4 bit  | 0b0110          | 8-bit block size further down
0x2c+4 | 4 bit  | 0b1000          | Sample rate 32kHz
0x2d+0 | 4 bit  | 0b0000          | Mono audio (1 channel)
0x2d+4 | 3 bit  | 0b001           | Bit depth 8 bit
0x2d+7 | 1 bit  | 0b0             | Mandatory 0 bit
0x2e+0 | 1 byte | 0x00            | Frame number 0
0x2f+0 | 1 byte | 0x17            | Block size 24
0x30+0 | 1 byte | 0xe9            | Frame header CRC

The first and only subframe starts at byte 0x31, it is broken down in the following table, without the coded residual.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x31+0 | 1 bit  | 0b0             | Mandatory 0 bit
0x31+1 | 6 bit  | 0b100010        | Linear prediction subframe, 3rd order
0x31+7 | 1 bit  | 0b0             | No wasted bits used
0x32+0 | 8 bit  | 0x00            | Unencoded warm-up sample 0
0x33+0 | 8 bit  | 0x4f            | Unencoded warm-up sample 79
0x34+0 | 8 bit  | 0x6f            | Unencoded warm-up sample 111
0x35+0 | 4 bit  | 0b0011          | Coefficient precision 4 bit
0x35+4 | 5 bit  | 0b00010         | Prediction right shift 2
0x36+1 | 4 bit  | 0b0111          | Predictor coefficient 7
0x36+5 | 4 bit  | 0b1010          | Predictor coefficient -6
0x37+1 | 4 bit  | 0b0010          | Predictor coefficient 2

The data stream continues with the coded residual, which is broken down in the following table. Residual partition 3 and 4 are left as an exercise for the reader.

Start  | Length | Contents        | Description
:------|:-------|:----------------|:-----------------
0x37+5 | 2 bit  | 0b00            | Rice-coded residual, 4-bit parameter
0x37+7 | 4 bit  | 0b0010          | Partition order 2
0x38+3 | 4 bit  | 0b0011          | Rice parameter 3
0x38+7 | 1 bit  | 0b1             | Quotient 0
0x39+0 | 3 bit  | 0b110           | Remainder 6
0x39+3 | 1 bit  | 0b1             | Quotient 0
0x39+4 | 3 bit  | 0b001           | Remainder 1
0x39+7 | 4 bit  | 0b0001          | Quotient 3
0x3a+3 | 3 bit  | 0b001           | Remainder 1
0x3a+6 | 4 bit  | 0b1111          | No Rice parameter, escape code
0x3b+2 | 5 bit  | 0b00101         | Partition encoded with 5 bits
0x3b+7 | 5 bit  | 0b10110         | Residual -10
0x3c+4 | 5 bit  | 0b11010         | Residual -6
0x3d+1 | 5 bit  | 0b00010         | Residual 2
0x3d+6 | 5 bit  | 0b01000         | Residual 8
0x3e+3 | 5 bit  | 0b01000         | Residual 8
0x3f+0 | 5 bit  | 0b00110         | Residual 6
0x3f+5 | 4 bit  | 0b0010          | Rice parameter 2
0x40+1 | 22 bit | (...)           | Residual partition 3
0x42+7 | 4 bit  | 0b0001          | Rice parameter 1
0x43+3 | 23 bit | (...)           | Residual partition 4

The frame ends with 6 padding bits and a 2 byte frame CRC

To decode this subframe, 21 predictions have to be calculated and added to their corresponding residuals. This is a sequential process: as each prediction uses previous samples, it is not possible to start this decoding halfway a subframe or decode a subframe with parallel threads.

The following table breaks down the calculation of each sample. For example, the predictor without shift value of row 4 is found by applying the predictor with the three warm-up samples: 7*111 - 6*79 + 2*0 = 303. This value is then shifted right by 2 bit: 303 >> 2 = 75. Then, the decoded residual sample is added: 75 + 3 = 78.

Residual  | Predictor w/o shift | Predictor | Sample value
----------|:-----|:----|:----
(warm-up) | N/A  | N/A | 0
(warm-up) | N/A  | N/A | 79
(warm-up) | N/A  | N/A | 111
3         | 303  | 75  | 78
-1        | 38   | 9   | 8
-13       | -190 | -48 | -61
-10       | -319 | -80 | -90
-6        | -248 | -62 | -68
2         | -58  | -15 | -13
8         | 137  | 34  | 42
8         | 236  | 59  | 67
6         | 191  | 47  | 53
0         | 53   | 13  | 13
-3        | -93  | -24 | -27
-5        | -161 | -41 | -46
-4        | -134 | -34 | -38
-1        | -44  | -11 | -12
1         | 52   | 13  | 14
1         | 94   | 23  | 24
4         | 60   | 15  | 19
2         | 17   | 4   | 6
2         | -24  | -6  | -4
2         | -26  | -7  | -5
0         | 1    | 0   | 0

Lining all these samples up, we get the following input for the MD5 summing process.

```
0x004F 6F4E 08C3 A6BC F32A 4335 0DE5 D2DA F40E 1813 06FC FB00
```

Which indeed results in the MD5 signature found in the streaminfo metadata block.
