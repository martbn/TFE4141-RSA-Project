
----- må sjekka t a og b itereringen til alphaene blir riktig
-- må også adde det for p og sånt, samt litt shift logic må på plass
-- amt logikk for å ta ut svaret


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_r64_datapath is
  generic (
    WORD_WIDTH : integer := 32;
    OPERAND_WIDTH : integer := 256
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';

    a_operand  : in  unsigned(OPERAND_WIDTH-1 downto 0);
    b_operand  : in  unsigned(OPERAND_WIDTH-1 downto 0);
    
    p_operand  : in  unsigned(OPERAND_WIDTH-1 downto 0);
    p_marked_operand  : in  unsigned(WORD_WIDTH_WIDTH-1 downto 0);

    sig_state   : in  std_logic;
    first_Outer_loop : in unsigned(1 downto 0);
  );
end entity montgomery_r64_datapath;

architecture behavior of montgomery_r64_datapath is

  -- Calculate number of words
  constant NUM_WORDS : integer := OPERAND_WIDTH / WORD_WIDTH;

  -- Signals for interconnecting processing elements
  signal b_first3 : unsigned(3*WORD_WIDTH-1 downto 0);
  signal b_middle3 : unsigned(3*WORD_WIDTH-1 downto 0);
  signal b_last2 : unsigned(2*WORD_WIDTH-1 downto 0);

  signal b_first_correct : unsigned(WORD_WIDTH-1 downto 0);
  signal b_middle_correct : unsigned(WORD_WIDTH-1 downto 0);
  signal b_last_correct : unsigned(WORD_WIDTH-1 downto 0);

  signal a_operand_full : unsigned(OPERAND_WIDTH-1 downto 0);

  signal a_first_word : unsigned(WORD_WIDTH-1 downto 0);
  signal a_middle_word : unsigned(WORD_WIDTH-1 downto 0);
  signal a_last_word : unsigned(WORD_WIDTH-1 downto 0);

  signal zero : unsigned(WORD_WIDTH-1 downto 0);

  -- Alpha PE signals
  signal s_a1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_a2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_a3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s1_af_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_af_out : unsigned(WORD_WIDTH-1 downto 0);

  -- Beta PE signals
  signal m : unsigned(WORD_WIDTH-1 downto 0);
  signal c_b_out : unsigned(WORD_WIDTH-1 downto 0);

  -- Gamma PE signals
  signal s_g1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_g2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_g3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s1_gf_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_gf_out : unsigned(WORD_WIDTH-1 downto 0);

  -- P operand words
  signal p_0 : unsigned(WORD_WIDTH-1 downto 0);
  signal p_marked : unsigned(WORD_WIDTH-1 downto 0);


  signal alpha1_in_s_g1 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha1_in_s_g2 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha2_in_s_g2 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha2_in_s_g3 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha3_in_s_g3 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha3_in_s1_gf : unsigned(WORD_WIDTH-1 downto 0);


