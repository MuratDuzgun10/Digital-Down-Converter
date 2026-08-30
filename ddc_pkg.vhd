-------------------------------------------------------------------------------
-- ddc_pkg.vhd
--
-- Shared types and fixed-point helper functions for the DDC project.
--   * int_array_t          : generic integer array (used for FIR coefficient
--                             generics, so entities can accept coefficients
--                             as a plain array of integers).
--   * round_shift           : arithmetic right-shift by an explicit number of
--                             bits with round-to-nearest, followed by a
--                             resize down to the requested output width.
--                             Used everywhere a fixed-point product or
--                             accumulator needs to be rescaled (mixer,
--                             CIC, FIR).
--   * design_lowpass_coeffs  : windowed-sinc (Hamming window) low-pass FIR
--                             coefficient generator, evaluated at
--                             elaboration time so it can be used directly
--                             as a generic default value. This keeps the
--                             design self-contained: no external
--                             coefficient file is required to synthesize
--                             or simulate the project.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

package ddc_pkg is
    type int_array_t is array (natural range <>) of integer;
    
    function round_shift(din: signed; shift : natural; wout : natural) return signed;
    
    function design_lowpass_coeffs(taps : positive;
                                   coef_w : positive;
                                   fc : real) return int_array_t;
end ddc_pkg;

package body ddc_pkg is
    -----------------------------------------------------------------------
    -- round_shift
    --   Arithmetic-shift-right din by 'shift' bits with round-to-nearest
    --   (ties round up), then narrow to 'wout' bits.
    --
    --   NOTE: this assumes the caller has allocated enough headroom bits
    --   in din so that the value, once scaled down by 2**shift, actually
    --   fits in 'wout' bits. If it does not, the result wraps just like
    --   ordinary two's-complement truncation (no explicit saturation
    --   logic is inserted). Size internal accumulator widths generously
    --   to avoid this.
    -----------------------------------------------------------------------
    
    function round_shift(din : signed; shift : natural; wout : natural) return signed is
        variable ext : signed(din'length downto 0);
        variable rounded : signed(din'length downto 0);
     begin  
        if shift = 0 then
            return resize(din, wout);
        else
            ext := resize(din, din'length + 1);
            rounded := ext + shift_left(to_signed(1, din'length + 1), shift - 1);
            return resize(shift_right(rounded, shift), wout);
        end if;
    end function;

    function design_lowpass_coeffs(taps : positive;
                                   coef_w : positive;
                                   fc : real) return int_array_t is
         type real_array_t is array (0 to taps - 1) of real;
         variable hbuf : real_array_t;
         variable center : real:= real(taps - 1) / 2.0;
         variable x, w, val, gain : real;
         variable result : int_array_t(0 to taps - 1);
         constant scale : real := real(2**(coef_w - 1) - 1);
    begin
        gain := 0.0;
        for i in  0 to taps - 1 loop
            x:= real(i) - center;
            if abs(x) < 1.0e-9 then
                val := 2.0 * fc; -- only to get the result of x=0 -> real(i) = center because if we go to else section for x=0 0/0 is can not be calculated
            else
                val := sin(2.0* MATH_PI * fc * x) / (MATH_PI * x); --ideal low pass filter formula with using Fourier transform where sin represneted as sin(x)/x
            end if;
            --Hamming window
            w := 0.54 - 0.46 * cos(2.0 * MATH_PI * real(i) / real(taps - 1)); -- hamming is using for get trid of the unwanted data from infinite sin fucntion
            hbuf(i) := val * w;
            gain := gain + hbuf(i);
        end loop;
        
        for i in 0 to taps - 1 loop
            result(i) := integer(round(scale * hbuf(i) / gain));
        end loop;
        return result;          
     end function;
     
end package body ddc_pkg;
