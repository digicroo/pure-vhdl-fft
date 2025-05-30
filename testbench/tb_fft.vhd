library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.utils_pkg.all;
use work.fft_sim_pkg.all;
use work.LD_package.all;
library std;
use std.env.finish;

-----------------------------------------------------------

entity TB_fft is
end entity TB_fft;

-----------------------------------------------------------

architecture testbench of TB_fft is

    procedure uniform_range(
        seed1, seed2: inout integer;
        lo, hi: in integer;
        u: out integer) is
        variable ureal: real;
    begin
        uniform(seed1, seed2, ureal);
        u := integer(floor(ureal * real(hi-lo) + real(lo)));
    end procedure;

    function get_twiddle_num(re, im: real; nfft: integer) return integer is
        variable res: integer;
    begin
        res := integer(round(arctan(im, re) * (-real(nfft) / math_2_pi)));
        res := res mod nfft;
        return res;
    end function;
    
    function gen_datavec(len: integer) return cplx_vec is
        variable res: cplx_vec(0 to len-1);
        variable f: real := 1.0/8.0;
    begin
        
        for k in res'range loop
            --res(k).re := real(k) * 100.0;
            --res(k).im := 0.0;
            res(k).re := 0.0;
            res(k).im := 0.0;
            --res(k).re := round(32767.0/2.0 * cos(MATH_2_PI * f * real(k)));
            --res(k).im := round(32767.0/2.0 * sin(MATH_2_PI * f * real(k)));
        end loop;
        res(16).re := 32767.0;
        res(16).im := 32767.0;
        return res;
    end function;
    
    function gen_datavec_noise(len: integer; maxval: integer; s1,s2:integer) return cplx_vec is
    -- len - length of the resulting array
    -- maxval - values are constrained to +-maxval
    -- s1,s2 - seeds for uniform
        variable res: cplx_vec(0 to len-1);
        variable f: real := 1.0/8.0;
        variable seed1, seed2: integer;
        variable rnd: real;
    begin
        seed1 := s1;
        seed2 := s2;
        for k in res'range loop
            uniform(seed1, seed2, rnd);
            res(k).re := round(real(maxval) * (rnd * 2.0 - 1.0));
            uniform(seed1, seed2, rnd);
            res(k).im := round(real(maxval) * (rnd * 2.0 - 1.0));
        end loop;
        return res;
    end function;

    -- clocks, resets
    constant CLK_FREQ : real := 10.0e6; 
    constant CLK_PERIOD : time := 1.0e9/CLK_FREQ * (1 ns); -- NS
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';

    -----------------------------------------------------------
    -----------------------------------------------------------
    constant DataWidth: integer := 16;
    constant FFTlen: integer := 16;
    constant TwiddleWidth: integer := 18;
    constant BitReversedInput: integer := 1;
    constant MIN_PAUSE: integer := 1;
    constant MAX_PAUSE: integer := 10;
    constant MAX_BLOCKS: integer := 10000;     -- blocks to simulate
    -----------------------------------------------------------
    -----------------------------------------------------------
    constant LOGLEN: integer := integer(log2(real(FFTlen)));

    --other signals
    signal in_addr     : std_logic_vector(integer(ceil(log2(real(FFTlen))))-1 downto 0) := (others=>'0');
    signal out_data_re : std_logic_vector(DataWidth-1 downto 0)                      := (others=>'0');
    signal out_data_im : std_logic_vector(DataWidth-1 downto 0)                      := (others=>'0');    


    signal tw_re_tru, tw_im_tru, tw_re_tru_d, tw_im_tru_d: real := 0.0;
    signal err_re, err_im: real := 0.0;
    signal twgen_out_re_real, twgen_out_im_real: real := 0.0;
    signal twgen_out_twnum: integer;
    
    signal in_data_re     : std_logic_vector(DataWidth-1 downto 0)                          := (others=>'0');
    signal in_data_im     : std_logic_vector(DataWidth-1 downto 0)                          := (others=>'0');
    signal in_data_valid  : std_logic                                                       := '0';
    signal out_data_valid : std_logic                                                       := '0';
    signal ifft_in, ifft_out: std_logic;
    signal cc_err_out     : std_logic;
    
    --shared variable xf: cplx_vec(0 to FFTlen-1) := (others=>(re=>0.0, im=>0.0));
