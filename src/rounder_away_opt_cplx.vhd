library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

-----------------------------------------------------------
-- Round away from zero or half to even (optimized for large fractional parts)

entity rounder_away_opt_cplx is
    generic(
        InWidth: integer;
        OutWidth: integer;   -- must be less than InWidth
        Mode: string := "HE"    -- HE - half to even, else away from zero
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        data_in_re: in std_logic_vector(InWidth-1 downto 0);   -- signed
        data_in_im: in std_logic_vector(InWidth-1 downto 0);   -- signed
        valid_in: in std_logic;
        data_out_re: out std_logic_vector(OutWidth-1 downto 0);
        data_out_im: out std_logic_vector(OutWidth-1 downto 0);
        valid_out: out std_logic
    );
end entity rounder_away_opt_cplx;

-----------------------------------------------------------

architecture rtl of rounder_away_opt_cplx is
begin
    
    round_proc_re : process(clk)
        variable preserved_re, preserved_im: unsigned(OutWidth-1 downto 0);
        variable round_term_re, round_term_im: unsigned(OutWidth-1 downto 0);
        variable disc_msb_re, disc_lsb_re: std_logic;
        variable disc_msb_im, disc_lsb_im: std_logic;
        variable msb_re, msb_im: std_logic;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                valid_out <= '0';
            else
                -- re
                if Mode = "HE" then
                    msb_re := data_in_re(InWidth-OutWidth);   -- round half to even
                else
                    msb_re := data_in_re(InWidth-1);     -- round away from zero
                end if;
                preserved_re := unsigned(data_in_re(InWidth-1 downto InWidth-OutWidth));    -- preserved bits, treat as unsigned
                disc_msb_re := data_in_re(InWidth-OutWidth-1);     -- most significant discarded bit
                disc_lsb_re := or_reduce(data_in_re(InWidth-OutWidth-2 downto 0));
                round_term_re := (others=>'0');
                if msb_re = '0' then    -- positive number
                    if preserved_re /= 2**(OutWidth-1)-1 then
                        round_term_re(0) := disc_msb_re;
                    else    -- largest positive number, do not add 1
                        round_term_re(0) := '0';
                    end if;
                else                    -- negative number, add 1 if frac /= -0.5
                    round_term_re(0) := disc_msb_re and disc_lsb_re;
                end if;
                data_out_re <= std_logic_vector(preserved_re + round_term_re);

                -- im
                if Mode = "HE" then
                    msb_im := data_in_im(InWidth-OutWidth);   -- round half to even
                else
                    msb_im := data_in_im(InWidth-1);     -- round away from zero
                end if;
                preserved_im := unsigned(data_in_im(InWidth-1 downto InWidth-OutWidth));    -- preserved bits, treat as unsigned
                disc_msb_im := data_in_im(InWidth-OutWidth-1);     -- most significant discarded bit
                disc_lsb_im := or_reduce(data_in_im(InWidth-OutWidth-2 downto 0));
                round_term_im := (others=>'0');
                if msb_im = '0' then    -- positive number
                    if preserved_im /= 2**(OutWidth-1)-1 then
                        round_term_im(0) := disc_msb_im;
                    else    -- largest positive number, do not add 1
                        round_term_im(0) := '0';
                    end if;
                else                    -- negative number, add 1 if frac /= -0.5
                    round_term_im(0) := disc_msb_im and disc_lsb_im;
                end if;
                data_out_im <= std_logic_vector(preserved_im + round_term_im);

                valid_out <= valid_in;
            end if;
        end if;
    end process;

end architecture;