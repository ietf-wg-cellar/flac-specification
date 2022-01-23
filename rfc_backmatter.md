
{backmatter}

# Numerical considerations

In order to maintain lossless behavior, all arithmetic used in encoding and decoding sample values MUST be done with integer data types, in order to eliminate the possibility of introducing rounding errors associated with floating-point arithmetic. Use of floating-point representations in analysis (e.g. finding a good predictor or rice parameter) is not a concern, as long as the process of using the found predictor and rice parameter to encode audio samples is implemented with only integer math.

Furthermore, the possibility of integer overflow MUST be eliminated by using data types large enough to never overflow. Choosing a 64-bit signed data type for all arithmetic involving sample values would make sure the possibility for overflow is eliminated, but usually smaller data types are chosen for increased performance, especially in embedded devices. This section will provide guidelines for choosing the right data type in each step of encoding and decoding FLAC files.

## Determining necessary data type size
To find the smallest data type size that is guaranteed not to overflow for a certain sequence of arithmetic operations, the combination of values producing the largest possible result should be considered.

If for example two 16-bit signed integers are added, the largest possible result forms if both values are the largest number that can be represented with a 16-bit signed integer. To store the result, an signed integer data type with at least 17 bits is needed. Similarly, when adding 4 of these values, 18 bits are needed, when adding 8, 19 bits are needed etc. In general, the number of bits necessary when adding numbers together is increased by the log base 2 of the number of values rounded up to the nearest integer. So, when adding 18 unknown values stored in 8 bit signed integers, we need a signed integer data type of at least 13 bits to store the result, as the log base 2 of 18 rounded up is 5.

In case of multiplication, the number of bits needed for the result is the size of the first variable plus the size of the second variable, ignoring one sign bit. If for example a 16-bit signed integer is multiplied by a 16-bit signed integer, the result needs at least 31 bits to store without overflowing.

## Stereo decorrelation
When stereo decorrelation is used, the side channel will have one extra bit of bit depth, see  [section on Interchannel Decorrelation](#interchannel-decorrelation).

This means that while 16-bit signed integers have sufficient range to store samples from a fully decoded FLAC frame with a bit depth of 16 bit, the decoding of a side subframe in such a file will need a data type with at least 17 bit to store decoded subframe samples before undoing stereo decorrelation.

Most FLAC decoders store decoded (subframe) samples as 32-bit values, which is sufficient for files with bit depths up to (and including) 31 bit.

## Prediction
A prediction (which is used to calculate the residual on encoding or with the residual to calculate the sample value on decoding) is formed by multiplying and summing preceding sample values. In order to eliminate the possibility of integer overflow, the combination of preceding sample values and predictor coefficients producing the largest possible value should be considered.

To determine the size of the data type needed to to calculate either the residual sample (on encoding) or the audio sample value (on decoding), the maximal possible value for these is calculated [as described in the previous subsection](#determining-necessary-data-type-size) in the following table. For example: if a frame codes for 16-bit audio and has some form of stereo decorrelation, the subframe coding for the side channel would need 16+1+3 bits in case a third order fixed predictor is used.

Order | Calculation of residual                              | Sample values summed | Extra bits
:-----|:-----------------------------------------------------|:---------------------|:-----------
0     | s(n)                                                 | 1                    | 0
1     | s(n) - s(n-1)                                        | 2                    | 1
2     | s(n) - 2 * s(n-1) + s(n-2)                           | 4                    | 2
3     | s(n) - 3 * s(n-1) + 3 * s(n-2) - s(n-3)              | 8                    | 3
4     | s(n) - 4 * s(n-1) + 6 * s(n-2) - 4 * s(n-3) + s(n-4) | 16                   | 4

Where

- n is the number of the sample being predicted
- s(n) is the sample being predicted
- s(n-1) is the sample before the one being predicted, s(n-2) is the sample before that etc.

For subframes with a linear predictor, calculation is a little more complicated. Each prediction is a sum of several multiplications. Each of these multiply a sample value with a predictor coefficient. The extra bits needed can be calculated by adding the predictor coefficient precision (in bits) to the bit depth of the audio samples. As both are signed numbers and only one 'sign bit' is necessary, 1 bit can be subtracted. To account for the summing of these multiplications, the log base 2 of the predictor order rounded up is added.

For example, if the sample bitdepth of the source is 24, the current subframe encodes a side channel (see the [section on interchannel decorrelation](#interchannel-decorrelation)), the predictor order is 12 and the predictor coefficient precision is 15 bits, the minimum required size of the used signed integer data type is at least (24 + 1) + (15 - 1) + ceil(log2(12)) = 43 bits. As another example, with a side-channel subframe bit depth of 16, a predictor order of 8 and a predictor coefficient precision of 12 bits, the minimum required size of the used signed integer data type is (16 + 1) + (12 - 1)  + ceil(log2(8)) = 31 bits.

After the prediction has been shifted right, the number of bits needed is reduced by the amount of right shift and increased by one bit for the subtraction from the current sample on encoding. On decoding, the data type size needed to store the result of the addition of the residual and the prediction should fit the subframe bit depth, assuming all calculations were done correctly.

Taking the last example where 31 bits were needed for the prediction, the required data type size for the residual samples in case of a right shift of 10 bits would be 31 - 10 + 1 = 22 bits.

## Rice coding
When folding (i.e. zig-zag encoding) the residual sample values, no extra bits are needed when the absolute value of each residual sample is first stored in an unsigned data type of the size of the last step, then doubled and then has one subtracted depending on whether the residual sample was positive or negative. Many implementations however choose to require one extra bit of data type size so zig-zag encoding can happen in one step and without a cast instead of the procedure described in the previous sentence.