--    signal fft_diff_re, fft_diff_im: std_logic_vector(DataWidth-1 downto 0);
    signal xf_re, xf_im, xf_delayed_re, xf_delayed_im: real;
    signal xf_valid: std_logic := '0';
    signal stop: boolean := false;
    
    signal out_re_d, out_im_d: std_logic_vector(DataWidth-1 downto 0);
    signal out_valid_d: std_logic;

    type fft_transaction is record
        inv: integer;
        fft_in: cplx_vec(0 to FFTlen-1);
        fft_out: cplx_vec(0 to FFTlen-1);
        abort: integer; -- flag that transaction is aborted (valid released before last sample), 0 or 1
        abort_index: integer;   -- index of the last sample in the transaction if abort = 1
    end record;

    type transaction_array is array (integer range <>) of fft_transaction;
    constant NULL_TR: fft_transaction := (
        inv => 0,
        fft_in => (0 to FFTlen-1 => (re=>0.0, im=>0.0)),
        fft_out => (0 to FFTlen-1 => (re=>0.0, im=>0.0)),
        abort => 0,
        abort_index => 0
    );

    type fft_tr_queue is protected
        procedure push(tr: fft_transaction);
        procedure reset;
        impure function pull return fft_transaction;
        impure function pull_tail return fft_transaction;
        impure function is_empty return boolean;
        impure function is_full return boolean;
    end protected;
    type fft_tr_queue is protected body
        constant Q_SIZE: integer := 100;
        variable q: transaction_array(0 to Q_SIZE-1) := (others=>NULL_TR);
        variable wp, rp, count: integer := 0;

        procedure push(tr: fft_transaction) is
        begin
            if count = Q_SIZE then
                report "QUEUE ERROR: push to full" severity ERROR;
                return;
            end if;
            q(wp) := tr;
            wp := (wp + 1) mod Q_SIZE;
            count := count + 1;
        end procedure;
        
        procedure reset is
        begin
            wp := 0;
            rp := 0;
            count := 0;
        end procedure;

        impure function pull return fft_transaction is
            variable res: fft_transaction := NULL_TR;
        begin
            if count = 0 then
                report "QUEUE ERROR: pull from empty" severity ERROR;
                return NULL_TR;
            end if;
            res := q(rp);
            rp := (rp + 1) mod Q_SIZE;
            count := count - 1;
            return res;
        end function;
        
        impure function pull_tail return fft_transaction is -- pull from the tail of the queue (get last pushed item)
            variable res: fft_transaction := NULL_TR;
        begin
            if count = 0 then
                report "QUEUE ERROR: pull_tail from empty" severity ERROR;
                return NULL_TR;
            end if;
            wp := (wp - 1) mod Q_SIZE;
            res := q(wp);
            count := count - 1;
            return res;
        end function;
        
        impure function is_empty return boolean is
        begin
            return count = 0;
        end function;
        
        impure function is_full return boolean is
        begin
            return count = Q_SIZE;
        end function;
    end protected body;
    
    shared variable tr_queue: fft_tr_queue;
    signal blocks_sent: boolean := false;
    

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
        variable x: cplx_vec(0 to FFTlen-1) := (others=>(re=>0.0, im=>0.0));
        variable s1, s2: integer;
        variable pause, inv, abort, abort_idx: integer;
        variable fft_tr: fft_transaction := NULL_TR;
        variable xf: cplx_vec(0 to FFTlen-1) := (others=>(re=>0.0, im=>0.0));
    begin
        s1 := 666;
        s2 := 900;
        wait until rising_edge(clk);
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        for blk in 1 to MAX_BLOCKS loop
            --report ">>>> Block #" & integer'image(blk);
            -- get pause duration after this block
            uniform_range(s1, s2, MIN_PAUSE, MAX_PAUSE, pause);
            --uniform_range(s1, s2, 0, 2, inv);   -- inv is fft(0)/ifft(1) flag
            uniform_range(s1, s2, -5, 2, abort);   -- premature interruption flag
            uniform_range(s1, s2, 0, FFTlen-1, abort_idx);   -- last sample index, 0 to FFTlen-2
            inv := 0;
            -- generate block
            if inv = 0 then
                x := gen_datavec_noise(FFTlen, 23169, s1, s2);
                --x := gen_datavec(FFTlen);
            else
                x := gen_datavec_noise(FFTlen, (2**DataWidth)/FFTlen/4, s1, s2);
                --x := gen_datavec(FFTlen);
            end if;
            xf := fft(x, inv, BitReversedInput, 1-inv);
            if BitReversedInput > 0 then
                x := reorder(x);    -- make input in bit-reversed order
            end if;
            -- push transaction to queue
            fft_tr := NULL_TR;
            fft_tr.fft_in := x;
            fft_tr.fft_out := xf;
            fft_tr.inv := inv;
            fft_tr.abort := abort;
            fft_tr.abort_index := abort_idx;
            if fft_tr.abort <= 0 then
                tr_queue.push(fft_tr);
            end if;
            -- send FFT block
            for k in x'range loop
                in_data_valid <= '1';
                if inv <= 0 then
                    ifft_in <= '0';
                else
                    ifft_in <= '1';
                end if;
                in_data_re <= real2slv(x(k).re, DataWidth);
                in_data_im <= real2slv(x(k).im, DataWidth);
                xf_re <= xf(k).re;
                xf_im <= xf(k).im;
                wait until rising_edge(clk);
                if fft_tr.abort >= 1 then    --and fft_tr.abort_index = k then
                    reset <= '1';
                    tr_queue.reset;
                    wait until rising_edge(clk);
                    reset <= '0';
                    exit;
                end if;
            end loop;
            -- generate pause
            if pause /= 0 then
                in_data_valid <= '0';
                for k in 1 to pause loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;
        
        blocks_sent <= true;
        
        wait;

    end process;
    

    fft_check_proc : process
        variable stop: boolean := false;
        variable fft_ix, out_blk_ix: integer := 0;
        variable fft_out, fft_diff: cplx_vec(0 to FFTlen-1);
        variable tr: fft_transaction := NULL_TR;
        variable max_max_err, cur_max_err: real;
        variable mean_mean_err_re, mean_mean_err_im, cur_mean_err_re, cur_mean_err_im: real;
        variable mean_err_vec_re: real_vec(0 to MAX_BLOCKS-1) := (others=>10000.0);
        variable mean_err_vec_im: real_vec(0 to MAX_BLOCKS-1) := (others=>10000.0);
        variable cur_std_err, std_err: real;
        variable std_err_vec: real_vec(0 to MAX_BLOCKS-1) := (others=>10000.0);
        variable fft_tru_re, fft_tru_im, fft_diff_re, fft_diff_im: real;
        variable cur_max_idx: integer;
    begin
        max_max_err := 0.0;
    
        loop
            wait until rising_edge(clk);
            out_re_d <= out_data_re;
            out_im_d <= out_data_im;
            out_valid_d <= out_data_valid;
            
            if out_data_valid /= '1' then
                fft_ix := 0;
                fft_diff_re := slv2real(out_data_re) - fft_tru_re;
                fft_diff_im := slv2real(out_data_im) - fft_tru_im;
            else
                if fft_ix = 0 then
                    tr := tr_queue.pull;
                end if;
                fft_tru_re := tr.fft_out(fft_ix).re;
                fft_tru_im := tr.fft_out(fft_ix).im;
                
                fft_out(fft_ix).re := slv2real(out_data_re);
                fft_out(fft_ix).im := slv2real(out_data_im);
                if (fft_ix = FFTlen-1) then
                    -- last out sample ---------------------------------
                    fft_diff := fft_out - tr.fft_out;
                    -- max err
                    --cur_max_err := max(absr( re(fft_diff) & im(fft_diff) ));
                    cur_max_err := max(absc(fft_diff));
                    cur_max_idx := max_index(absc(fft_diff));
                    if cur_max_err > max_max_err then max_max_err := cur_max_err; end if;
                    -- mean err
                    mean_err_vec_re(out_blk_ix) := mean(re(fft_diff));
                    mean_mean_err_re := mean(mean_err_vec_re(0 to out_blk_ix));
                    mean_err_vec_im(out_blk_ix) := mean(im(fft_diff));
                    mean_mean_err_im := mean(mean_err_vec_im(0 to out_blk_ix));
                    -- mean square err
                    cur_std_err := sqrt(mean(absc(fft_diff) * absc(fft_diff)));
                    std_err_vec(out_blk_ix) := cur_std_err;
                    std_err := sqrt(mean( std_err_vec(0 to out_blk_ix)*std_err_vec(0 to out_blk_ix) ));
                    
                    report ">>>> Block #" & integer'image(out_blk_ix);
                    report ">>>>> max err = " & real'image(max_max_err) & " LSB @ index " & integer'image(cur_max_idx) & ",   mean sq err = " & real'image(std_err) & " LSB";
                    
                    ------------------------------------------------------
                    out_blk_ix := out_blk_ix + 1;
                end if;
                
                fft_diff_re := slv2real(out_data_re) - fft_tru_re;
                fft_diff_im := slv2real(out_data_im) - fft_tru_im;
                
                fft_ix := (fft_ix + 1) mod FFTlen;
                stop := (out_blk_ix = MAX_BLOCKS) or (blocks_sent and tr_queue.is_empty);
                
            end if;
            
            
            if stop then
                report ">>>> SIMULATION END. After " & integer'image(out_blk_ix+1) & " blocks MAX ERROR = " & real'image(max_max_err) & " LSB";
                report ">>>> MEAN ERROR Re = " & real'image(mean_mean_err_re) & " LSB";
                report ">>>> MEAN ERROR Im = " & real'image(mean_mean_err_im) & " LSB";
                report ">>>> RMS ERROR = " & real'image(std_err) & " LSB";
                finish;
            end if;
        end loop;
    end process;
    
    
    
    
    ----------------------------------------------------------------------------

    UUT : entity work.fft2
    generic map (
        DataWidth        => DataWidth,
        TwiddleWidth     => TwiddleWidth,
        FFTlen           => FFTlen,
        BitReversedInput => BitReversedInput
    )
    port map (
        clk            => clk,
        reset          => reset,
        in_data_re     => in_data_re,
        in_data_im     => in_data_im,
        in_data_valid  => in_data_valid,
        ifft_in        => ifft_in,
        out_data_re    => out_data_re,
        out_data_im    => out_data_im,
        out_data_valid => out_data_valid,
        ifft_out       => ifft_out,
        cc_err_out     => cc_err_out
    ); 
    
    
--    UUT: entity work.DIF_4096
--    generic map(                 -- Decimation in frequency, Natural order -> Bit-reversed order
--        IsInverse   => true,              -- FFT/IFFT when false/true
--        CoefWidth   => 18,              -- |coef|=2**(Re'length-2), max positive 010...0, max negative is 110..0
--        KeepLsb     => true,              -- True - Remove MSB, False - Remove LSB
--        Is4096      => true               -- True - 4096, False - 1024
--    )
--    port map(
--        Clk         => clk,
--        Reset       => reset,
--    
--        InEna       => in_data_valid,         -- =0 - init, then =1 during 4096 samples with no gap, then can be the next 4096 samples or pause (=0 zero or more cycles)
--        InData.Re   => in_data_re,           -- Len is 17, Re/Im=-65535!!!!!...+65535, Module is limited 65535!!!!!!!!!!
--        InData.Im   => in_data_im,
--    
--        OutEna      => out_data_valid,        -- Latency from InEna is 4143
--        OutData.Re  => out_data_re,          -- Len is 17
--        OutData.Im  => out_data_im,
--    
--        Ovf         => open         -- not aligned to InData or OutData - simple output of the internal Butterfly
--    );  
    

end architecture;