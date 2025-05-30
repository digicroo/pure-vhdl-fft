library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

-----------------------------------------------------------
-- Delay line 

entity delay_line_fft is
    generic(
        Delay: integer;
        InDataWidth: integer;
        UseRAM: integer     -- 0 or 1. In RAM mode in_valid doesn't matterout_valid is always high 
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        in_data: in std_logic_vector(InDataWidth-1 downto 0);
        in_valid: in std_logic;
        out_data: out std_logic_vector(InDataWidth-1 downto 0);
        out_valid: out std_logic
    );
end entity delay_line_fft;

-----------------------------------------------------------

architecture rtl of delay_line_fft is

    function clog2_nonneg(x: integer) return integer is
        variable res: integer;
    begin
        if x > 0 then
            res := integer(ceil(log2(real(x))));
        else
            res := 0;
        end if;
        return res;
    end function;

    type t_dl is array(integer range <>) of std_logic_vector(InDataWidth downto 0);

    signal dl: t_dl(Delay-1 downto 0);
    signal dl_in: std_logic_vector(InDataWidth downto 0);

    -- ram mode
    constant ADDRW: integer := clog2_nonneg(Delay);
    constant RAMLEN: integer := 2**ADDRW;
    signal wp, rp: unsigned(ADDRW-1 downto 0);
    type t_ram is array(integer range <>) of std_logic_vector(InDataWidth-1 downto 0);
    signal ram: t_ram(0 to RAMLEN-1);
    signal out_data_i: std_logic_vector(InDataWidth-1 downto 0);
    
begin

    gen_zero: if Delay = 0 generate
    begin
        out_data <= in_data;
        out_valid <= in_valid;
    end generate gen_zero;

    gen_shiftreg: if Delay > 0 and UseRAM <= 0 generate
    begin
        dl_in <= in_valid & in_data;
        out_data <= dl(Delay-1)(InDataWidth-1 downto 0);
        out_valid <= dl(Delay-1)(InDataWidth);
        
        sr_proc : process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    dl <= (others=>(others=>'0'));
                else
                    dl <= dl(Delay-2 downto 0) & dl_in;
                end if;
            end if;
        end process;
    end generate gen_shiftreg;

    gen_ram: if Delay > 0 and UseRAM > 0 generate
        ram_proc: process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    rp <= to_unsigned(2**ADDRW-Delay+1+1, ADDRW);   -- +1 for output reg
                    wp <= (others=>'0');
                else
                    ram(to_integer(wp)) <= in_data;
                    wp <= wp + 1;
                    out_data_i <= ram(to_integer(rp));
                    rp <= rp + 1;
                    out_data <= out_data_i;
                end if;
            end if;
        end process;
        out_valid <= '1';
    end generate gen_ram;

end architecture;