library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Twiddle factor generator for DIF FFT
-- latency 3

entity twiddle_gen_fft is
    generic(
        TwiddleWidth: integer;
        FFTlen: integer;
        Stage: integer;      -- 0 for 1st two stages, 1 for next two, etc.
        BitReversedInput: integer   -- 0 for natural FFT input, 1 for bit-reversed
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        ifft: in std_logic;     -- 0 for forward fft, 1 for inverse fft
        in_addr: in std_logic_vector(integer(ceil(log2(real(FFTlen))))-1 downto 0);
        out_data_re: out std_logic_vector(TwiddleWidth-1 downto 0);
        out_data_im: out std_logic_vector(TwiddleWidth-1 downto 0)
    );
end entity twiddle_gen_fft;

-----------------------------------------------------------

architecture rtl of twiddle_gen_fft is

    function reverse(vec: std_logic_vector) return std_logic_vector is
        constant L: integer := vec'length;
        variable input, res: std_logic_vector(L-1 downto 0) := vec;
    begin
        for k in input'range loop
            res(k) := input(L-1-k);
        end loop;
        return res;
    end function;

    type t_rom is array(integer range <>) of signed(2*TwiddleWidth-1 downto 0);
    constant AW: integer := integer(ceil(log2(real(FFTlen))));
    constant ROMSIZE: integer := FFTlen / (4**(Stage+1));
    constant ROMADDRBITS: integer := integer(ceil(log2(real(ROMSIZE))));

    function gen_twiddles(nfft, romsize: integer) return t_rom is
        variable res: t_rom(0 to romsize-1);
        constant TWW: integer := res(0)'length / 2;
        constant TWINT: integer := 2;   -- integer part bits
        variable tw_re, tw_im: real := 0.0;
        variable tw_re_s, tw_im_s: signed(TWW-1 downto 0);
    begin
        for k in res'range loop
            tw_re := cos(MATH_2_PI * 2.0**(2*Stage) * real(k) / real(nfft));
            tw_im := -sin(MATH_2_PI * 2.0**(2*Stage) * real(k) / real(nfft));
            tw_re_s := to_signed(integer(round(tw_re * (2.0**(TWW-TWINT)))), TWW);  -- 2 bits integer part
            tw_im_s := to_signed(integer(round(tw_im * (2.0**(TWW-TWINT)))), TWW);
            res(k) := tw_im_s & tw_re_s;
        end loop;
        return res;
    end function;

    signal twrom: t_rom(0 to ROMSIZE-1) := gen_twiddles(FFTlen, ROMSIZE);
    signal rom_out: signed(2*TwiddleWidth-1 downto 0);
    signal rom_out_re, rom_out_im: signed(TwiddleWidth-1 downto 0);
    signal wnum_ctrlb: std_logic_vector(1 downto 0);
    signal addr_d: std_logic_vector(2 downto 0);
    signal in_addr_rev: std_logic_vector(in_addr'range);
    signal w_num, w_num_shift: std_logic_vector(AW-1 downto 0);
    signal ifft_d: std_logic;
    
begin

    gen_shift_normal_input:
    if BitReversedInput <= 0 generate
        in_addr_rev <= in_addr;
    end generate;
    gen_shift_bitrev_input:
    if BitReversedInput > 0 generate
        in_addr_rev <= reverse(in_addr);
    end generate;

    wnum_ctrlb <= in_addr_rev(ROMADDRBITS+1 downto ROMADDRBITS);

    w_num_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                null;
            else
                case wnum_ctrlb is
                when "00" =>
                    w_num <= (others=>'0');
                when "01" =>
                    w_num <= std_logic_vector(resize(unsigned(in_addr_rev(ROMADDRBITS-1 downto 0)), AW) sll 1); -- x2
                when "10" =>
                    w_num <= std_logic_vector(resize(unsigned(in_addr_rev(ROMADDRBITS-1 downto 0)), AW));       -- x1
                when others =>
                    w_num <= std_logic_vector(
                        (resize(unsigned(in_addr_rev(ROMADDRBITS-1 downto 0)), AW) sll 1)
                        + resize(unsigned(in_addr_rev(ROMADDRBITS-1 downto 0)), AW)
                        );       -- x3
                end case;
                ifft_d <= ifft;
            end if;
        end if;
    end process;

    rom_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rom_out <= (others=>'0');
            else
                rom_out <= twrom(to_integer(unsigned(w_num(ROMADDRBITS-1 downto 0))));
            end if;
        end if;
    end process;

    rom_out_re <= rom_out(TwiddleWidth-1 downto 0);
    rom_out_im <= rom_out(2*TwiddleWidth-1 downto TwiddleWidth);

    tw_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                addr_d <= (others=>'0');
            else
                addr_d <= ifft_d & w_num(ROMADDRBITS+1 downto ROMADDRBITS);
                -- conjugate twiddles for ifft (inverse im sign)
                case addr_d is
                when "000" =>
                    out_data_re <= std_logic_vector(rom_out_re);
                    out_data_im <= std_logic_vector(rom_out_im);
                when "001" =>
                    out_data_re <= std_logic_vector(rom_out_im);
                    out_data_im <= std_logic_vector(-rom_out_re);
                when "010" =>
                    out_data_re <= std_logic_vector(-rom_out_re);
                    out_data_im <= std_logic_vector(-rom_out_im);
                when "011" =>
                    out_data_re <= std_logic_vector(-rom_out_im);
                    out_data_im <= std_logic_vector(rom_out_re);
                when "100" =>
                    out_data_re <= std_logic_vector(rom_out_re);
                    out_data_im <= std_logic_vector(-rom_out_im);
                when "101" =>
                    out_data_re <= std_logic_vector(rom_out_im);
                    out_data_im <= std_logic_vector(rom_out_re);
                when "110" =>
                    out_data_re <= std_logic_vector(-rom_out_re);
                    out_data_im <= std_logic_vector(rom_out_im);
                when "111" =>
                    out_data_re <= std_logic_vector(-rom_out_im);
                    out_data_im <= std_logic_vector(-rom_out_re);
                when others => null;
                end case;
            end if;
        end if;
    end process;

end architecture;