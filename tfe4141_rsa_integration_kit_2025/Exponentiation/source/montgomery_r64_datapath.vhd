
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
    
    n_operand  : in  unsigned(OPERAND_WIDTH-1 downto 0);
    n_marked_operand  : in  unsigned(WORD_WIDTH-1 downto 0);

    sig_state   : in  std_logic;
    shift_a : in std_logic;
    shift_b : in std_logic;
    --first_Outer_loop_state : in unsigned(1 downto 0);
    result_out  : out unsigned(OPERAND_WIDTH + WORD_WIDTH -1 downto 0);
    last_outer_loop_state : in unsigned(3 downto 0);

    activate_gamma_final : in std_logic;
    activate_gamma1 : in std_logic;
    activate_gamma2 : in std_logic;
    activate_gamma3 : in std_logic;
    activate_beta : in std_logic;
    activate_alpha1 : in std_logic;
    activate_alpha2 : in std_logic;
    activate_alpha3 : in std_logic;
    activate_alpha_final : in std_logic;
    
    -- Debug outputs for gamma signals
    s_g1_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    s_g2_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    s_g3_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    s1_gf_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    
    -- Debug outputs for alpha signals
    s_a1_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    s_a2_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    s_a3_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_a1_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_a2_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_a3_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    
    -- Debug outputs for UNREGISTERED alpha carries (when produced)
    c_a1_out_immediate_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_a2_out_immediate_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_a3_out_immediate_debug : out unsigned(WORD_WIDTH-1 downto 0);
    
    -- Debug outputs for beta signals
    m_debug : out unsigned(WORD_WIDTH-1 downto 0);
    c_b_out_debug : out unsigned(WORD_WIDTH-1 downto 0);
    
    -- Debug outputs for operand words
    a_first_word_debug : out unsigned(WORD_WIDTH-1 downto 0);
    a_middle_word_debug : out unsigned(WORD_WIDTH-1 downto 0);
    a_last_word_debug : out unsigned(WORD_WIDTH-1 downto 0);
    b_first_correct_debug : out unsigned(WORD_WIDTH-1 downto 0);
    b_middle_correct_debug : out unsigned(WORD_WIDTH-1 downto 0);
    b_last_correct_debug : out unsigned(WORD_WIDTH-1 downto 0)

  );
end entity montgomery_r64_datapath;

architecture behavior of montgomery_r64_datapath is

  -- Calculate number of words
  constant NUM_WORDS : integer := OPERAND_WIDTH / WORD_WIDTH;

  -- Signals for interconnecting processing elements
  signal a_operand_sig : unsigned(OPERAND_WIDTH-1 downto 0);
  signal b_operand_sig : unsigned(OPERAND_WIDTH-1 downto 0);
  signal n_operand_sig : unsigned(OPERAND_WIDTH-1 downto 0);

  signal b_first_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_middle_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_last_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');



  signal a_first_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal a_middle_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal a_last_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');

  signal zero : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');

  -- Alpha PE signals
  signal s_a1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_a1_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered for gamma inputs
  signal c_a1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a1_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from alpha1
  signal s_a2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_a2_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered for gamma inputs
  signal c_a2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a2_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from alpha2
  signal s_a3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s_a3_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered for gamma inputs
  signal c_a3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a3_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from alpha3
  signal s1_af_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_af_out : unsigned(WORD_WIDTH-1 downto 0);

  -- Beta PE signals
  signal m : unsigned(WORD_WIDTH-1 downto 0);
  signal m_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered version of m
  signal c_b_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_b_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from beta

  -- Gamma PE signals
  signal s_g1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g1_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from gamma1
  signal s_g2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g2_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g2_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from gamma2
  signal s_g3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g3_out : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g3_out_reg : unsigned(WORD_WIDTH-1 downto 0);  -- Registered carry from gamma3
  signal s1_gf_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_gf_out : unsigned(WORD_WIDTH-1 downto 0);

  -- P operand words
 
  signal n_0 : unsigned(WORD_WIDTH-1 downto 0);
  signal n_1 : unsigned(WORD_WIDTH-1 downto 0);
  signal n_2 : unsigned(WORD_WIDTH-1 downto 0);
  signal n_3 : unsigned(WORD_WIDTH-1 downto 0);
 
  signal n_marked : unsigned(WORD_WIDTH-1 downto 0);


  signal alpha1_in_s_g1 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha1_in_s_g2 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha2_in_s_g2 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha2_in_s_g3 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha3_in_s_g3 : unsigned(WORD_WIDTH-1 downto 0);
  signal alpha3_in_s1_gf : unsigned(WORD_WIDTH-1 downto 0);


  signal result : unsigned(OPERAND_WIDTH + WORD_WIDTH -1 downto 0);


