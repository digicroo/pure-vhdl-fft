library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix 2^2 SDF FFT butterfly type I
-- https://doi.org/10.1109/IPPS.1996.508145

entity BF2_1 is
    generic(
        InDataWidth: integer
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        mode: in std_logic; -- 0 - passthrough, 1 - butterfly
        in_up_re: in std_logic_vector(InDataWidth-1 downto 0);
        in_up_im: in std_logic_vector(InDataWidth-1 downto 0);
        in_lo_re: in std_logic_vector(InDataWidth-1 downto 0);
        in_lo_im: in std_logic_vector(InDataWidth-1 downto 0);
        in_valid: in std_logic;
        out_up_re: out std_logic_vector(InDataWidth-1 downto 0);
        out_up_im: out std_logic_vector(InDataWidth-1 downto 0);
        out_lo_re: out std_logic_vector(InDataWidth-1 downto 0);
        out_lo_im: out std_logic_vector(InDataWidth-1 downto 0);
        out_valid: out std_logic
    );
end entity BF2_1;

-----------------------------------------------------------

architecture rtl of BF2_1 is

    signal lo_re_s, lo_im_s: signed(InDataWidth-1 downto 0);
    signal up_re_s, up_im_s: signed(InDataWidth-1 downto 0);

begin

    lo_re_s <= resize(signed(in_lo_re), InDataWidth);
    lo_im_s <= resize(signed(in_lo_im), InDataWidth);
    up_re_s <= resize(signed(in_up_re), InDataWidth);
    up_im_s <= resize(signed(in_up_im), InDataWidth);
    
    bf_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                out_valid <= '0';
            else
                if in_valid = '1' then
                    if mode = '0' then  -- passthrough
                        out_up_re <= std_logic_vector(lo_re_s);
                        out_up_im <= std_logic_vector(lo_im_s);
                        out_lo_re <= std_logic_vector(up_re_s);
                        out_lo_im <= std_logic_vector(up_im_s);
                    else                -- butterfly
                        out_up_re <= std_logic_vector(up_re_s - lo_re_s);
                        out_up_im <= std_logic_vector(up_im_s - lo_im_s);
                        out_lo_re <= std_logic_vector(up_re_s + lo_re_s);
                        out_lo_im <= std_logic_vector(up_im_s + lo_im_s);
                    end if;
                end if;
                out_valid <= in_valid;
            end if;
        end if;
    end process;

end architecture;