library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;

package fft_sim_pkg is

    type int_vec is array(integer range <>) of integer;
    type real_vec is array(integer range <>) of real;
    type cplx is record
        re: real;
        im: real;
    end record;
    type cplx_vec is array(integer range <>) of cplx;
    
    procedure uniform_range(
        seed1, seed2: inout integer;
        lo, hi: in integer;
        u: out integer);
    procedure generate_scaling_sch(
        seed1,seed2: inout integer;
        fftlen: in integer;
        sch: out std_logic_vector;
        total_scaling: out integer);
        
    function get_scaling_sch(fftlen, total_scaling: integer) return std_logic_vector;
    function min(a,b: integer) return integer;

    function real2slv(x: real; width: integer) return std_logic_vector;
    function real2slv(x: real; width: integer; frac: integer) return std_logic_vector;
    function slv2real(x: std_logic_vector) return real;
    function slv2real(x: std_logic_vector; frac: integer) return real;
    function clog2(x: integer) return integer;
    function reverse(vec: std_logic_vector) return std_logic_vector;
    function reverse(num: integer; nbits: integer) return integer;
    function reorder(idata: real_vec) return real_vec;  -- bit-reversed to natural reordering (and vise versa)
    function reorder(idata: cplx_vec) return cplx_vec;
    function reorder(idata: cplx_vec; nchan: integer) return cplx_vec;
    function tw(n, fftlen, ifft: integer) return cplx;
    function "+"(a,b: cplx) return cplx;
    function "-"(a,b: cplx) return cplx;
    function "*"(a,b: cplx) return cplx;
    function "+"(a,b: cplx_vec) return cplx_vec;
    function "-"(a,b: cplx_vec) return cplx_vec;
    function "*"(a,b: cplx_vec) return cplx_vec;
    function "+"(a,b: real_vec) return real_vec;
    function "-"(a,b: real_vec) return real_vec;
    function "*"(a,b: real_vec) return real_vec;
    function re(a: cplx_vec) return real_vec;   -- get real part
    function im(a: cplx_vec) return real_vec;   -- get imaginary part
    function absr(a: real_vec) return real_vec; -- abs for real vector
    function absc(a: cplx_vec) return real_vec; -- abs for complex vector
    function max(a: real_vec) return real;
    function max_index(a: real_vec) return integer;
    function mean(a: real_vec) return real;
    function fft(idata: cplx_vec; inv, reord, scale: integer) return cplx_vec;
    function fft_multich(x: cplx_vec; n_chan: integer; inv, reord, scale: integer) return cplx_vec;
    
end package fft_sim_pkg;

