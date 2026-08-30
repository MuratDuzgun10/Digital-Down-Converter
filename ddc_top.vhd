library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ddc_pkg.all;

entity ddc_top is
    generic (
        PHASE_W : natural := 32;
        LUT_ADDR_W : natural := 10;
        NCO_W : natural := 16;

        ADC_W : natural := 14;
        MIX_W : natural := 18;

        CIC_STAGES : positive := 3;
        CIC_R : positive := 8;
        CIC_DIFF_DELAY : positive := 1;
        CIC_INTERNAL_W : positive := 34;
        CIC_OUT_SHIFT : natural := 9;
        CIC_OUT_W : positive := 18;

        FIR_TAPS : positive := 21;
        FIR_COEF_W : positive := 16;
        FIR_CUTOFF : real := 0.4;
        FIR_COEFFS : int_array_t := design_lowpass_coeffs(21, 16, 0.4);
        FIR_DECIM : positive := 2;

        OUT_W : positive := 16
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        en_in : in std_logic;
        adc_data : in signed(ADC_W - 1 downto 0);
        phase_inc : in unsigned(PHASE_W - 1 downto 0);
        phase_ld : in std_logic := '0';
        phase_ld_val : in unsigned(PHASE_W - 1 downto 0) := (others => '0');
        i_out : out signed(OUT_W - 1 downto 0);
        q_out : out signed(OUT_W - 1 downto 0);
        out_valid : out std_logic
    );
end entity ddc_top;

architecture rtl of ddc_top is

    signal sin_s, cos_s : signed(NCO_W - 1 downto 0);
    signal i_mix, q_mix : signed(MIX_W - 1 downto 0);
    signal i_cic, q_cic : signed(CIC_OUT_W - 1 downto 0);
    signal cic_valid : std_logic;

begin

    u_nco : entity work.nco
    generic map (
        PHASE_W => PHASE_W,
        LUT_ADDR_W => LUT_ADDR_W,
        OUT_W => NCO_W
    )
    port map (
        clk => clk,
        rst => rst,
        en => en_in,
        phase_inc => phase_inc,
        phase_ld => phase_ld,
        phase_ld_val => phase_ld_val,
        sin_o => sin_s,
        cos_o => cos_s
    );

    u_mixer : entity work.cplx_mixer
    generic map (
        DIN_W => ADC_W,
        LO_W => NCO_W,
        DOUT_W => MIX_W
    )
    port map (
        clk => clk,
        rst => rst,
        en => en_in,
        din => adc_data,
        cos_i => cos_s,
        sin_i => sin_s,
        i_o => i_mix,
        q_o => q_mix
    );

    u_cic_i : entity work.cic_decimator
    generic map (
        NUM_STAGES => CIC_STAGES,
        DECIM_FACTOR => CIC_R,
        DIFF_DELAY => CIC_DIFF_DELAY,
        IN_W => MIX_W,
        INTERNAL_W => CIC_INTERNAL_W,
        OUT_SHIFT => CIC_OUT_SHIFT,
        OUT_W => CIC_OUT_W
    )
    port map (
        clk => clk,
        rst => rst,
        en_in => en_in,
        din => i_mix,
        dout => i_cic,
        en_out => cic_valid
    );

    u_cic_q : entity work.cic_decimator
    generic map (
        NUM_STAGES => CIC_STAGES,
        DECIM_FACTOR => CIC_R,
        DIFF_DELAY => CIC_DIFF_DELAY,
        IN_W => MIX_W,
        INTERNAL_W => CIC_INTERNAL_W,
        OUT_SHIFT => CIC_OUT_SHIFT,
        OUT_W => CIC_OUT_W
    )
    port map (
        clk => clk,
        rst => rst,
        en_in => en_in,
        din => q_mix,
        dout => q_cic,
        en_out => open
    );

    u_fir_i : entity work.fir_decim
    generic map (
        TAPS => FIR_TAPS,
        COEFFS => FIR_COEFFS,
        COEF_W => FIR_COEF_W,
        DECIM_FACTOR => FIR_DECIM,
        IN_W => CIC_OUT_W,
        OUT_W => OUT_W
    )
    port map (
        clk => clk,
        rst => rst,
        en_in => cic_valid,
        din => i_cic,
        dout => i_out,
        en_out => out_valid
    );

    u_fir_q : entity work.fir_decim
    generic map (
        TAPS => FIR_TAPS,
        COEFFS => FIR_COEFFS,
        COEF_W => FIR_COEF_W,
        DECIM_FACTOR => FIR_DECIM,
        IN_W => CIC_OUT_W,
        OUT_W => OUT_W
    )
    port map (
        clk => clk,
        rst => rst,
        en_in => cic_valid,
        din => q_cic,
        dout => q_out,
        en_out => open
    );

end architecture rtl;
