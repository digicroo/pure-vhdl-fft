library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;
--use work.utils_pkg.all;
use work.fft_sim_pkg.all;

-----------------------------------------------------------

entity TB_rounder is
end entity TB_rounder;

-----------------------------------------------------------

architecture testbench of TB_rounder is

    function get_twiddle_num(re, im: real; nfft: integer) return integer is
        variable res: integer;
    begin
        res := integer(round(arctan(im, re) * (-real(nfft) / math_2_pi)));
        res := res mod nfft;
        return res;
    end function;
    
    function round_he(x: real) return real is
        variable res, frac, int, odd: real;
    begin
        int := trunc(x);
        frac := x - int;
        odd := real(integer(trunc(x)) mod 2);
        if frac = 0.5 or frac = -0.5 then
            res := int + odd*sign(x);
        else
            res := round(x);
        end if;
        return res;
    end function;

    -- clocks, resets
    constant CLK_FREQ : real := 10.0e6; 
    constant CLK_PERIOD : time := 1.0e9/CLK_FREQ * (1 ns); -- NS
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    
    constant InWidth: integer := 5;
    constant OutWidth: integer := 4;

    signal data_in_re  : std_logic_vector(InWidth-1 downto 0)  := (others=>'0');
    signal data_in_im  : std_logic_vector(InWidth-1 downto 0)  := (others=>'0');
    signal valid_in    : std_logic                             := '0';
    signal data_out_re : std_logic_vector(OutWidth-1 downto 0) := (others=>'0');
    signal data_out_im : std_logic_vector(OutWidth-1 downto 0) := (others=>'0');
    signal valid_out   : std_logic                             := '0';
    
    
    

begin
    -----------------------------------------------------------
    -- Clocks
    -----------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2; 

    -----------------------------------------------------------
    -- Testbench Stimulus
    -----------------------------------------------------------
    TB_proc : process
        variable cnt: integer := 0;
        variable real_in, real_out: real := -5.0;
    begin
        data_in_re <= (others=>'0');
        wait until rising_edge(clk);
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';


        loop
            wait until rising_edge(clk);
            valid_in <= '1';
            data_in_re <= data_in_re + 1;
            real_in := real_in + 0.25;
            real_out := round_he(real_in);
        end loop;

    end process;


    -----------------------------------------------------------
    -- Entity Under Test
    -----------------------------------------------------------

    rounder_away_opt_cplx_1 : entity work.rounder_away_opt_cplx
        generic map (
            InWidth  => InWidth,
            OutWidth => OutWidth
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in_re  => data_in_re,
            data_in_im  => "00000",
            valid_in    => valid_in,
            data_out_re => data_out_re,
            data_out_im => open,
            valid_out   => valid_out
        );    

end architecture;