package body fft_sim_pkg is

    procedure uniform_range(
        seed1, seed2: inout integer;
        lo, hi: in integer; -- hi excluded
        u: out integer) is
        
        variable ureal: real;
    begin
        uniform(seed1, seed2, ureal);
        u := integer(floor(ureal * real(hi-lo) + real(lo)));
    end procedure;
    
    -- generate random valid scaling schedule
    procedure generate_scaling_sch(
        seed1,seed2: inout integer;
        fftlen: in integer;
        sch: out std_logic_vector;
        total_scaling: out integer) is
        
        constant STAGES: integer := integer(ceil(log2(real(fftlen))/2.0));
        constant SCALING_LEN: integer := STAGES * 2;
        variable res: std_logic_vector(SCALING_LEN-1 downto 0);
        variable single_scl, total_scl: integer;
    begin
        total_scl := 1;
        for k in 0 to STAGES-1 loop
            if STAGES mod 2 /= 0 and k = STAGES-1 then
                uniform_range(seed1, seed2, 0, 2, single_scl);   -- scaling for single stage from 0 to 1
            else
                uniform_range(seed1, seed2, 0, 3, single_scl);   -- scaling for single stage from 0 to 2
            end if;
            res(2*k+1 downto 2*k) := std_logic_vector(to_unsigned(single_scl, 2));
            total_scl := total_scl * 2**single_scl;
        end loop;
        sch := res;
        total_scaling := total_scl;
    end procedure;
    
    -- generate scaling schedule from fft length and desired scaling factor
    function get_scaling_sch(fftlen, total_scaling: integer) return std_logic_vector is
        constant LOGLEN: integer := integer(log2(real(fftlen)));
        constant STAGES: integer := integer(ceil(log2(real(fftlen))/2.0));
        constant SCALING_LEN: integer := STAGES * 2;
        variable res: std_logic_vector(SCALING_LEN-1 downto 0);
        variable scale_rem: integer := integer(log2(real(total_scaling)));    -- remaining scaling
        variable scale_cur: integer;    -- scaling for current stage
    begin
        for k in STAGES-1 downto 0 loop
            if k = STAGES-1 then    -- last stage
                if LOGLEN mod 2 /= 0 then   -- odd number of stages, last stage scaling must be 0 or 1
                    scale_cur := min(scale_rem, 1);
                else    -- last stage scaling can be 0, 1 or 2
                    scale_cur := min(scale_rem, 2);
                end if;
            else    -- non-last stage
                scale_cur := min(scale_rem, 2);
            end if;
            res(2*k+1 downto 2*k) := std_logic_vector(to_unsigned(scale_cur, 2));
            scale_rem := scale_rem - scale_cur;
        end loop;
        return res;
    end function;
    
    function min(a,b: integer) return integer is
    begin
        if a > b then return b;
        else return a;
        end if;
    end;

    -- convert real to std_logic_vector
    function real2slv(x: real; width: integer) return std_logic_vector is
        variable tmp: real;
        variable res: std_logic_vector(width-1 downto 0) := (others=>'0');
        variable neg: boolean;
    begin
        if x < 0.0 then
            neg := true;
            tmp := floor(-x);
        else
            neg := false;
            tmp := floor(x);
        end if;
        for k in 0 to width-1 loop
            --report integer'image(k) & ": " & real'image(tmp) & "   " & real'image(tmp mod 2.0);
            if (tmp mod 2.0) > 0.5 then
                res(k) := '1';
            else
                res(k) := '0';
            end if;
            tmp := floor(tmp / 2.0);
        end loop;
        if neg then
            res := (not res) + 1;
        end if;
        return res;
    end function;
    
    function real2slv(x: real; width: integer; frac: integer) return std_logic_vector is
    begin
        return real2slv(round(x * 2.0**frac), width);
    end function;

    -- convert signed slv to real
    function slv2real(x: std_logic_vector) return real is
        variable res: real := 0.0;
        variable xx: std_logic_vector(x'length-1 downto 0) := x;
        variable neg: boolean := false;
    begin
        if xx(xx'left) = '1' then
            neg := true;
            xx := (not xx) + 1;
        end if;
        
        for k in 0 to xx'length-1 loop
            res := res + real(to_integer(unsigned(xx(k downto k)))) * 2.0**k;
        end loop;
        
        if neg then
            res := -res;
        end if;
        return res;
    end function;
    
    -- convert signed fixed point slv to real
    function slv2real(x: std_logic_vector; frac: integer) return real is
        variable res: real := 0.0;
        variable xx: std_logic_vector(x'length-1 downto 0) := x;
        variable neg: boolean := false;
    begin
        if xx(xx'left) = '1' then
            neg := true;
            xx := (not xx) + 1;
        end if;
        
        for k in 0 to xx'length-1 loop
            res := res + real(to_integer(unsigned(xx(k downto k)))) * 2.0**k;
        end loop;
        
        if neg then
            res := -res;
        end if;
        return res / 2.0**frac;
    end function;

    function clog2(x: integer) return integer is
    begin
        return integer(ceil(log2(real(x))));
    end function;

    function reverse(vec: std_logic_vector) return std_logic_vector is
        constant L: integer := vec'length;
        variable input, res: std_logic_vector(L-1 downto 0) := vec;
    begin
        for k in input'range loop
            res(k) := input(L-1-k);
        end loop;
        return res;
    end function;

    function reverse(num: integer; nbits: integer) return integer is
        variable input, res_u: unsigned(nbits-1 downto 0);
    begin
        input := to_unsigned(num, nbits);
        for k in input'range loop
            res_u(k) := input(nbits-1-k);
        end loop;
        return to_integer(res_u);
    end function;

    function reorder(idata: real_vec) return real_vec is
        variable idatato: real_vec(0 to idata'length-1) := idata;
        constant L: integer := idata'length;
        constant NBITS: integer := clog2(L);
        variable res: real_vec(0 to L-1);
    begin
        for k in 0 to L-1 loop
            res(k) := idatato(reverse(k, NBITS));
        end loop;
        return res;
    end function;

    function reorder(idata: cplx_vec) return cplx_vec is
        variable idatato: cplx_vec(0 to idata'length-1) := idata;
        constant L: integer := idata'length;
        constant NBITS: integer := clog2(L);
        variable res: cplx_vec(0 to L-1);
    begin
        for k in 0 to L-1 loop
            res(k) := idatato(reverse(k, NBITS));
        end loop;
        return res;
    end function;
    
    function reorder(idata: cplx_vec; nchan: integer) return cplx_vec is    -- idata length must be a multiple of nchan
        variable idatato: cplx_vec(0 to idata'length-1) := idata;
        constant L: integer := idata'length;
        constant L1: integer := L / nchan;
        constant NBITS: integer := clog2(L1);
        variable res: cplx_vec(0 to L-1);
        variable buf: cplx_vec(0 to L1-1);
    begin
        
        for ch in 0 to nchan-1 loop
            -- get all data for current channel
            for k in 0 to L1-1 loop
                buf(k) := idatato(k*nchan + ch);
            end loop;
            -- reorder single channel
            buf := reorder(buf);
            -- write reordered to res
            for k in 0 to L1-1 loop
                res(k*nchan + ch) := buf(k);
            end loop;
        end loop;
        return res;
    end function;

    function tw(n, fftlen, ifft: integer) return cplx is
        variable res: cplx;
        variable argm: real;
    begin
        argm := -MATH_2_PI * real(n) / real(fftlen);
        res.re := cos(argm);
        res.im := sin(argm);
        if ifft > 0 then
            res.im := -res.im;  -- conj
        end if;
        return res;
    end function;

    function "+"(a,b: cplx) return cplx is
        variable res: cplx;
    begin
        res.re := a.re + b.re;
        res.im := a.im + b.im;
        return res;
    end function;

    function "-"(a,b: cplx) return cplx is
        variable res: cplx;
    begin
        res.re := a.re - b.re;
        res.im := a.im - b.im;
        return res;
    end function;

    function "*"(a,b: cplx) return cplx is
        variable res: cplx;
    begin
        -- (a.re + j*a.im) * (b.re + j*b.im) = (a.re*b.re - a.im*b.im) + j(a.im*b.re + a.re*b.im)
        res.re := a.re*b.re - a.im*b.im;
        res.im := a.im*b.re + a.re*b.im;
        return res;
    end function;
    
    function "+"(a,b: cplx_vec) return cplx_vec is
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable b_to: cplx_vec(0 to b'length-1) := b;
        variable res: cplx_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) + b_to(k);
        end loop;
        return res;
    end function;
    
    function "-"(a,b: cplx_vec) return cplx_vec is
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable b_to: cplx_vec(0 to b'length-1) := b;
        variable res: cplx_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) - b_to(k);
        end loop;
        return res;
    end function;
    
    function "*"(a,b: cplx_vec) return cplx_vec is
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable b_to: cplx_vec(0 to b'length-1) := b;
        variable res: cplx_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) * b_to(k);
        end loop;
        return res;
    end function;
    
    
    function "+"(a,b: real_vec) return real_vec is
        variable a_to: real_vec(0 to a'length-1) := a;
        variable b_to: real_vec(0 to b'length-1) := b;
        variable res: real_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) + b_to(k);
        end loop;
        return res;
    end function;
    
    function "-"(a,b: real_vec) return real_vec is
        variable a_to: real_vec(0 to a'length-1) := a;
        variable b_to: real_vec(0 to b'length-1) := b;
        variable res: real_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) - b_to(k);
        end loop;
        return res;
    end function;
    
    function "*"(a,b: real_vec) return real_vec is
        variable a_to: real_vec(0 to a'length-1) := a;
        variable b_to: real_vec(0 to b'length-1) := b;
        variable res: real_vec(a_to'range) := a;
    begin
        for k in a_to'range loop
            res(k) := a_to(k) * b_to(k);
        end loop;
        return res;
    end function;
    
    
    function re(a: cplx_vec) return real_vec is   -- get real part
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable res: real_vec(0 to a'length-1);
    begin
        for k in a_to'range loop
            res(k) := a_to(k).re;
        end loop;
        return res;
    end function;
    
    function im(a: cplx_vec) return real_vec is   -- get imaginary part
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable res: real_vec(0 to a'length-1);
    begin
        for k in a_to'range loop
            res(k) := a_to(k).im;
        end loop;
        return res;
    end function;
    
    function absr(a: real_vec) return real_vec is   -- get absolute value
        variable a_to: real_vec(0 to a'length-1) := a;
        variable res: real_vec(0 to a'length-1);
    begin
        for k in a_to'range loop
            res(k) := abs(a_to(k));
        end loop;
        return res;
    end function;
    
    function absc(a: cplx_vec) return real_vec is
        variable a_to: cplx_vec(0 to a'length-1) := a;
        variable res: real_vec(0 to a'length-1);
    begin
        for k in a_to'range loop
            res(k) := sqrt(a_to(k).re**2 + a_to(k).im**2);
        end loop;
        return res;
    end function;
    
    function max(a: real_vec) return real is   -- get max value
        variable a_to: real_vec(0 to a'length-1) := a;
        variable res: real;
    begin
        if a'length > 0 then
            res := a_to(0);
        else
            res := 0.0;
            report "max(zero length real_vec) returned 0.0" severity warning;
        end if;
        for k in a_to'range loop
            if a_to(k) > res then
                res := a_to(k);
            end if;
        end loop;
        return res;
    end function;
    
    function max_index(a: real_vec) return integer is   -- returns index of max value in a. If there are several maximums, index of the 1st one is returned
        variable a_to: real_vec(0 to a'length-1) := a;
        variable res: integer;
    begin
        res := 0;
        if a'length = 0 then
            report "max_index(zero length real_vec) returned 0" severity warning;
        end if;
        for k in a_to'range loop
            if a_to(k) > a_to(res) then
                res := k;
            end if;
        end loop;
        return res;
    end function;
    
    function mean(a: real_vec) return real is
        variable a_to: real_vec(0 to a'length-1) := a;
        variable res: real := 0.0;
    begin
        if a'length = 0 then
            report "mean(zero length real_vec) returned 0.0" severity warning;
            return res;
        end if;
        for k in a_to'range loop
            res := res + a_to(k);
        end loop;
        res := res / real(a'length);
        return res;
    end function;

    function fft(idata: cplx_vec; inv, reord, scale: integer) return cplx_vec is
        constant L: integer := idata'length;
        constant NSTAGES: integer := clog2(L);
        variable x: cplx_vec(0 to L-1) := idata;
        variable sm: cplx;
        variable st, ed, numfft, nhalf: integer := 0;    
        variable invscale: real := 1.0 / real(scale);
    begin
        for stage in 0 to NSTAGES-1 loop
            numfft := 2**stage; -- number of sub-ffts
            nhalf := L / numfft / 2;
            for nf in 0 to numfft-1 loop
                st := nf * 2*nhalf;     -- start index of half-fft
                ed := st + nhalf - 1;   -- end index of half-fft
                -- calc butterfly sum/diff
                for ix in st to ed loop
                    sm := x(ix) + x(ix+nhalf);
                    x(ix+nhalf) := (x(ix) - x(ix+nhalf)) * tw(numfft*(ix-st), L, inv);
                    x(ix) := sm;
                end loop;
            end loop;
        end loop;
        
        if reord /= 0 then
            x := reorder(x);
        end if;
        
--        if scale /= 0 then
--            for k in 0 to L-1 loop
--                x(k).re := x(k).re / real(L);
--                x(k).im := x(k).im / real(L);
--            end loop;
--        end if;

        -- scaling
        for k in 0 to L-1 loop
            x(k).re := x(k).re * invscale;
            x(k).im := x(k).im * invscale;
        end loop;

        return x;
    end function;
    
    -- calculate output for multichannel fft
    function fft_multich(x: cplx_vec; n_chan: integer; inv, reord, scale: integer) return cplx_vec is
        variable xto: cplx_vec(0 to x'length-1) := x;
        variable res: cplx_vec(0 to x'length-1);
        constant fftlen: integer := x'length / n_chan;
        variable buf_single: cplx_vec(0 to fftlen-1);
    begin
        for ch in 0 to n_chan-1 loop
            -- get fft input for current channel ch
            for k in 0 to fftlen-1 loop
                buf_single(k) := xto(n_chan*k + ch);
            end loop;
            -- calc fft
            buf_single := fft(buf_single, inv, reord, scale);
            -- put fft output to res
            for k in 0 to fftlen-1 loop
                res(n_chan*k + ch) := buf_single(k);
            end loop;
        end loop;
        return res;
    end function;
    
    

end package body fft_sim_pkg;