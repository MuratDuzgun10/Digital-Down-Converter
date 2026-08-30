-------------------------------------------------------------------------------
-- fir_decim.vhd
--
-- Generic direct-form FIR filter with built-in decimation by DECIM_FACTOR.
-- Coefficients are supplied as a plain array of integers (COEFFS), scaled
-- as COEF_W-bit signed values representing value / 2**(COEF_W-1) (i.e.
-- a unity-gain-normalized fixed-point convention). This matches the
-- output of ddc_pkg.design_lowpass_coeffs, which can be used to supply
-- COEFFS directly.
--
-- This is a straightforward (non-polyphase) implementation: every tap is
-- evaluated on every input sample and the result is only latched every
-- DECIM_FACTOR-th sample. It is simple and fully synthesizable, but for
-- large tap counts / high sample rates a polyphase structure would use
-- DSP resources more efficiently -- see README for notes.
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.ddc_pkg.all;

entity fir_decim is
    generic(
        TAPS : positive := 21;
        COEFFS : int_array_t;   --lenght must equal TAPS
        COEF_W : positive := 16;
        DECIM_FACTOR : positive := 2;
        IN_W : positive := 18;
        OUT_W : positive := 18
    );
    
    Port(
        clk : in std_logic;
        rst : in std_logic;
        en_in : std_logic;
        din : in signed(IN_W - 1 downto 0);
        dout : out signed(OUT_W - 1 downto 0);
        en_out : out std_logic
    );
end fir_decim;

architecture rtl of fir_decim is
    type shift_reg_t is array (0 to TAPS-1) of signed(IN_W-1 downto 0);
    signal shreg : shift_reg_t := (others=>(others=>'0'));
    
    constant SUM_W : positive := IN_W + COEF_W + 8; --headroom for tap signal
    
    type coef_rom_t is array (0 to TAPS-1) of signed(COEF_W-1 downto 0);
    
    function build_coef_rom  return coef_rom_t is
        variable rom : coef_rom_t := (others => (others => '0'));
    begin
        for i in 0 to TAPS-1 loop
            rom(i) := to_signed(COEFFS(i), COEF_W);
        end loop;
        return rom;
    end function;
    
    constant COEF_ROM : coef_rom_t := build_coef_rom;
    
    signal decim_cnt : unsigned(15 downto 0) := (others=>'0');
    signal out_strobe : std_logic := '0';
    signal dout_reg : signed(OUT_W - 1 downto 0) := (others=>'0');
    signal en_out_reg : std_logic := '0';
    
begin

    assert COEFFS'length = TAPS
        report "fir_decim: COEFFS array length must equal TAPS"
        severity FAILURE;
    ---------------------------------------------------------------------
    -- Input shift register (input rate)
    ---------------------------------------------------------------------
    p_shift : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                shreg <= (others=> (others=>'0'));
            elsif en_in = '1' then
                shreg(0) <= din;
                for i in 1 to TAPS-1 loop
                    shreg(i) <= shreg(i-1);
                end loop;
            end if;
        end if;
    end process p_shift;
    
    ---------------------------------------------------------------------
    -- Decimate-by-M strobe generator
    ---------------------------------------------------------------------  
    p_decim : process(clk)
    begin     
        if rising_edge(clk) then
            if rst = '1' then
               decim_cnt <= (others=>'0');
               out_strobe <= '0';
             elsif en_in = '1' then
                if decim_cnt = DECIM_FACTOR - 1 then
                    decim_cnt <= (others=>'0');
                    out_strobe <= '1';
                 else 
                    decim_cnt <= decim_cnt + 1;
                    out_strobe <= '0';
                 end if;
              else
                out_strobe <= '0';
            end if;
        end if;
    end process p_decim;
    ---------------------------------------------------------------------
    -- MAC (evaluated only on the decimated output sample)
    ---------------------------------------------------------------------
    p_mac : process(clk)
        variable acc : signed(SUM_W-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                dout_reg <= (others=>'0');
                en_out_reg <= '0';
            elsif en_in = '1' and out_strobe = '1' then
                acc := (others=>'0');
                for i in 0 to TAPS-1 loop
                    acc := acc + resize(shreg(i) * COEF_ROM(i), SUM_W);
                end loop;
                dout_reg <= round_shift(acc, COEF_W-1, OUT_W);
                en_out_reg <= '1';
            else
                en_out_reg <= '0';
            end if;
        end if;
    end process p_mac;
    
    dout <= dout_reg;
    en_out <= en_out_reg;
end rtl;
