library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------

entity fft_test_top is
    generic(
        DataWidth : integer := 16;
        TwiddleWidth : integer := 18;
        MaxShiftRegDelay : integer := 256;
        FFTlen : integer := 4096;
        BitReversedInput : integer := 0;
        Nchannels : integer := 1;
        UseFFT2: integer := 0
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        di_re: in std_logic_vector(DataWidth-1 downto 0);
        di_im: in std_logic_vector(DataWidth-1 downto 0);
        di_valid: in std_logic;
        di_ready: out std_logic;
        di_ifft: in std_logic;
        di_scaling_sch: in std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);
        do_re: out std_logic_vector(DataWidth-1 downto 0);
        do_im: out std_logic_vector(DataWidth-1 downto 0);
        do_valid: out std_logic;
        do_ifft: out std_logic;
        do_cc_err: out std_logic
    );
end entity fft_test_top;

-----------------------------------------------------------

architecture top of fft_test_top is

begin

    gen_fft: if UseFFT2 <= 0 generate
        fft_my: entity work.fft
        generic map(
            DataWidth => DataWidth,
            TwiddleWidth => TwiddleWidth,
            MaxShiftRegDelay => MaxShiftRegDelay,
            FFTlen => FFTlen,
            BitReversedInput => BitReversedInput,
            Nchannels => Nchannels
        )
        port map(
            clk => clk,
            reset => reset,
            in_data_re => di_re,
            in_data_im => di_im,
            in_data_valid => di_valid,
            ifft_in => di_ifft,
            scaling_sch => di_scaling_sch,
            out_data_re => do_re,
            out_data_im => do_im,
            out_data_valid => do_valid,
            ifft_out => do_ifft,
            cc_err_out => do_cc_err
        );
    end generate gen_fft;
    
    gen_fft2: if UseFFT2 > 0 generate
        fft_my: entity work.fft2
        generic map(
            DataWidth => DataWidth,
            TwiddleWidth => TwiddleWidth,
            MaxShiftRegDelay => MaxShiftRegDelay,
            FFTlen => FFTlen,
            BitReversedInput => BitReversedInput,
            Nchannels => Nchannels
        )
        port map(
            clk => clk,
            reset => reset,
            in_data_re => di_re,
            in_data_im => di_im,
            in_data_valid => di_valid,
            ifft_in => di_ifft,
            scaling_sch => di_scaling_sch,
            out_data_re => do_re,
            out_data_im => do_im,
            out_data_valid => do_valid,
            ifft_out => do_ifft,
            cc_err_out => do_cc_err
        );
    end generate gen_fft2;
    
end architecture;