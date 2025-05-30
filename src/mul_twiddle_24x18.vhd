library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Multiplier for twiddle factors at input 2
-- in_re2 + in_im2 must be less than 2^17-1
-- latency 4

entity mul_twiddle_24x18 is
    generic(
        UserWidth: integer := 1
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        user_in: in std_logic_vector(UserWidth-1 downto 0);
        user_out: out std_logic_vector(UserWidth-1 downto 0);
        in_re1: in std_logic_vector(23 downto 0);
        in_im1: in std_logic_vector(23 downto 0);
        in_re2: in std_logic_vector(17 downto 0);
        in_im2: in std_logic_vector(17 downto 0);
        in_valid: in std_logic;
        out_re: out std_logic_vector(42 downto 0);
        out_im: out std_logic_vector(42 downto 0);
        out_valid: out std_logic
    );
end entity mul_twiddle_24x18;

-----------------------------------------------------------

architecture rtl of mul_twiddle_24x18 is

    attribute use_dsp: string;

    constant Latency: integer := 4; 
    
    type t_usrdl is array(integer range<>) of std_logic_vector(UserWidth-1 downto 0);
    signal dl_usr: t_usrdl(1 to Latency);
    
    signal dl_valid: std_logic_vector(1 to Latency);

    signal a, b, a_del, b_del:  signed(24 downto 0);
    signal c, d, c_del:         signed(17 downto 0);
    signal sum1:                signed(24 downto 0);
    signal sum2, sum3:          signed(17 downto 0);
        --attribute use_dsp of sum2: signal is "yes";
    signal k1, k2, k3:          signed(42 downto 0);

    signal mul_out_re, mul_out_im: signed(42 downto 0);
    
begin

    -- (a + jb) * (c + jd) = ac-bd + j*(bc+ad)
    -- k1 = c * (a+b);      18 * 25
    -- k2 = a * (d-c);      25 * 18
    -- k3 = b * (c+d);      25 * 18
    -- (a + jb) * (c + jd) = k1-k3 + j*(k1+k2)

    mul_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                dl_valid <= (others=>'0');
            else
                dl_valid <= in_valid & dl_valid(1 to Latency-1);
                dl_usr <= user_in & dl_usr(1 to Latency-1);

                a <= resize(signed(in_re1), 25);
                b <= resize(signed(in_im1), 25);
                c <= signed(in_re2);
                d <= signed(in_im2);

                sum1 <= a + b;  -- 25bit
                sum2 <= d - c;  -- 18
                sum3 <= c + d;  -- 18
                c_del <= c;     -- 18
                a_del <= a;     -- 25
                b_del <= b;     -- 25

                k1 <= c_del * sum1;     -- 43
                k2 <= a_del * sum2;
                k3 <= b_del * sum3;

                mul_out_re <= k1 - k3;
                mul_out_im <= k1 + k2;  -- with dl_valid(4)
            end if;
        end if;
    end process;

    out_re <= std_logic_vector(mul_out_re);
    out_im <= std_logic_vector(mul_out_im);
    out_valid <= dl_valid(Latency);
    user_out <= dl_usr(Latency);

end architecture;