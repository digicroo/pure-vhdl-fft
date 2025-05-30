library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;
--use work.utils_pkg.all;
use work.fft_sim_pkg.all;

-----------------------------------------------------------

entity TB_twiddle_gen_fft is
end entity TB_twiddle_gen_fft;

-----------------------------------------------------------

architecture testbench of TB_twiddle_gen_fft is

    function get_twiddle_num(re, im: real; nfft: integer) return integer is
        variable res: integer;
    begin
        res := integer(round(arctan(im, re) * (-real(nfft) / math_2_pi)));
        res := res mod nfft;
        return res;
    end function;

    -- clocks, resets
    constant CLK_FREQ : real := 10.0e6; 
    constant CLK_PERIOD : time := 1.0e9/CLK_FREQ * (1 ns); -- NS
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';

    constant FFTlen: integer := 64;
    constant TwiddleWidth: integer := 16;
    constant Stage: integer := 2;
    constant BitReversedInput: integer := 1;

    --other signals
    signal in_addr     : std_logic_vector(integer(ceil(log2(real(FFTlen))))-1 downto 0) := (others=>'0');
    signal out_data_re : std_logic_vector(TwiddleWidth-1 downto 0)                      := (others=>'0');
    signal out_data_im : std_logic_vector(TwiddleWidth-1 downto 0)                      := (others=>'0');    
    signal ifft: std_logic := '0';


    signal tw_re_tru, tw_im_tru, tw_re_tru_d, tw_im_tru_d: real := 0.0;
    signal err_re, err_im: real := 0.0;
    signal twgen_out_re_real, twgen_out_im_real: real := 0.0;
    signal twgen_out_twnum: integer;
    
    
    

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
    begin
        wait until rising_edge(clk);

        loop
            wait until rising_edge(clk);
            in_addr <= in_addr + 1;
        end loop;

    end process;

    check_proc : process
        variable tmp1, tmp2: real;
    begin
        wait until rising_edge(clk);

        loop
            wait until rising_edge(clk);
            tmp1 := real(to_integer(unsigned(in_addr)));
            tw_re_tru <= cos(-MATH_2_PI * tmp1 / real(FFTlen));
            tw_im_tru <= sin(-MATH_2_PI * tmp1 / real(FFTlen));

            tw_re_tru_d <= tw_re_tru;
            tw_im_tru_d <= tw_im_tru;
        end loop;
    end process;

    twgen_out_re_real <= real(to_integer(signed(out_data_re))) / (2.0**(TwiddleWidth-1));
    twgen_out_im_real <= real(to_integer(signed(out_data_im))) / (2.0**(TwiddleWidth-1));
    twgen_out_twnum <= get_twiddle_num(twgen_out_re_real, twgen_out_im_real, FFTlen);
    err_re <= twgen_out_re_real - tw_re_tru_d;
    err_im <= twgen_out_im_real - tw_im_tru_d;

    -----------------------------------------------------------
    -- Entity Under Test
    -----------------------------------------------------------

    twiddle_gen_fft_1 : entity work.twiddle_gen_fft
        generic map (
            TwiddleWidth => TwiddleWidth,
            FFTlen       => FFTlen,
            Stage        => Stage,
            BitReversedInput => BitReversedInput
        )
        port map (
            clk         => clk,
            reset       => reset,
            ifft        => ifft,
            in_addr     => in_addr,
            out_data_re => out_data_re,
            out_data_im => out_data_im
        );    
        
        
    dbg_proc: process
        variable k, k_inv: integer := -1;
        constant NBITS: integer := 4;
    begin
        loop
            wait until rising_edge(clk);
            k := k + 1;
            k_inv := reverse(k, NBITS);
        end loop;
    end process;

end architecture;