begin

  -- Assign input operands to internal signals
  b_first3 <= b_operand(3*WORD_WIDTH-1 downto 0);
  b_middle3 <= b_operand(6*WORD_WIDTH-1 downto 3*WORD_WIDTH);
  b_last2 <= b_operand(8*WORD_WIDTH-1 downto 6*WORD_WIDTH);

  b_first_correct <= b_operand(WORD_WIDTH-1 downto 0);
  b_middle_correct <= b_operand(4*WORD_WIDTH-1 downto 3*WORD_WIDTH);
  b_last_correct <= b_operand(7*WORD_WIDTH-1 downto 6*WORD_WIDTH);

  a_operand_full <= a_operand;
  a_first_word <= a_operand_full(WORD_WIDTH-1 downto 0);
  a_middle_word <= a_operand_full(2*WORD_WIDTH-1 downto WORD_WIDTH);
  a_last_word <= a_operand_full(3*WORD_WIDTH-1 downto 2*WORD_WIDTH);

  zero <= (others => '0');

  -- Extract P operand words
  p_0 <= p_operand(WORD_WIDTH-1 downto 0);
  p_marked <= p_marked_operand(WORD_WIDTH-1 downto 0);

  


  mux: process(clk, reset)
  begin
    if reset = '1' then
      alpha1_in_s_g1 <= (others => '0');
      alpha1_in_s_g2 <= (others => '0');
      alpha2_in_s_g2 <= (others => '0');
      alpha2_in_s_g3 <= (others => '0');
      alpha3_in_s_g3 <= (others => '0');
      alpha3_in_s1_gf <= (others => '0');
      
    elsif first_Outer_loop = '01' then
      alpha1_in_s_g1 <= s_g1_out;
      alpha1_in_s_g2 <= s_g2_out;
    elsif first_Outer_loop = '10' then
      alpha1_in_s_g1 <= s_g1_out;
      alpha1_in_s_g2 <= s_g2_out;
      alpha2_in_s_g2 <= s_g2_out;
      alpha2_in_s_g3 <= s_g3_out;
    elsif first_Outer_loop = '11' then
      alpha1_in_s_g1 <= s_g1_out;
      alpha1_in_s_g2 <= s_g2_out;
      alpha2_in_s_g2 <= s_g2_out;
      alpha2_in_s_g3 <= s_g3_out;
      alpha3_in_s_g3 <= s_g3_out;
      alpha3_in_s1_gf <= s1_gf_out;
    else
      alpha1_in_s_g1 <= (others => '0');
      alpha1_in_s_g2 <= (others => '0');
      alpha2_in_s_g2 <= (others => '0');
      alpha2_in_s_g3 <= (others => '0');
      alpha3_in_s_g3 <= (others => '0');
      alpha3_in_s1_gf <= (others => '0');
    end if;
  end process;  

  -- ========================================================================
  -- Alpha Processing Elements
  -- ========================================================================

  alpha1_pe_inst : entity work.alpha1_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      a_word    => a_first_word,
      b_word    => b_first_correct,
      s_g1_out  => alpha1_in_s_g1,
      s_g2_out  => alpha1_in_s_g2,
      zero      => zero,
      s_a1_out  => s_a1_out,
      c_a1_out  => c_a1_out,
      sig_state => sig_state
    );

  alpha2_pe_inst : entity work.alpha2_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      a_word    => a_middle_word,
      b_word    => b_middle_correct,
      s_g2_out  => alpha2_in_s_g2,
      s_g3_out  => alpha2_in_s_g3,
      c_a1_out  => c_a1_out,
      s_a2_out  => s_a2_out,
      c_a2_out  => c_a2_out,
      sig_state => sig_state
    );

  alpha3_pe_inst : entity work.alpha3_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      a_word    => a_last_word,
      b_word    => b_last_correct,
      s1_gf_out => alpha3_in_s1_gf,
      s_g3_out  => alpha3_in_s_g3,
      c_a2_out  => c_a2_out,
      s_a3_out  => s_a3_out,
      c_a3_out  => c_a3_out,
      sig_state => sig_state
    );

  alpha_final_pe_inst : entity work.alpha_final_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      s_af_in   => s_a3_out,
      c_af_in   => c_a3_out,
      s1_af_out => s1_af_out,
      s2_af_out => s2_af_out
    );

  -- ========================================================================
  -- Beta Processing Element
  -- ========================================================================

  beta_pe_inst : entity work.beta_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      p_marked  => p_marked_0,
      p_zero    => p_0,
      s_b_in    => s_a1_out,
      m         => m,
      c_b_out   => c_b_out
    );

  -- ========================================================================
  -- Gamma Processing Elements
  -- ========================================================================

  gamma1_pe_inst : entity work.gamma1_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      m         => m,
      p_i       => p_0,
      s_g1_in   => s_a1_out,
      c_g1_in   => zero,
      s_g1_out  => s_g1_out,
      c_g1_out  => c_g1_out
    );

  gamma2_pe_inst : entity work.gamma2_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      m         => m,
      p_i       => p_0,
      s_a1_out  => s_a1_out,
      s_a2_out  => s_a2_out,
      c_g1_out  => c_g1_out,
      s_g2_out  => s_g2_out,
      c_g2_out  => c_g2_out,
      sig_state => sig_state
    );

  gamma3_pe_inst : entity work.gamma3_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      m         => m,
      p_i       => p_0,
      s_a2_out  => s_a2_out,
      s_a3_out  => s_a3_out,
      c_g2_out  => c_g2_out,
      s_g3_out  => s_g3_out,
      c_g3_out  => c_g3_out,
      sig_state => sig_state
    );

  gamma_final_pe_inst : entity work.gamma_final_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      s1_gf_in  => s_a3_out,
      s2_gf_in  => s1_af_out,
      c_gf_in   => c_g3_out,
      s1_gf_out => s1_gf_out,
      s2_gf_out => s2_gf_out
    );

end architecture behavior;