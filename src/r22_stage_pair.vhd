library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix-2^2 FFT stage pair

entity r22_stage_pair is
    generic(
        DataWidth: integer;
        TwiddleWidth: integer;
        MaxShiftRegDelay: integer := 64;
        FFTlen: integer;
        StagePairNum: integer;  -- 0 for 1st pair of stages, 1 for next pair, etc.
        BitReversedInput: integer
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_data_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;
        scaling_sch_in: in std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);
        
        out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_data_valid: out std_logic;
        ifft_out: out std_logic;
        scaling_sch_out: out std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);
        
        cc_err: out std_logic_vector(1 downto 0)
    );
end entity r22_stage_pair;

-----------------------------------------------------------

architecture rtl of r22_stage_pair is

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
    constant TWINT: integer := 2;
    constant TWFRAC: integer := TwiddleWidth - TWINT;
    constant CNTW: integer := integer(log2(real(FFTlen)));
    constant SCALE_BITS: integer := 2;  -- FFT scaling 2 bits per pair
    constant SCALING_LEN: integer := scaling_sch_in'length;

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

    constant DLY_WIDTH: integer := 2*(DataWidth+2) + 2 + SCALING_LEN;
    signal dly_bf2_in_data:  std_logic_vector(DLY_WIDTH-1 downto 0);
    signal dly_bf2_out_data: std_logic_vector(DLY_WIDTH-1 downto 0);
    signal dly_bf2_out_re:  std_logic_vector(DataWidth+2-1 downto 0);
    signal dly_bf2_out_im:  std_logic_vector(DataWidth+2-1 downto 0);
    signal dly_bf2_out_valid: std_logic;
    signal dly_bf2_ifft_out: std_logic;
    signal dly_bf2_scaling: std_logic_vector(SCALING_LEN-1 downto 0);

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
    signal mul_user_in, mul_user_out: std_logic_vector(SCALING_LEN+1-1 downto 0);
    signal mul_scaling_out: std_logic_vector(SCALING_LEN-1 downto 0);

    --signal unscaled_re, unscaled_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal scaled0_re, scaled0_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal scaled1_re, scaled1_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal scaled2_re, scaled2_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    --signal unscaled_last_re, unscaled_last_im: std_logic_vector(DataWidth+SCALE_BITS-1 downto 0);
    signal scaled_last0_re, scaled_last0_im: std_logic_vector(DataWidth+SCALE_BITS-1 downto 0);
    signal scaled_last1_re, scaled_last1_im: std_logic_vector(DataWidth+SCALE_BITS-1 downto 0);
    signal scaled_last2_re, scaled_last2_im: std_logic_vector(DataWidth+SCALE_BITS-1 downto 0);
    signal rounder_in_re, rounder_in_im: std_logic_vector(DataWidth+SCALE_BITS+TWFRAC-1 downto 0);
    signal rounder_last_in_re, rounder_last_in_im: std_logic_vector(DataWidth+SCALE_BITS-1 downto 0);
    signal rounder_out_re, rounder_out_im: std_logic_vector(DataWidth-1 downto 0);
    signal rounder_in_valid, rounder_out_valid: std_logic;

    signal scaling: std_logic_vector(1 downto 0);
    signal bf1_scale_out: std_logic_vector(SCALING_LEN-1 downto 0);
    signal bf2_scale_out: std_logic_vector(SCALING_LEN-1 downto 0);

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
        scale_in    => scaling_sch_in,
        out_data_re => bf1_out_re,
        out_data_im => bf1_out_im,
        out_valid   => bf1_out_valid,
        ifft_out    => bf1_ifft_flag_out,
        scale_out   => bf1_scale_out,
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
        scale_in    => bf1_scale_out,
        out_data_re => bf2_out_re,
        out_data_im => bf2_out_im,
        out_valid   => bf2_out_valid,
        ifft_out    => bf2_ifft_flag_out,
        scale_out   => bf2_scale_out,
        spl_cnt_out => bf2_spl_cnt,
        cc_err      => bf2_cc_err
    );

    --scaling <= bf2_scale_out(2*StagePairNum+1 downto 2*StagePairNum);  -- 1:0 for 0th stage, 3:2 for 1st, etc.

    gen_not_last_stage: if not is_last_stage(FFTlen, StagePairNum) generate

        dly_bf2_in_data <= bf2_scale_out & bf2_ifft_flag_out & bf2_out_valid & bf2_out_im & bf2_out_re;

        -- delay line for twiddle_gen latency compensation
        delay_line_twgen : entity work.delay_line_fft
        generic map (
            --Delay       => TWGEN_LATENCY-BF2_LATENCY,
            Delay       => TWGEN_LATENCY,
            InDataWidth => DLY_WIDTH,
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

        dly_bf2_scaling   <= dly_bf2_out_data(dly_bf2_out_data'left downto 2*(DataWidth+2)+2);
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
            ifft        => bf2_ifft_flag_out,   -- before delay
            in_addr     => bf2_spl_cnt,
            out_data_re => tw_re,
            out_data_im => tw_im
        );

        mul_in_re1 <= std_logic_vector(resize(signed(dly_bf2_out_re), 24));
        mul_in_im1 <= std_logic_vector(resize(signed(dly_bf2_out_im), 24));
        mul_in_re2 <= std_logic_vector(resize(signed(tw_re), mul_in_re2'length));
        mul_in_im2 <= std_logic_vector(resize(signed(tw_im), mul_in_im2'length));
        mul_in_valid <= dly_bf2_out_valid;

        mul_user_in <= dly_bf2_scaling & dly_bf2_ifft_out;

        twiddle_mul : entity work.mul_twiddle_24x18
        generic map(
            UserWidth => SCALING_LEN+1
        )
        port map (
            clk       => clk,
            reset     => reset,
            -- user
            user_in  => mul_user_in,  -- after delay
            user_out => mul_user_out,
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

        mul_ifft_out <= mul_user_out(0);
        mul_scaling_out <= mul_user_out(SCALING_LEN downto 1);
        scaling <= mul_scaling_out(2*StagePairNum+1 downto 2*StagePairNum);  -- 1:0 for 0th stage, 3:2 for 1st, etc.

        scaled2_re <= mul_out_re(TWFRAC+DataWidth-1+SCALE_BITS downto 0);   -- scaled discard LSB in rounder
        scaled2_im <= mul_out_im(TWFRAC+DataWidth-1+SCALE_BITS downto 0);
        scaled1_re <= mul_out_re(TWFRAC+DataWidth+1-1 downto 0) & "0"; -- discard 1 MSB and 1 LSB
        scaled1_im <= mul_out_im(TWFRAC+DataWidth+1-1 downto 0) & "0";
        scaled0_re <= mul_out_re(TWFRAC+DataWidth-1 downto 0) & "00"; -- unscaled, discard MSBs
        scaled0_im <= mul_out_im(TWFRAC+DataWidth-1 downto 0) & "00";

        --rounder_in_re <= scaled_re when mul_ifft_out = '0' else unscaled_re;
        --rounder_in_im <= scaled_im when mul_ifft_out = '0' else unscaled_im;
        with scaling select rounder_in_re <=
            scaled0_re when "00",
            scaled1_re when "01",
            scaled2_re when others;
        with scaling select rounder_in_im <=
            scaled0_im when "00",
            scaled1_im when "01",
            scaled2_im when others;
        rounder_in_valid <= mul_out_valid;

        rounder_inst : entity work.rounder_away_opt_cplx
        generic map (
            InWidth  => DataWidth + SCALE_BITS + TWFRAC,
            OutWidth => DataWidth
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in_re  => rounder_in_re,
            data_in_im  => rounder_in_im,
            valid_in    => rounder_in_valid,
            data_out_re => rounder_out_re,
            data_out_im => rounder_out_im,
            valid_out   => rounder_out_valid
        );
        
        ifft_out <= mul_ifft_out when rising_edge(clk);   --! TODO: put through rounder via user_in/out
        scaling_sch_out <= mul_scaling_out when rising_edge(clk);
    end generate gen_not_last_stage;

    gen_last_stage: if is_last_stage(FFTlen, StagePairNum) generate
        scaling <= bf2_scale_out(2*StagePairNum+1 downto 2*StagePairNum);  -- 1:0 for 0th stage, 3:2 for 1st, etc.

        scaled_last2_re <= bf2_out_re;  -- disard LSBs in rounder
        scaled_last2_im <= bf2_out_im;
        scaled_last1_re <= std_logic_vector(signed(bf2_out_re) sll 1); -- discard 1 MSB and 1 LSB
        scaled_last1_im <= std_logic_vector(signed(bf2_out_im) sll 1);
        scaled_last0_re <= std_logic_vector(signed(bf2_out_re) sll SCALE_BITS); -- discard MSBs
        scaled_last0_im <= std_logic_vector(signed(bf2_out_im) sll SCALE_BITS);

        --rounder_last_in_re <= scaled_last_re when bf2_ifft_flag_out = '0' else unscaled_last_re;
        --rounder_last_in_im <= scaled_last_im when bf2_ifft_flag_out = '0' else unscaled_last_im;
        with scaling select rounder_last_in_re <=
            scaled_last0_re when "00",
            scaled_last1_re when "01",
            scaled_last2_re when others;
        with scaling select rounder_last_in_im <=
            scaled_last0_im when "00",
            scaled_last1_im when "01",
            scaled_last2_im when others;
        rounder_in_valid <= bf2_out_valid;

        rounder_inst : entity work.rounder_away_opt_cplx
        generic map (
            InWidth  => DataWidth + SCALE_BITS,
            OutWidth => DataWidth
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in_re  => rounder_last_in_re,
            data_in_im  => rounder_last_in_im,
            valid_in    => rounder_in_valid,
            data_out_re => rounder_out_re,
            data_out_im => rounder_out_im,
            valid_out   => rounder_out_valid
        );
        
        ifft_out <= bf2_ifft_flag_out when rising_edge(clk);    --! TODO: put through rounder via user_in/out
        scaling_sch_out <= bf2_scale_out when rising_edge(clk);
    end generate gen_last_stage;

    out_data_re <= rounder_out_re;
    out_data_im <= rounder_out_im;
    out_data_valid <= rounder_out_valid;

    cc_err <= bf2_cc_err & bf1_cc_err;

end architecture;