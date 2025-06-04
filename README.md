# pure-vhdl-fft
A fully pipelined radix-2<sup>2</sup> FFT core built according to [this paper](https://doi.org/10.1109/IPPS.1996.508145). Supports natural order or bit-reversed order of input data, forward or inverse FFT.

There are two cores: `fft` and `fft2`. They have the same set of ports but differ slightly in performance and resources.
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
|ifft_in        |I| Transform direction, 0 for forward FFT, 1 for inverse FFT, must be the same for all samples of a block. Forward FFT is scaled, inverse FFT is unscaled |
|out_data_re    |O| Output data real part |
|out_data_im    |O| Output data imaginary part |
|out_data_valid |O| Output data valid |
|ifft_out       |O| Transform direction out, 0 - current output block is a result of forward FFT, 1 - current output block is a result of inverse FFT |
|cc_err_out     |O| Control counter error, goes high when in_data_valid is deasserted before the last sample of a block. After that correct operation of the core is not guaranteed until reset is asserted |

## Performance
Performance is measured in terms of root-mean square error between core output and floating point (double) FFT result.

### FFT core
DataWidth = 16
TwiddleWidth = 18
Max. error is for 100 simulated blocks.
| FFTlen | FFT RMS/max error, LSB | IFFT RMS/max error, LSB |
|--|--|--|
|8      | 0.57/1.35 | 0.29/0.67     |
|16     | 0.48/1.07 | 0.57/1.61     |
|32     | 0.60/1.47 | 0.95/2.82     |
|64     | 0.50/1.22 | 1.46/5.05     |
|128    | 0.60/1.49 | 2.18/7.88     |
|256    | 0.50/1.26 | 3.15/13.2     |
|512    | 0.60/1.55 | 4.53/17.6     |
|1024   | 0.50/1.34 | 6.45/27.6     |
|2048   | 0.60/1.64 | 9.09/35.8     |
|4096   | 0.50/1.33 | 12.7/47.3     |
|8192   | 0.60/1.66 | 17.6/74.9     |
|16384  | 0.50/1.43 | 23.9/103      |
|32768* | 0.60/1.68 | 35.1/156      |
|65536* | 0.50/1.39 | 52.1/233      |

### FFT2 core
DataWidth = 16
TwiddleWidth = 18
Max. error is for 100 simulated blocks.
| FFTlen | FFT RMS/max error, LSB | IFFT RMS/max error, LSB |
|--|--|--|
|8      | 0.42/0.80  | 0.33/0.91    |
|16     | 0.42/0.81  | 0.48/1.27    |
|32     | 0.44/0.95  | 0.97/2.82    |
|64     | 0.43/0.92  | 1.43/4.85    |
|128    | 0.45/1.06  | 2.18/7.88    |
|256    | 0.43/0.99  | 3.14/12.5    |
|512    | 0.45/1.14  | 4.53/17.6    |
|1024   | 0.43/1.03  | 6.44/27.6    |
|2048   | 0.45/1.20  | 9.09/35.8    |
|4096   | 0.43/1.10  | 12.7/48.3    |
|8192   | 0.45/1.29  | 17.6/74.9    |
|16384  | 0.43/1.10  | 23.9/104     |
|32768* | 0.45/1.23  | 35.1/156     |
|65536* | 0.43/1.11  | 47.6/202     |


## Utilization
* Vivado 2019.1
* Clock speed: 300 MHz
* Synthesis strategy: default
* Implementation strategy: default
* Device: XC7K325T-2
* DataWidth: 16
* TwiddleWidth: 18
* MaxShiftRegDelay: 256

### FFT core

| FFTlen | BitRev | LUT   | FF    | BRAM  | DSP   |
|--------|--------|-------|-------|-------|-------|
| 8      | 0      | 456   | 608   | 0     | 3     |
| 16     | 0      | 729   | 808   | 0     | 3     |
| 32     | 0      | 974   | 1186  | 0     | 6     |
| 64     | 0      | 1271  | 1413  | 0     | 6     |
| 128    | 0      | 1550  | 1821  | 0     | 9     |
| 256    | 0      | 1983  | 2105  | 0     | 9     |
| 512    | 0      | 2479  | 2573  | 0.5   | 12    |
| 1024   | 0      | 2758  | 2751  | 1     | 12    |
| 2048   | 0      | 2998  | 3043  | 2.5   | 15    |
| 4096   | 0      | 3177  | 3233  | 5     | 15    |
| 8192   | 0      | 3382  | 3545  | 10.5  | 18    |
| 16384  | 0      | 3618  | 3778  | 21.5  | 18    |
| 32768  | 0      | 3806  | 4082  | 45.5  | 21    |
| 65536  | 0      | 4123  | 4360  | 91.5  | 21    |
| 8      | 1      | 454   | 608   | 0     | 3     |
| 16     | 1      | 688   | 804   | 0     | 3     |
| 32     | 1      | 973   | 1186  | 0     | 6     |
| 64     | 1      | 1234  | 1407  | 0     | 6     |
| 128    | 1      | 1550  | 1821  | 0     | 9     |
| 256    | 1      | 1930  | 2097  | 0     | 9     |
| 512    | 1      | 2192  | 2393  | 1     | 12    |
| 1024   | 1      | 2720  | 2737  | 1     | 12    |
| 2048   | 1      | 2948  | 3043  | 2.5   | 15    |
| 4096   | 1      | 3145  | 3217  | 5     | 15    |
| 8192   | 1      | 3358  | 3545  | 10.5  | 18    |
| 16384  | 1      | 3585  | 3742  | 22    | 18    |
| 32768  | 1      | 3807  | 4082  | 45.5  | 21    |
| 65536  | 1      | 4070  | 4348  | 93    | 21    |


### FFT2 core

| FFTlen | BitRev | LUT   | FF    | BRAM  | DSP   |
|--------|--------|-------|-------|-------|-------|
| 8      | 0      | 422   | 583   | 0     | 3     |
| 16     | 0      | 729   | 795   | 0     | 3     |
| 32     | 0      | 942   | 1162  | 0     | 6     |
| 64     | 0      | 1259  | 1401  | 0     | 6     |
| 128    | 0      | 1513  | 1797  | 0     | 9     |
| 256    | 0      | 1970  | 2093  | 0     | 9     |
| 512    | 0      | 2514  | 2549  | 0.5   | 12    |
| 1024   | 0      | 2819  | 2739  | 1     | 12    |
| 2048   | 0      | 3053  | 3019  | 2.5   | 15    |
| 4096   | 0      | 3256  | 3221  | 5     | 15    |
| 8192   | 0      | 3462  | 3521  | 10.5  | 18    |
| 16384  | 0      | 3726  | 3748  | 21.5  | 18    |
| 32768  | 0      | 3908  | 4058  | 45.5  | 21    |
| 65536  | 0      | 4251  | 4350  | 91.5  | 21    |
| 8      | 1      | 420   | 595   | 0     | 3     |
| 16     | 1      | 700   | 807   | 0     | 3     |
| 32     | 1      | 946   | 1170  | 0     | 6     |
| 64     | 1      | 1233  | 1407  | 0     | 6     |
| 128    | 1      | 1529  | 1805  | 0     | 9     |
| 256    | 1      | 1966  | 2097  | 0     | 9     |
| 512    | 1      | 2226  | 2369  | 1.5   | 12    |
| 1024   | 1      | 2803  | 2729  | 1.5   | 12    |
| 2048   | 1      | 3001  | 3019  | 3     | 15    |
| 4096   | 1      | 3219  | 3201  | 6     | 15    |
| 8192   | 1      | 3440  | 3521  | 11    | 18    |
| 16384  | 1      | 3682  | 3726  | 23.5  | 18    |
| 32768  | 1      | 3904  | 4104  | 47.5  | 21    |
| 65536  | 1      | 4189  | 4331  | 99    | 21    |

