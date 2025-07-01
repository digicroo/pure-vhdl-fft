library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix-2^2 FFT stage with butterfly type 1


entity r22_stage_bf1 is
    generic(
        DataWidth: integer;
        FFTlen: integer;
        StagePairNum: integer;  -- 0 for 1st pair of stages, 1 for next pair, etc.
        BitReversedInput: integer;
        MaxShiftRegDelay: integer := 64
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;      -- must be block-wise
        scale_in: in std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);     -- must be block-wise
        out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_valid: out std_logic;
        ifft_out: out std_logic;
        scale_out: out std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);
        cc_err: out std_logic
    );
end entity r22_stage_bf1;

-----------------------------------------------------------

architecture rtl of r22_stage_bf1 is

    function get_subfft_len(fftlen, pairnum, bitrev: integer) return integer is
        variable res: integer;
    begin
        if bitrev <= 0 then -- natural input
            res := fftlen / 2**(2*pairnum);
        else    -- bitrev input
            res := 2**(2*pairnum+1);
        end if;
        return res;
    end function;

    constant FFTLEN_CUR: integer := get_subfft_len(FFTlen, StagePairNum, BitReversedInput);   -- length of sub-fft for current stage
    constant BF_LATENCY: integer := 1;
    constant DELAY_LEN: integer := FFTLEN_CUR / 2 - BF_LATENCY;
    constant DELAY_USERAM: integer := DELAY_LEN - MaxShiftRegDelay;
    constant CCW: integer := integer(log2(real(FFTLEN_CUR)));    -- control counter width
    constant OUT_VALID_START_TIME: integer := FFTLEN_CUR / 2 - 1 + BF_LATENCY;

    signal cc, vc: unsigned(CCW-1 downto 0);
    signal dly_in_data, dly_out_data: std_logic_vector(2*DataWidth-1 downto 0);
    signal dly_in_re, dly_in_im, dly_out_re, dly_out_im: std_logic_vector(DataWidth-1 downto 0);
    signal out_valid_i: std_logic;
    signal ifft_reg: std_logic;
    signal scale_reg: std_logic_vector(scale_in'length-1 downto 0);
    
begin

    BF : entity work.BF2_1
    generic map (
        InDataWidth => DataWidth
    )
    port map (
        clk       => clk,
        reset     => reset,
        mode      => cc(CCW-1),
        in_up_re  => dly_out_re,
        in_up_im  => dly_out_im,
        in_lo_re  => in_data_re,
        in_lo_im  => in_data_im,
        in_valid  => '1',   --in_valid,
        out_up_re => dly_in_re,
        out_up_im => dly_in_im,
        out_lo_re => out_data_re,
        out_lo_im => out_data_im,
        out_valid => open   --out_valid
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
                cc <= (others=>'0');
            else
                if in_valid = '0' then
                    cc <= (others=>'0');
                else
                    if cc = 0 then
                        ifft_reg <= ifft_in;    -- latch with the 0th data sample
                        scale_reg <= scale_in;
                    end if;
                    cc <= cc + 1;
                end if;
            end if;
        end if;
    end process;

    valid_counter_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                vc <= (others=>'0');
                out_valid_i <= '0';
            else
                -- out_valid
                if out_valid_i = '0' then
                    if cc = OUT_VALID_START_TIME then
                        out_valid_i <= '1';
                        ifft_out <= ifft_reg;
                        scale_out <= scale_reg;
                    end if;
                else
                    if vc = FFTLEN_CUR-1 then
                        if cc /= OUT_VALID_START_TIME then
                            out_valid_i <= '0';
                        else    -- no gap in in_valid
                            ifft_out <= ifft_reg;
                            scale_out <= scale_reg;
                        end if;
                    end if;
                end if;

                -- valid counter
                if out_valid_i = '0' then
                    vc <= (others=>'0');
                else
                    vc <= vc + 1;
                end if;
            end if;
        end if;
    end process;

    out_valid <= out_valid_i;
    cc_err <= '1' when (in_valid = '0' and reset = '0' and cc /= 0) else '0';

end architecture;