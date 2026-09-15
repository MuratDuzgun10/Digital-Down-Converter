
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.ddc_pkg.all;

entity cplx_mixer is
   generic(
        DIN_W : natural := 16; --input real sample width
        LO_W : natural := 16; --NCO sin/cos sample width
        DOUT_W : natural := 18 --output I(Q width
    );
    Port(
        clk : in std_logic;
        rst : in std_logic;
        en : in std_logic;
        din : in signed(DIN_W - 1 downto 0);
        cos_i : in signed(LO_W - 1 downto 0);
        sin_i : in signed(LO_W - 1 downto 0);
        i_o : out signed(DOUT_W - 1 downto 0);
        q_o : out signed(DOUT_W - 1 downto 0)   
    );
    
end cplx_mixer;

architecture rtl of cplx_mixer is
    signal i_full, q_full : signed(DIN_W + LO_W - 1 downto 0):= (others => '0');
begin
    
    p_mix: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i_full <= (others => '0');
                q_full <= (others => '0');
            elsif en = '1' then
                i_full <= din * cos_i;
                q_full <= -(din * sin_i);
            end if;
        end if;
    end process p_mix;
    
    i_o <= round_shift(i_full, LO_W -1, DOUT_W);
    q_o <= round_shift(q_full, LO_w -1, DOUT_W);
end rtl;
