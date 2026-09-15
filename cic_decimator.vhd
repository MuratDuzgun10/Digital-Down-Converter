-------------------------------------------------------------------------------
-- cic_decimator.vhd
--
-- Generic N-stage CIC (Hogenauer) decimator:
--   NUM_STAGES  cascaded integrators running at the input rate
--   -> decimate by DECIM_FACTOR (R)
--   -> NUM_STAGES cascaded combs (differential delay DIFF_DELAY) running
--      at the decimated output rate.
--

-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.ddc_pkg.all;

entity cic_decimator is
    generic(
        NUM_STAGES : positive := 3;
        DECIM_FACTOR : positive := 8;
        DIFF_DELAY : positive := 1;
        IN_W : positive := 18;
        INTERNAL_W : positive := 34;
        OUT_SHIFT :  positive := 9;
        OUT_W : positive := 18
    );
    
     Port(
        clk : in std_logic;
        rst : in std_logic;
        en_in : in std_logic;
        din : in signed(IN_W - 1 downto 0);
        dout : out signed(OUT_W - 1 downto 0);
        en_out : out std_logic
     );
end cic_decimator;

architecture rtl of cic_decimator is
    type stage_array_t is array (0 to NUM_STAGES) of signed(INTERNAL_W - 1 downto 0);
    type comb_delay_line_t is array (0 to DIFF_DELAY - 1) of signed(INTERNAL_W - 1 downto 0);
    type comb_delay_bank_t is array (0 to NUM_STAGES - 1) of comb_delay_line_t;
    
    signal integ : stage_array_t := (others=>(others=>'0'));
    signal comb_bank : comb_delay_bank_t := (others =>(others=>(others=>'0')));
    signal comb_out : stage_array_t := (others=>(others=>'0'));
    
    signal decim_cnt : unsigned(15 downto 0):= (others=>'0');
    signal decim_strobe : std_logic:='0';
   
begin
    ---------------------------------------------------------------------
    -- Integrator section (input rate)
    --------------------------------------------------------------------- 
    integ(0) <= resize(din, INTERNAL_W);
    
    gen_integrators : for k in 0 to NUM_STAGES - 1 generate
        p_int : process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    integ(k + 1) <= (others=>'0');
                elsif en_in = '1' then
                    integ(k + 1) <= integ(k + 1)  + integ(k);
                end if;
            end if;
        end process p_int;
    end generate gen_integrators;
    ---------------------------------------------------------------------
    -- Decimate-by-R strobe generator
    ---------------------------------------------------------------------
    p_decim : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                decim_cnt    <= (others => '0');
                decim_strobe <= '0';
            elsif en_in = '1' then
                if decim_cnt = DECIM_FACTOR - 1 then
                    decim_cnt    <= (others => '0');
                    decim_strobe <= '1';
                else
                    decim_cnt <= decim_cnt + 1;
                    decim_strobe <= '0';
                end if;
             else
                decim_strobe <= '0';
            end if;
        end if;
    end process p_decim;
    ---------------------------------------------------------------------
    -- Comb section (decimated output rate)
    ---------------------------------------------------------------------
    comb_out(0) <= integ(NUM_STAGES);
    
    gen_combs : for k in 0 to NUM_STAGES - 1 generate
        p_comb : process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    comb_bank(k) <= (others=>(others=>'0'));
                    comb_out(k+1) <= (others=>'0');
                 elsif decim_strobe = '1' then
                    comb_bank(k)(0) <= comb_out(k);
                    for d in 1 to DIFF_DELAY - 1 loop --ýf we need to increase the stages of DIFF_DELAY this loop will start acting but for now we do not use it
                        comb_bank(k)(d) <= comb_bank(k)(d-1);
                    end loop;
                    comb_out(k+1) <= comb_out(k) - comb_bank(k)(DIFF_DELAY - 1);
                end if;
            end if;
        end process p_comb;
    end generate gen_combs;
    
    dout <= round_shift(comb_out(NUM_STAGES), OUT_SHIFT, OUT_W);
    en_out <= decim_strobe;
end rtl;
