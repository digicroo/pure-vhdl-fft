library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix-2^2 FFT stage pair

entity r22_stage_pair2 is
    generic(
        DataWidth: integer;
        TwiddleWidth: integer;
        MaxShiftRegDelay: integer := 64;
        FFTlen: integer;
        StagePairNum: integer;  -- 0 for 1st pair of stages, 1 for next pair, etc.
        BitReversedInput: integer;
        Debug: boolean := false
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_data_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;
        
        --out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_re: out std_logic_vector(TwiddleWidth+DataWidth-1 downto 0);
        --out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(TwiddleWidth+DataWidth-1 downto 0);
        out_data_valid: out std_logic;
        ifft_out: out std_logic;
        
        cc_err: out std_logic_vector(1 downto 0)
    );
end entity r22_stage_pair2;

-----------------------------------------------------------

architecture rtl of r22_stage_pair2 is

    -- returns true if current stage is the last full pair for this FFT length
    function is_last_stage(len, pairnum: integer) return boolean is
        variable res: boolean := false;
    begin
        if integer(log2(real(len)))-1 = 2*pairnum+1 then
            res := true;
        end if;
        return res;
    end function;

    constant BF1_LATENCY: integer := 1;
    constant BF2_LATENCY: integer := 1;
    constant TWGEN_LATENCY: integer := 3;
    constant TWINT: integer := 2;   -- twiddle factors integer part bits
    constant TWFRAC: integer := TwiddleWidth - TWINT;   -- twiddle factors fractional part bits
    constant CNTW: integer := integer(log2(real(FFTlen)));
    constant SCALE_BITS: integer := 2;  -- FFT scaling 2 bits per pair

    signal bf1_in_re:       std_logic_vector(DataWidth downto 0);
    signal bf1_in_im:       std_logic_vector(DataWidth downto 0);
    signal bf1_in_valid:    std_logic;
    signal bf1_out_re:      std_logic_vector(DataWidth downto 0);
    signal bf1_out_im:      std_logic_vector(DataWidth downto 0);
    signal bf1_out_valid:   std_logic;
    signal bf1_cc_err:      std_logic;
    signal bf1_ifft_flag_out: std_logic;
    
    signal bf2_in_re:       std_logic_vector(DataWidth+1 downto 0);
    signal bf2_in_im:       std_logic_vector(DataWidth+1 downto 0);
    signal bf2_in_valid:    std_logic;
    signal bf2_out_re:      std_logic_vector(DataWidth+1 downto 0);
    signal bf2_out_im:      std_logic_vector(DataWidth+1 downto 0);
    signal bf2_out_valid:   std_logic;
    signal bf2_spl_cnt:     std_logic_vector(CNTW-1 downto 0);
    signal bf2_cc_err:      std_logic;
    signal bf2_ifft_flag_out: std_logic;

    signal dly_bf2_in_data:  std_logic_vector(2*(DataWidth+2)+1 downto 0);
    signal dly_bf2_out_data: std_logic_vector(2*(DataWidth+2)+1 downto 0);
    signal dly_bf2_out_re:  std_logic_vector(DataWidth+2-1 downto 0);
    signal dly_bf2_out_im:  std_logic_vector(DataWidth+2-1 downto 0);
    signal dly_bf2_out_valid: std_logic;
    signal dly_bf2_ifft_out: std_logic;

    signal tw_re, tw_im: std_logic_vector(TwiddleWidth-1 downto 0);

    signal mul_in_re1: std_logic_vector(23 downto 0);
    signal mul_in_im1: std_logic_vector(23 downto 0);
    signal mul_in_re2: std_logic_vector(17 downto 0);
    signal mul_in_im2: std_logic_vector(17 downto 0);
    signal mul_in_valid: std_logic;
    signal mul_out_re: std_logic_vector(42 downto 0);
    signal mul_out_im: std_logic_vector(42 downto 0);
    signal mul_out_valid: std_logic;
    signal mul_ifft_out: std_logic;

    signal unscaled_re, unscaled_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal unscaled_valid: std_logic;
    signal scaled_re, scaled_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal scaled_valid: std_logic;
    
    -- dbg
    signal ovf_re, ovf_im, ovf: std_logic;

