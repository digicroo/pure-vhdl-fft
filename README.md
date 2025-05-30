# pure-vhdl-fft
Fast Fourier transform core written in pure VHDL

This is a radix-2<sup>2</sup> FFT core built according to [this paper](https://doi.org/10.1109/IPPS.1996.508145)

There are two cores: `fft` and `fft2`. They have the same set of ports but differ slightly in performaance and resources.
It is recommended to use fft for bit-reversed input to save resources, and fft2 for natural order input to get lower RMS error.

## Generics/parameters

| Name | Description | Range |
|--|--|--|
| DataWidth | Bit width of input and output data (real or imaginary part) | Up to 22 |
| TwiddleWidth | Bit width of twiddle factors. 2 bits for integer part, the rest for fractional part | Up to 18 |
| MaxShiftRegDelay | Maximum length of a delay line to be implemented as a shift register. Delay lines longer than this value are implemented as RAM.| Recommended values are 32 to 512 for Xilinx 7 series|
| FFTlen | Transform length, must be a power of 2. | Min. 8 |
| BitReversedInput | 0 for natural ordered input and bit-reversed order output, 1 for bit-reversed order input and natural order output. | 0, 1 |


## Ports

| Name | I/O | Description |
|--|--|--|
|clk            |I| Clock |
|reset          |I| Synchronous reset |
|in_data_re     |I| Input data real part | 
|in_data_im     |I| Input data imaginary part |
|in_data_valid  |I| Input data valid, block-wise |
|ifft_in        |I| Transform direction, 0 for forward FFT, 1 for inverse FFT, must be the same for all samples of a block |
|out_data_re    |O| Output data real part |
|out_data_im    |O| Output data imaginary part |
|out_data_valid |O| Output data valid |
|ifft_out       |O| Transform direction out, 0 - current output block is a result of forward FFT, 1 - current output block is a result of inverse FFT |
|cc_err_out     |O| Control counter error, goes high when in_data_valid is deasserted before the last sample of a block. After that correct operation of the core is not guaranteed until reset is asserted |

*performance tables in progress*