begin
  a_operand_sig <= a_operand;
  b_operand_sig <= b_operand;
  n_operand_sig <= n_operand;

  -- Register all PE outputs to break combinational paths
  -- This ensures all modules use values from the PREVIOUS clock cycle
  register_pe_outputs: process(clk, reset)
  begin
    if reset = '1' then
      -- Alpha to next alpha stage
      c_a1_out_reg <= (others => '0');
      c_a2_out_reg <= (others => '0');
      c_a3_out_reg <= (others => '0');
      
      -- Alpha to gamma (for gamma inputs)
      s_a1_out_reg <= (others => '0');
      s_a2_out_reg <= (others => '0');
      s_a3_out_reg <= (others => '0');
      
      -- Beta to gamma
      c_b_out_reg <= (others => '0');
      m_reg <= (others => '0');
      
      -- Gamma to next gamma stage
      c_g1_out_reg <= (others => '0');
      c_g2_out_reg <= (others => '0');
      c_g3_out_reg <= (others => '0');
      
      -- Gamma to alpha (for next iteration feedback)
      alpha1_in_s_g1 <= (others => '0');
      alpha1_in_s_g2 <= (others => '0');
      alpha2_in_s_g2 <= (others => '0');
      alpha2_in_s_g3 <= (others => '0');
      alpha3_in_s_g3 <= (others => '0');
      alpha3_in_s1_gf <= (others => '0');
    elsif rising_edge(clk) then
      -- Register alpha carries
      c_a1_out_reg <= c_a1_out;
      c_a2_out_reg <= c_a2_out;
      c_a3_out_reg <= c_a3_out;
      
      -- Register alpha sums for gamma
      s_a1_out_reg <= s_a1_out;
      s_a2_out_reg <= s_a2_out;
      s_a3_out_reg <= s_a3_out;
      
      -- Register beta outputs every cycle
      -- Beta is only valid in STATE2, but we capture every cycle
      -- so the STATE2 value is available in STATE3
      c_b_out_reg <= c_b_out;
      m_reg <= m;
      
      -- Register gamma carries
      c_g1_out_reg <= c_g1_out;
      c_g2_out_reg <= c_g2_out;
      c_g3_out_reg <= c_g3_out;
      
      -- Register gamma sums for alpha (next iteration feedback)
      alpha1_in_s_g1 <= s_g1_out;
      alpha1_in_s_g2 <= s_g2_out;
      alpha2_in_s_g2 <= s_g2_out;
      alpha2_in_s_g3 <= s_g3_out;
      alpha3_in_s_g3 <= s_g3_out;
      alpha3_in_s1_gf <= s1_gf_out;
    end if;
  end process;

  -- Assign input operands to internal signals
  -- Note: b_first3, b_middle3, b_last2 are loaded at reset in shift_b_p_process
  -- Note: b_first_correct, b_middle_correct, b_last_correct are driven by shift_b_p_process
  -- Note: a_first_word, a_middle_word, a_last_word are driven by shift_a_process
  -- Note: p_0, p_1 are driven combinatorially, p_2, p_3 driven by shift_b_p_process
  -- Do not assign them here to avoid multiple drivers

  zero <= (others => '0');

  -- Extract P operand words (p_0 and p_1 don't change, p_2 and p_3 are shifted)
  

  n_marked <= n_marked_operand(WORD_WIDTH-1 downto 0);


  -- ========================================================================
  

 

  --  mux_alpha_inputs: process(clk, reset)
  --  begin
  --    if reset = '1' then
  --      alpha1_in_s_g1 <= (others => '0');
  --      alpha1_in_s_g2 <= (others => '0');
  --      alpha2_in_s_g2 <= (others => '0');
  --      alpha2_in_s_g3 <= (others => '0');
  --      alpha3_in_s_g3 <= (others => '0');
  --      alpha3_in_s1_gf <= (others => '0');
  --    elsif clk'event and clk = '1' then
  --      
  --      if first_Outer_loop_state = "01" then
  --        alpha1_in_s_g1 <= s_g1_out;
  --        alpha1_in_s_g2 <= s_g2_out;
  --      elsif first_Outer_loop_state = "10" then
  --        alpha1_in_s_g1 <= s_g1_out;
  --        alpha1_in_s_g2 <= s_g2_out;
  --        alpha2_in_s_g2 <= s_g2_out;
  --        alpha2_in_s_g3 <= s_g3_out;
  --      elsif first_Outer_loop_state = "11" then
  --        alpha1_in_s_g1 <= s_g1_out;
  --        alpha1_in_s_g2 <= s_g2_out;
  --        alpha2_in_s_g2 <= s_g2_out;
  --        alpha2_in_s_g3 <= s_g3_out;
  --        alpha3_in_s_g3 <= s_g3_out;
  --        alpha3_in_s1_gf <= s1_gf_out;
  --      else
  --        alpha1_in_s_g1 <= (others => '0');
  --        alpha1_in_s_g2 <= (others => '0');
  --        alpha2_in_s_g2 <= (others => '0');
  --        alpha2_in_s_g3 <= (others => '0');
  --        alpha3_in_s_g3 <= (others => '0');
  --        alpha3_in_s1_gf <= (others => '0');
  --      end if;
  --    end if;
  --  end process;

  result_process : process(clk, reset)
  begin
    if reset = '1' then
      result_out <= (others => '0');
    elsif rising_edge(clk) then
      -- Collect result by shifting in gamma outputs word by word
      case last_outer_loop_state is
        when "0001" =>
          result_out <= (others => '0');  -- Clear result first
          result_out(WORD_WIDTH-1 downto 0) <= s_g1_out;
        when "0010" =>
          result_out(2*WORD_WIDTH-1 downto WORD_WIDTH) <= s_g2_out;
        when "0011" =>
          result_out(3*WORD_WIDTH-1 downto 2*WORD_WIDTH) <= s_g2_out;
        when "0100" =>
          result_out(4*WORD_WIDTH-1 downto 3*WORD_WIDTH) <= s_g2_out;
        when "0101" =>
          result_out(5*WORD_WIDTH-1 downto 4*WORD_WIDTH) <= s_g3_out;
        when "0110" =>
          result_out(6*WORD_WIDTH-1 downto 5*WORD_WIDTH) <= s_g3_out;
        when "0111" =>
          result_out(7*WORD_WIDTH-1 downto 6*WORD_WIDTH) <= s_g3_out;
        when "1000" =>
          result_out(8*WORD_WIDTH-1 downto 7*WORD_WIDTH) <= s1_gf_out;
          result_out(9*WORD_WIDTH-1 downto 8*WORD_WIDTH) <= s2_gf_out;
        when others =>
          result_out <= result_out;
      end case;
    end if;
  end process;

  -- ========================================================================
  -- Alpha Processing Elements
  -- ========================================================================

  shifter_inst : entity work.shifter_r64
    generic map (
      WIDTH_WORD => WORD_WIDTH,
      WIDTH_OPERAND => OPERAND_WIDTH
    )
    port map (
      clk => clk,
      reset => reset,
      shift_a => shift_a,
      shift_b => shift_b,
      A => a_operand_sig,
      B => b_operand_sig,
      N => n_operand_sig,
      a_first_word => a_first_word,
      a_middle_word => a_middle_word,
      a_last_word => a_last_word,
      b_first_word => b_first_word,
      b_middle_word => b_middle_word,
      b_last_word => b_last_word,
      n_0_word => n_0,
      n_1_word => n_1,
      n_2_word => n_2,
      n_3_word => n_3
    );

  alpha1_pe_inst : entity work.alpha1_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      activate_module => activate_alpha1,
      a_word    => a_first_word,
      b_word    => b_first_word,
      s_g1_out  => alpha1_in_s_g1,
      s_g2_out  => alpha1_in_s_g2,
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
      activate_module => activate_alpha2,
      a_word    => a_middle_word,
      b_word    => b_middle_word,
      s_g2_out  => alpha2_in_s_g2,
      s_g3_out  => alpha2_in_s_g3,
      c_a1_out  => c_a1_out,  -- Use UNREGISTERED carry (alpha2 has internal register)
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
      activate_module => activate_alpha3,
      a_word    => a_last_word,
      b_word    => b_last_word,
      s1_gf_out => alpha3_in_s1_gf,
      s_g3_out  => alpha3_in_s_g3,
      c_a2_out  => c_a2_out,  -- Use UNREGISTERED carry (alpha3 has internal register)
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
      activate_module => activate_alpha_final,
      s_af_in   => s2_gf_out,
      c_af_in   => c_a3_out,  -- Use UNREGISTERED carry (alpha_final doesn't loop back)
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
      activate_module => activate_beta,
      p_marked  => n_marked,
      p_zero    => n_0,
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
      activate_module => activate_gamma1,
      m         => m,              -- Use UNREGISTERED beta output (same cycle)
      p_i       => n_1,
      s_g1_in   => s_a1_out_reg,  -- Use registered alpha output
      c_g1_in   => c_b_out,        -- Use UNREGISTERED beta carry (same cycle)
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
      activate_module => activate_gamma2,
      m         => m,              -- Use UNREGISTERED beta output (same cycle)
      p_i       => n_2,
      s_a1_out  => s_a1_out_reg,  -- Use registered alpha output
      s_a2_out  => s_a2_out_reg,  -- Use registered alpha output
      c_g1_out  => c_g1_out_reg,  -- Use registered gamma1 carry
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
      activate_module => activate_gamma3,
      m         => m,              -- Use UNREGISTERED beta output (same cycle)
      p_i       => n_3,
      s_a2_out  => s_a2_out_reg,  -- Use registered alpha output
      s_a3_out  => s_a3_out_reg,  -- Use registered alpha output
      c_g2_out  => c_g2_out_reg,  -- Use registered gamma2 carry
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
      activate_module => activate_gamma_final,
      s1_gf_in  => s_a3_out_reg,  -- Use registered alpha output
      s2_gf_in  => s1_af_out,
      c_gf_in   => c_g3_out_reg,  -- Use registered gamma3 carry
      s1_gf_out => s1_gf_out,
      s2_gf_out => s2_gf_out
    );
  
  -- Connect debug outputs
  -- Alpha/Gamma sum outputs: show immediate (unregistered) for debugging when they compute
  s_g1_out_debug <= s_g1_out;
  s_g2_out_debug <= s_g2_out;
  s_g3_out_debug <= s_g3_out;
  s1_gf_out_debug <= s1_gf_out;
  s_a1_out_debug <= s_a1_out;      -- Show immediate alpha1 output
  s_a2_out_debug <= s_a2_out;      -- Show immediate alpha2 output
  s_a3_out_debug <= s_a3_out;      -- Show immediate alpha3 output
  
  -- Carry outputs: show BOTH immediate (when produced) and registered (when used)
  c_a1_out_immediate_debug <= c_a1_out;  -- Show when alpha1 produces it
  c_a2_out_immediate_debug <= c_a2_out;  -- Show when alpha2 produces it
  c_a3_out_immediate_debug <= c_a3_out;  -- Show when alpha3 produces it
  
  c_a1_out_debug <= c_a1_out_reg;  -- Show registered carry used by alpha2 (one cycle later)
  c_a2_out_debug <= c_a2_out_reg;  -- Show registered carry used by alpha3 (one cycle later)
  c_a3_out_debug <= c_a3_out_reg;  -- Show registered carry used by alpha_final (one cycle later)
  
  m_debug <= m;                    -- Show beta m output
  c_b_out_debug <= c_b_out;        -- Show beta carry output
  
  -- Connect operand word debug outputs
  a_first_word_debug <= a_first_word;
  a_middle_word_debug <= a_middle_word;
  a_last_word_debug <= a_last_word;
  b_first_correct_debug <= b_first_word;
  b_middle_correct_debug <= b_middle_word;
  b_last_correct_debug <= b_last_word;
  

end architecture behavior;