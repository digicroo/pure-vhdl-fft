library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Radix 2^2 SDF FFT butterfly type II
-- https://doi.org/10.1109/IPPS.1996.508145

entity BF2_2 is
    generic(
        InDataWidth: integer
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        mode: in std_logic_vector(1 downto 0); -- X0 - passthrough, 01 - regular butterfly, 11 - *(-j) butterfly
        in_up_re: in std_logic_vector(InDataWidth-1 downto 0);
        in_up_im: in std_logic_vector(InDataWidth-1 downto 0);
        in_lo_re: in std_logic_vector(InDataWidth-1 downto 0);
        in_lo_im: in std_logic_vector(InDataWidth-1 downto 0);
        in_valid: in std_logic;
        ifft_in : in std_logic;
        out_up_re: out std_logic_vector(InDataWidth-1 downto 0);
        out_up_im: out std_logic_vector(InDataWidth-1 downto 0);
        out_lo_re: out std_logic_vector(InDataWidth-1 downto 0);
        out_lo_im: out std_logic_vector(InDataWidth-1 downto 0);
        out_valid: out std_logic;
        ifft_out : out std_logic
    );
end entity BF2_2;

-----------------------------------------------------------

architecture rtl of BF2_2 is

    signal lo_re_s, lo_im_s: signed(InDataWidth-1 downto 0);
    signal up_re_s, up_im_s: signed(InDataWidth-1 downto 0);

    signal lo_mux_re, lo_mux_im: signed(InDataWidth-1 downto 0);  -- lower cross-mux
    signal lo_mux_ctrl: std_logic;

    signal up_addsub_re, up_addsub_im: signed(InDataWidth-1 downto 0);
    signal lo_addsub_re, lo_addsub_im: signed(InDataWidth-1 downto 0);

    signal out_up_re_i: std_logic_vector(InDataWidth-1 downto 0);
    signal out_up_im_i: std_logic_vector(InDataWidth-1 downto 0);
    signal out_lo_re_i: std_logic_vector(InDataWidth-1 downto 0);
    signal out_lo_im_i: std_logic_vector(InDataWidth-1 downto 0);

    signal ifft_out_i: std_logic;
    signal out_mux_ctrl: std_logic;

begin

    lo_re_s <= resize(signed(in_lo_re), InDataWidth+0*1);
    lo_im_s <= resize(signed(in_lo_im), InDataWidth+0*1);
    up_re_s <= resize(signed(in_up_re), InDataWidth+0*1);
    up_im_s <= resize(signed(in_up_im), InDataWidth+0*1);

    lo_mux_ctrl <= mode(1) and mode(0);
    lo_mux_re <= lo_re_s when lo_mux_ctrl = '0' else lo_im_s;
    lo_mux_im <= lo_im_s when lo_mux_ctrl = '0' else lo_re_s;

    up_addsub_re <= up_re_s + lo_mux_re;
    up_addsub_im <= up_im_s + lo_mux_im when lo_mux_ctrl = '0' else up_im_s - lo_mux_im;
    lo_addsub_re <= up_re_s - lo_mux_re;
    lo_addsub_im <= up_im_s - lo_mux_im when lo_mux_ctrl = '0' else up_im_s + lo_mux_im;
    
    bf_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                out_valid <= '0';
            else
                if in_valid = '1' then
                    if mode(0) = '0' then  -- passthrough
                        out_up_re_i <= std_logic_vector(lo_mux_re);
                        out_up_im_i <= std_logic_vector(lo_mux_im);
                        out_lo_re_i <= std_logic_vector(up_re_s);
                        out_lo_im_i <= std_logic_vector(up_im_s);
                    else                -- butterfly
                        out_up_re_i <= std_logic_vector(lo_addsub_re);
                        out_up_im_i <= std_logic_vector(lo_addsub_im);
                        out_lo_re_i <= std_logic_vector(up_addsub_re);
                        out_lo_im_i <= std_logic_vector(up_addsub_im);
                    end if;
                end if;
                out_valid <= in_valid;
                ifft_out_i <= ifft_in;
                out_mux_ctrl <= lo_mux_ctrl and ifft_in;
            end if;
        end if;
    end process;

    -- FFT/IFFT mux
    -- when computing IFFT lower input is multiplied by +j instead of -j,
    -- which is equivalent to swapping upper and lower out
    out_up_re <= out_up_re_i when (out_mux_ctrl = '0') else out_lo_re_i;
    out_up_im <= out_up_im_i when (out_mux_ctrl = '0') else out_lo_im_i;
    out_lo_re <= out_lo_re_i when (out_mux_ctrl = '0') else out_up_re_i;
    out_lo_im <= out_lo_im_i when (out_mux_ctrl = '0') else out_up_im_i;
    ifft_out <= ifft_out_i;

end architecture;