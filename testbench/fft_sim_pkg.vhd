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

    function clog2(x: integer) return integer;
    function reverse(vec: std_logic_vector) return std_logic_vector;
    function reverse(num: integer; nbits: integer) return integer;
    function reorder(idata: real_vec) return real_vec;  -- bit-reversed to natural reordering (and vise versa)
    function reorder(idata: cplx_vec) return cplx_vec;
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
    
end package fft_sim_pkg;

package body fft_sim_pkg is

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

    function reorder(idata: real_vec) return real_vec is    -- idata must be 0 to
        constant L: integer := idata'length;
        constant NBITS: integer := clog2(L);
        variable res: real_vec(0 to L-1);
    begin
        for k in 0 to L-1 loop
            res(k) := idata(reverse(k, NBITS));
        end loop;
        return res;
    end function;

    function reorder(idata: cplx_vec) return cplx_vec is    -- idata must be 0 to
        constant L: integer := idata'length;
        constant NBITS: integer := clog2(L);
        variable res: cplx_vec(0 to L-1);
    begin
        for k in 0 to L-1 loop
            --res(k).re := idata(reverse(k, NBITS)).re;
            --res(k).im := idata(reverse(k, NBITS)).im;
            res(k) := idata(reverse(k, NBITS));
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
        
        if scale /= 0 then
            for k in 0 to L-1 loop
                x(k).re := x(k).re / real(L);
                x(k).im := x(k).im / real(L);
            end loop;
        end if;
        return x;
    end function;

end package body fft_sim_pkg;