begin

    bf1_in_re <= std_logic_vector(resize(signed(in_data_re), DataWidth+1));
    bf1_in_im <= std_logic_vector(resize(signed(in_data_im), DataWidth+1));
    bf1_in_valid <= in_data_valid;

    r22_stage_1st_half : entity work.r22_stage_bf1
    generic map (
        DataWidth    => DataWidth+1,
        FFTlen       => FFTlen,
        BitReversedInput => BitReversedInput,
        StagePairNum => StagePairNum,
        MaxShiftRegDelay => MaxShiftRegDelay
    )
    port map (
        clk         => clk,
        reset       => reset,
        in_data_re  => bf1_in_re,
        in_data_im  => bf1_in_im,
        in_valid    => bf1_in_valid,
        ifft_in     => ifft_in,
        out_data_re => bf1_out_re,
        out_data_im => bf1_out_im,
        out_valid   => bf1_out_valid,
        ifft_out    => bf1_ifft_flag_out,
        cc_err      => bf1_cc_err
    );

    bf2_in_re <= std_logic_vector(resize(signed(bf1_out_re), DataWidth+2));
    bf2_in_im <= std_logic_vector(resize(signed(bf1_out_im), DataWidth+2));
    bf2_in_valid <= bf1_out_valid;

    r22_stage_2nd_half : entity work.r22_stage_bf2
    generic map (
        DataWidth    => DataWidth+2,
        FFTlen       => FFTlen,
        BitReversedInput => BitReversedInput,
        StagePairNum => StagePairNum,
        MaxShiftRegDelay => MaxShiftRegDelay
    )
    port map (
        clk         => clk,
        reset       => reset,
        in_data_re  => bf2_in_re,
        in_data_im  => bf2_in_im,
        in_valid    => bf2_in_valid,
        ifft_in     => bf1_ifft_flag_out,
        out_data_re => bf2_out_re,
        out_data_im => bf2_out_im,
        out_valid   => bf2_out_valid,
        ifft_out    => bf2_ifft_flag_out,
        spl_cnt_out => bf2_spl_cnt,
        cc_err      => bf2_cc_err
    );


    gen_not_last_stage: if not is_last_stage(FFTlen, StagePairNum) generate

        dly_bf2_in_data <= bf2_ifft_flag_out & bf2_out_valid & bf2_out_im & bf2_out_re;

        -- delay line for twiddle_gen latency compensation
        delay_line_fft_1 : entity work.delay_line_fft
        generic map (
            --Delay       => TWGEN_LATENCY-BF2_LATENCY,
            Delay       => TWGEN_LATENCY,
            InDataWidth => 2*(DataWidth+2)+2,
            UseRAM      => 0
        )
        port map (
            clk       => clk,
            reset     => reset,
            in_data   => dly_bf2_in_data,
            in_valid  => '0',
            out_data  => dly_bf2_out_data,
            out_valid => open
        );

        dly_bf2_ifft_out  <= dly_bf2_out_data(2*(DataWidth+2)+1);
        dly_bf2_out_valid <= dly_bf2_out_data(2*(DataWidth+2));
        dly_bf2_out_im <=    dly_bf2_out_data(2*(DataWidth+2)-1 downto DataWidth+2);
        dly_bf2_out_re <=    dly_bf2_out_data((DataWidth+2)-1 downto 0);

        twiddle_gen: entity work.twiddle_gen_fft
        generic map (
            TwiddleWidth => TwiddleWidth,
            FFTlen       => FFTlen,
            Stage        => StagePairNum,
            BitReversedInput => BitReversedInput
        )
        port map (
            clk         => clk,
            reset       => reset,
            ifft        => bf2_ifft_flag_out,   -- ifft flag before delay
            in_addr     => bf2_spl_cnt,
            out_data_re => tw_re,
            out_data_im => tw_im
        );

        mul_in_re1 <= std_logic_vector(resize(signed(dly_bf2_out_re), 24));
        mul_in_im1 <= std_logic_vector(resize(signed(dly_bf2_out_im), 24));
        mul_in_re2 <= std_logic_vector(resize(signed(tw_re), mul_in_re2'length));
        mul_in_im2 <= std_logic_vector(resize(signed(tw_im), mul_in_im2'length));
        mul_in_valid <= dly_bf2_out_valid;

        twiddle_mul : entity work.mul_twiddle_24x18
        generic map(
            UserWidth => 1
        )
        port map (
            clk       => clk,
            reset     => reset,
            -- user
            user_in(0)  => dly_bf2_ifft_out,  -- ifft flag after delay
            user_out(0) => mul_ifft_out,
            -- data
            in_re1    => mul_in_re1,
            in_im1    => mul_in_im1,
            -- twiddle
            in_re2    => mul_in_re2,
            in_im2    => mul_in_im2,
            in_valid  => mul_in_valid,
            out_re    => mul_out_re,
            out_im    => mul_out_im,
            out_valid => mul_out_valid
        );

        -- lower TWFRAC bits are fractional part, another SCALE_BITS must be discarded/rounded for scaling
        scaled_re <= mul_out_re(TWFRAC+DataWidth-1+SCALE_BITS downto 0);
        scaled_im <= mul_out_im(TWFRAC+DataWidth-1+SCALE_BITS downto 0);
        unscaled_re <= mul_out_re(TWFRAC+DataWidth-1 downto 0) & "00"; -- discard MSBs
        unscaled_im <= mul_out_im(TWFRAC+DataWidth-1 downto 0) & "00";

        out_data_re <= scaled_re when mul_ifft_out = '0' else unscaled_re;
        out_data_im <= scaled_im when mul_ifft_out = '0' else unscaled_im;
        out_data_valid <= mul_out_valid;
        ifft_out <= mul_ifft_out;   --! TODO: put through rounder via user_in/out
    end generate gen_not_last_stage;

    gen_last_stage: if is_last_stage(FFTlen, StagePairNum) generate    
        scaled_re <= std_logic_vector(resize(signed(bf2_out_re), DataWidth+TwiddleWidth));
        scaled_im <= std_logic_vector(resize(signed(bf2_out_im), DataWidth+TwiddleWidth));
        unscaled_re <= std_logic_vector(resize(signed(bf2_out_re), DataWidth+TwiddleWidth) sll SCALE_BITS); -- discard MSBs
        unscaled_im <= std_logic_vector(resize(signed(bf2_out_im), DataWidth+TwiddleWidth) sll SCALE_BITS);

        out_data_re <= scaled_re when bf2_ifft_flag_out = '0' else unscaled_re;
        out_data_im <= scaled_im when bf2_ifft_flag_out = '0' else unscaled_im;
        out_data_valid <= bf2_out_valid;
        ifft_out <= bf2_ifft_flag_out;
    end generate gen_last_stage;
    
    ovf_re <= '0' when scaled_re(scaled_re'left downto scaled_re'left-2) = "000" or scaled_re(scaled_re'left downto scaled_re'left-2) = "111" else '1';
    ovf_im <= '0' when scaled_im(scaled_im'left downto scaled_im'left-2) = "000" or scaled_im(scaled_im'left downto scaled_im'left-2) = "111" else '1';
    ovf <= ovf_re or ovf_im;

    cc_err <= bf2_cc_err & bf1_cc_err;

end architecture;