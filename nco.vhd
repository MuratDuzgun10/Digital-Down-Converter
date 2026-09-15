library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity nco is
    generic(
        PHASE_W : natural := 32; --phase accumulator width
        LUT_ADDR_W : natural := 10; -- LUT address width (depth = 2**LUT_ADDR_W)
        OUT_W : natural := 16 --sine/cosine sample width
    );
    port(
        clk : in std_logic;
        rst : in std_logic;
        en : std_logic; --sample enable
        phase_inc : in unsigned(PHASE_W - 1 downto 0); --frequency tuning word
        phase_ld : in std_logic := '0'; --synchronous phase reset
        phase_ld_val : in unsigned(PHASE_W - 1 downto 0) := (others => '0');
        sin_o : out signed(OUT_W -1 downto 0);
        cos_o : out signed(OUT_W - 1 downto 0)  
    );
end nco;

architecture RTL of nco is
    constant LUT_DEPTH : natural := 2**LUT_ADDR_W;
    constant AMPL : real := real(2**(OUT_W-1) -1);
    type lut_array_t is array (0 to LUT_DEPTH -1) of signed(OUT_W -1 downto 0);
    
    function build_sin_lut return lut_array_t is
        variable tbl : lut_array_t;
        variable ang : real;
    begin
        for i in 0 to LUT_DEPTH -1 loop
            ang := 2.0*MATH_PI*real(i)/real(LUT_DEPTH);
            tbl(i) := to_signed(integer(round(AMPL*sin(ang))), OUT_W);
        end loop;
        return tbl;  
    end function;
    
    function build_cos_lut return lut_array_t is
        variable tbl : lut_array_t;
        variable ang : real;
    begin
        for i in 0 to LUT_DEPTH - 1 loop
            ang    := 2.0 * MATH_PI * real(i) / real(LUT_DEPTH);
            tbl(i) := to_signed(integer(round(AMPL * cos(ang))), OUT_W);
        end loop;
        return tbl;
    end function;
    
    constant SIN_LUT : lut_array_t := build_sin_lut;
    constant COS_LUT : lut_array_t := build_cos_lut;
    
    signal phase_acc : unsigned(PHASE_W - 1 downto 0) := (others => '0');
    signal lut_addr : unsigned(LUT_ADDR_W - 1 downto 0);
    signal sin_reg, cos_reg : signed(OUT_W - 1 downto 0) := (others=>'0');
begin
    lut_addr <= phase_acc(PHASE_W - 1 downto PHASE_W - LUT_ADDR_W);
    
    p_phase : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                phase_acc <= (others => '0');
            elsif phase_ld = '1' then
                phase_acc <= phase_ld_val;
            elsif en = '1' then
                phase_acc <= phase_acc + phase_inc;
            end if;
        end if;
    end process p_phase;
    
    p_lut : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sin_reg <= (others=> '0');
                cos_reg <= (others=> '0');
             elsif en = '1' then
                sin_reg <= SIN_LUT(to_integer(lut_addr));
                cos_reg <= COS_LUT(to_integer(lut_addr));
            end if;
        end if;
    end process p_lut;
    
    sin_o <= sin_reg;
    cos_o <= cos_reg;
end RTL;
