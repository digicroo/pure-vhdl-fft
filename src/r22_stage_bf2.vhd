library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix-2^2 FFT stage with butterfly type 2


entity r22_stage_bf2 is
    generic(
        DataWidth: integer;
        FFTlen: integer;
        BitReversedInput: integer;
        StagePairNum: integer;  -- 0 for 1st pair of stages, 1 for next pair, etc. (for natural input FFT)
        MaxShiftRegDelay: integer := 64
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        --mode: in std_logic_vector(1 downto 0);
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;      -- must be block-wise
        out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_valid: out std_logic;
        ifft_out: out std_logic;      -- must be block-wise
        spl_cnt_out: out std_logic_vector(integer(log2(real(FFTlen)))-1 downto 0);  -- to twiddle gen
        cc_err: out std_logic
    );
end entity r22_stage_bf2;

-----------------------------------------------------------

architecture rtl of r22_stage_bf2 is

    function get_subfft_len(fftlen, pairnum, bitrev: integer) return integer is
        variable res: integer;
    begin
        if bitrev <= 0 then -- natural input
            res := fftlen / 2**(2*pairnum+1);
        else    -- bitrev input
            res := 2**(2*pairnum+2);
        end if;
        return res;
    end function;
    
    function get_ccwidth(len, rev: integer) return integer is
        variable res: integer;
    begin
        if rev <= 0 then
            res := integer(log2(real(len))) + 1;    -- cc counts FFTLEN_CUR as for previous stage
        else
            res := integer(log2(real(len)));        -- cc counts FFTLEN_CUR as for current stage
        end if;
        return res;
    end function;

    constant BF_LATENCY: integer := 1;
    constant FFTLEN_CUR: integer := get_subfft_len(FFTlen, StagePairNum, BitReversedInput);   -- length of sub-fft for current stage
    constant DELAY_LEN: integer := FFTLEN_CUR / 2 - BF_LATENCY;
    constant DELAY_USERAM: integer := DELAY_LEN - MaxShiftRegDelay;
    constant SPL_CNTW: integer := integer(log2(real(FFTlen)));    -- sample counter width
    constant CCW: integer := get_ccwidth(FFTLEN_CUR, BitReversedInput);
    -- when bitrev, cc counts to FFTLEN_CUR,
    -- mode is 2 MSBs of cc (to count quarters)
    constant OUT_VALID_START_TIME: integer := FFTLEN_CUR / 2 - 1 + BF_LATENCY;

    signal mode: std_logic_vector(1 downto 0);
    signal ispl_cnt, ospl_cnt: unsigned(SPL_CNTW-1 downto 0);
    signal cc: unsigned(CCW-1 downto 0);    -- control counter
    signal vc: unsigned(CCW-2 downto 0);    -- valid counter
    signal dly_in_data, dly_out_data: std_logic_vector(2*DataWidth-1 downto 0);
    signal dly_in_re, dly_in_im, dly_out_re, dly_out_im: std_logic_vector(DataWidth-1 downto 0);
    signal out_valid_i: std_logic;
    signal ifft_reg: std_logic;
    
begin
    
    cc <= ispl_cnt(CCW-1 downto 0);
    
    gen_nonbitrev: if BitReversedInput <= 0 generate
        mode <= cc(CCW-1) & cc(CCW-2);
    end generate;
    gen_bitrev: if BitReversedInput > 0 generate
        mode <= cc(CCW-2) & cc(CCW-1);
    end generate;

    BF : entity work.BF2_2
    generic map (
        InDataWidth => DataWidth
    )
    port map (
        clk       => clk,
        reset     => reset,
        mode      => mode,
        in_up_re  => dly_out_re,
        in_up_im  => dly_out_im,
        in_lo_re  => in_data_re,
        in_lo_im  => in_data_im,
        in_valid  => '1',   -- in_valid,
        ifft_in   => ifft_in,
        out_up_re => dly_in_re,
        out_up_im => dly_in_im,
        out_lo_re => out_data_re,
        out_lo_im => out_data_im,
        out_valid => open,  -- out_valid
        ifft_out  => open   -- ifft_out is handled separately
    );

    dly_in_data <= dly_in_im & dly_in_re;
    dly_out_re <= dly_out_data(DataWidth-1 downto 0);
    dly_out_im <= dly_out_data(2*DataWidth-1 downto DataWidth);

    delay_line : entity work.delay_line_fft
    generic map (
        Delay       => DELAY_LEN,
        InDataWidth => 2*DataWidth,
        UseRAM      => DELAY_USERAM
    )
    port map (
        clk       => clk,
        reset     => reset,
        in_data   => dly_in_data,
        in_valid  => '1',
        out_data  => dly_out_data,
        out_valid => open
    );    
    
    ctrl_counter_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ispl_cnt <= (others=>'0');
            else
                if in_valid = '0' then
                    ispl_cnt <= (others=>'0');
                else
                    if ispl_cnt = 0 then
                        ifft_reg <= ifft_in;    -- latch with the 0th data sample
                    end if;
                    ispl_cnt <= ispl_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    valid_counter_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ospl_cnt <= (others=>'0');
                out_valid_i <= '0';
            else
                -- out_valid
                if out_valid_i = '0' then
                    if ispl_cnt = OUT_VALID_START_TIME then
                        out_valid_i <= '1';
                        ifft_out <= ifft_reg;
                    end if;
                else
                    if ospl_cnt = FFTlen-1 then
                        if ispl_cnt /= OUT_VALID_START_TIME then
                            out_valid_i <= '0';                            
                        else
                            ifft_out <= ifft_reg;
                        end if;
                    end if;
                end if;

                -- valid counter
                if out_valid_i = '0' then
                    ospl_cnt <= (others=>'0');
                else
                    ospl_cnt <= ospl_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    vc <= ospl_cnt(CCW-2 downto 0);

    out_valid <= out_valid_i;
    cc_err <= '1' when (in_valid = '0' and reset = '0' and cc /= 0) else '0';
    spl_cnt_out <= std_logic_vector(ospl_cnt);
    
end architecture;