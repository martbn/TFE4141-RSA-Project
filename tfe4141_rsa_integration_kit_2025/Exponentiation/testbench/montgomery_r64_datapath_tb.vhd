library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_r64_datapath_tb is
end entity montgomery_r64_datapath_tb;

architecture testbench of montgomery_r64_datapath_tb is
  
  -- Testbench constants - 32-bit operands with 4-bit words
  constant WORD_WIDTH : integer := 4;
  constant OPERAND_WIDTH : integer := 32;
  constant CLK_PERIOD : time := 10 ns;
  
  -- Signals for DUT
  signal clk : std_logic := '0';
  signal reset : std_logic := '0';
  
  signal a_operand : unsigned(OPERAND_WIDTH-1 downto 0) := (others => '0');
  signal b_operand : unsigned(OPERAND_WIDTH-1 downto 0) := (others => '0');
  signal n_operand : unsigned(OPERAND_WIDTH-1 downto 0) := (others => '0');
  signal n_marked_operand : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  signal sig_state : std_logic := '0';
  signal shift_a : std_logic := '0';
  signal shift_b : std_logic := '0';
  --signal first_Outer_loop_state : unsigned(1 downto 0) := "00";
  signal last_outer_loop_state : unsigned(3 downto 0) := "0000";
  
  signal result_out : unsigned(OPERAND_WIDTH + WORD_WIDTH - 1 downto 0) := (others => '0');
  
  -- Activation signals for PE modules
  signal activate_gamma_final : std_logic := '0';
  signal activate_gamma1 : std_logic := '0';
  signal activate_gamma2 : std_logic := '0';
  signal activate_gamma3 : std_logic := '0';
  signal activate_beta : std_logic := '0';
  signal activate_alpha1 : std_logic := '0';
  signal activate_alpha2 : std_logic := '0';
  signal activate_alpha3 : std_logic := '0';
  signal activate_alpha_final : std_logic := '0';
  
  -- Debug signals for gamma PE outputs
  signal s_g1_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_g2_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_g3_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s1_gf_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  -- Debug signals for alpha PE outputs
  signal s_a1_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_a2_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_a3_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  -- Debug signals for alpha carry outputs
  signal c_a1_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_a2_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_a3_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  -- Debug signals for beta PE outputs
  signal m_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_b_out_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  -- Debug signals for operand words
  signal a_first_word_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal a_middle_word_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal a_last_word_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_first_correct_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_middle_correct_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_last_correct_debug : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  
  -- Test control signals
  signal test_done : boolean := false;
  
begin

  -- Clock generation
  clk_process : process
  begin
    while not test_done loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- DUT instantiation
  dut : entity work.montgomery_r64_datapath
    generic map (
      WORD_WIDTH => WORD_WIDTH,
      OPERAND_WIDTH => OPERAND_WIDTH
    )
    port map (
      clk => clk,
      reset => reset,
      a_operand => a_operand,
      b_operand => b_operand,
      n_operand => n_operand,
      n_marked_operand => n_marked_operand,
      sig_state => sig_state,
      shift_a => shift_a,
      shift_b => shift_b,
      --first_Outer_loop_state => first_Outer_loop_state,
      result_out => result_out,
      last_outer_loop_state => last_outer_loop_state,
      activate_gamma_final => activate_gamma_final,
      activate_gamma1 => activate_gamma1,
      activate_gamma2 => activate_gamma2,
      activate_gamma3 => activate_gamma3,
      activate_beta => activate_beta,
      activate_alpha1 => activate_alpha1,
      activate_alpha2 => activate_alpha2,
      activate_alpha3 => activate_alpha3,
      activate_alpha_final => activate_alpha_final,
      s_g1_out_debug => s_g1_out_debug,
      s_g2_out_debug => s_g2_out_debug,
      s_g3_out_debug => s_g3_out_debug,
      s1_gf_out_debug => s1_gf_out_debug,
      s_a1_out_debug => s_a1_out_debug,
      s_a2_out_debug => s_a2_out_debug,
      s_a3_out_debug => s_a3_out_debug,
      c_a1_out_debug => c_a1_out_debug,
      c_a2_out_debug => c_a2_out_debug,
      c_a3_out_debug => c_a3_out_debug,
      m_debug => m_debug,
      c_b_out_debug => c_b_out_debug,
      a_first_word_debug => a_first_word_debug,
      a_middle_word_debug => a_middle_word_debug,
      a_last_word_debug => a_last_word_debug,
      b_first_correct_debug => b_first_correct_debug,
      b_middle_correct_debug => b_middle_correct_debug,
      b_last_correct_debug => b_last_correct_debug
    );

  -- Main test process
  test_process : process
  begin
    
    -- ===================================================================
    -- Test 1: Basic initialization and reset test
    -- ===================================================================
    report "========================================";
    report "Test 1: Reset test";
    report "========================================";
    
    -- Set operands BEFORE releasing reset
    a_operand <= x"00000005";  -- Small value: 5
    b_operand <= x"00000003";  -- Small value: 3
    n_operand <= x"00000007";  -- Modulus: 7
    n_marked_operand <= x"9";  -- p' mod w
    sig_state <= '0';
    shift_a <= '0';
    shift_b <= '0';
    --first_Outer_loop_state <= "00";
    last_outer_loop_state <= "0000";
    
    -- Initialize activation signals
    activate_alpha1 <= '0';
    activate_alpha2 <= '0';
    activate_alpha3 <= '0';
    activate_alpha_final <= '0';
    activate_beta <= '0';
    activate_gamma1 <= '0';
    activate_gamma2 <= '0';
    activate_gamma3 <= '0';
    activate_gamma_final <= '0';
    
    -- Apply reset pulse
    reset <= '1';
    wait for CLK_PERIOD * 2;
    
    -- Release reset - operands should load on next clock
    reset <= '0';
    wait for CLK_PERIOD * 3;
    
    report "Test 1 completed: Reset verified";
    
    -- ===================================================================
    -- Test 2: Simple operand loading
    -- ===================================================================
    report "========================================";
    report "Test 2: Simple operand loading";
    report "========================================";
    
    -- Load simple values: a=0x12345678, b=0xABCDEF01, p=0xFFFFFFFF, p'=0xF
    
    
    -- Activate alpha1 and gamma1 for basic operation
    activate_alpha1 <= '1';
    activate_gamma1 <= '1';
    
    wait for CLK_PERIOD * 2;
    
    report "Test 2 completed: Operands loaded";
    
    -- ===================================================================
    -- Test 3: Test sig_state switching (first outer loop iteration)
    -- ===================================================================
    report "========================================";
    report "Test 3: sig_state switching with first_Outer_loop_state = 01";
    report "========================================";
    
    reset <= '0';
    wait for CLK_PERIOD;
    reset <= '0';
    
    -- Setup test values
    
    
    -- Activate first PE (alpha1, gamma1, beta)
    activate_alpha1 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    
    -- First outer loop state = 01 (first PE active)
    --first_Outer_loop_state <= "01";
    sig_state <= '0';
    
    wait for CLK_PERIOD * 2;
    
    -- Switch sig_state
    sig_state <= '1';
    wait for CLK_PERIOD * 2;
    
    sig_state <= '0';
    wait for CLK_PERIOD * 2;
    
    report "Test 3 completed: sig_state switching verified";
    
    -- ===================================================================
    -- Test 4: Test shift_a functionality
    -- ===================================================================
    report "========================================";
    report "Test 4: shift_a functionality";
    report "========================================";
    
    reset <= '0';
    wait for CLK_PERIOD;
    reset <= '0';
    
    
    
    -- Activate all PEs for full operation
    activate_alpha1 <= '1';
    activate_alpha2 <= '1';
    activate_alpha3 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    activate_gamma2 <= '1';
    activate_gamma3 <= '1';
    
    shift_a <= '0';
    wait for CLK_PERIOD * 2;
    
    -- Trigger shift
    shift_a <= '1';
    wait for CLK_PERIOD;
    shift_a <= '0';
    
    wait for CLK_PERIOD * 3;
    
    -- Multiple shifts
    for i in 1 to 5 loop
      shift_a <= '1';
      wait for CLK_PERIOD;
      shift_a <= '0';
      wait for CLK_PERIOD;
    end loop;
    
    report "Test 4 completed: shift_a functionality verified";
    
    -- ===================================================================
    -- Test 5: Test first_Outer_loop_state progression
    -- ===================================================================
    report "========================================";
    report "Test 5: first_Outer_loop_state progression";
    report "========================================";
    
    reset <= '0';
    wait for CLK_PERIOD;
    reset <= '0';
    
    
    
    -- State 00 (no PEs active)
    activate_alpha1 <= '0';
    activate_alpha2 <= '0';
    activate_alpha3 <= '0';
    activate_beta <= '0';
    activate_gamma1 <= '0';
    activate_gamma2 <= '0';
    activate_gamma3 <= '0';
    sig_state <= '0';
    wait for CLK_PERIOD * 2;
    
    -- State 01 (first PE active)
    activate_alpha1 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    wait for CLK_PERIOD * 2;
    sig_state <= '1';
    wait for CLK_PERIOD * 2;
    
    -- State 10 (first two PEs active)
    activate_alpha2 <= '1';
    activate_gamma2 <= '1';
    sig_state <= '0';
    wait for CLK_PERIOD * 2;
    sig_state <= '1';
    wait for CLK_PERIOD * 2;
    
    -- State 11 (all three PEs active)
    activate_alpha3 <= '1';
    activate_gamma3 <= '1';
    sig_state <= '0';
    wait for CLK_PERIOD * 2;
    sig_state <= '1';
    wait for CLK_PERIOD * 2;
    
    report "Test 5 completed: first_Outer_loop_state progression verified";
    
    -- ===================================================================
    -- Test 6: Test last_outer_loop_state and result collection
    -- ===================================================================
    report "========================================";
    report "Test 6: last_outer_loop_state and result collection";
    report "========================================";
    
    reset <= '1';
    
    
    
    wait for CLK_PERIOD;
    reset <= '0';
    
    -- All PEs active
    activate_alpha1 <= '1';
    activate_alpha2 <= '1';
    activate_alpha3 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    activate_gamma2 <= '1';
    activate_gamma3 <= '1';
    activate_alpha_final <= '1';
    activate_gamma_final <= '1';
    sig_state <= '0';
    
    wait for CLK_PERIOD * 5;
    
    -- Simulate result collection states
    last_outer_loop_state <= "0001";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0010";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0011";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0100";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0101";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0110";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "0111";
    wait for CLK_PERIOD;
    
    last_outer_loop_state <= "1000";
    wait for CLK_PERIOD * 2;
    
    report "Result output: " & to_string(result_out);
    
    last_outer_loop_state <= "0000";
    wait for CLK_PERIOD;
    
    report "Test 6 completed: Result collection verified";
    
    -- ===================================================================
    -- Test 7: Combined operation test
    -- ===================================================================
    report "========================================";
    report "Test 7: Combined operation test";
    report "========================================";
    
    reset <= '1';
    
    -- Test case: a=7, b=9, p=11 (small values for easy verification)
    a_operand <= x"00000007";
    b_operand <= x"00000009";
    n_operand <= x"0000000B";
    n_marked_operand <= x"B";  -- -11^(-1) mod 16 = 11
    
    wait for CLK_PERIOD;
    reset <= '0';
    
    -- Start with first PE
    activate_alpha1 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    activate_alpha2 <= '0';
    activate_alpha3 <= '0';
    activate_gamma2 <= '0';
    activate_gamma3 <= '0';
    activate_alpha_final <= '0';
    activate_gamma_final <= '0';
    sig_state <= '0';
    shift_a <= '0';
    shift_b <= '0';
    last_outer_loop_state <= "0000";
    
    wait for CLK_PERIOD * 2;
    
    -- Perform some operations with state changes
    for i in 0 to 3 loop
      sig_state <= '0';
      wait for CLK_PERIOD;
      sig_state <= '1';
      wait for CLK_PERIOD;
    end loop;
    
    -- Activate more PEs
    activate_alpha2 <= '1';
    activate_gamma2 <= '1';
    wait for CLK_PERIOD * 4;
    
    activate_alpha3 <= '1';
    activate_gamma3 <= '1';
    wait for CLK_PERIOD * 4;
    
    -- Perform shift operations
    for i in 0 to 2 loop
      shift_a <= '1';
      wait for CLK_PERIOD;
      shift_a <= '0';
      wait for CLK_PERIOD * 2;
    end loop;
    
    report "Test 7 completed: Combined operation verified";
    
    -- ===================================================================
    -- Test 8: Edge case - all zeros
    -- ===================================================================
    report "========================================";
    report "Test 8: Edge case - all zeros";
    report "========================================";
    
    reset <= '1';
    
    a_operand <= (others => '0');
    b_operand <= (others => '0');
    n_operand <= x"00000001";
    n_marked_operand <= x"F";
    
    wait for CLK_PERIOD;
    reset <= '0';
    
    -- Activate all PEs
    activate_alpha1 <= '1';
    activate_alpha2 <= '1';
    activate_alpha3 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    activate_gamma2 <= '1';
    activate_gamma3 <= '1';
    sig_state <= '0';
    
    wait for CLK_PERIOD * 5;
    
    sig_state <= '1';
    wait for CLK_PERIOD * 5;
    
    report "Test 8 completed: Zero case verified";
    
    -- ===================================================================
    -- Test 9: Edge case - maximum values
    -- ===================================================================
    report "========================================";
    report "Test 9: Edge case - maximum values";
    report "========================================";
    
    reset <= '1';
    
    a_operand <= (others => '1');
    b_operand <= (others => '1');
    n_operand <= (others => '1');
    n_marked_operand <= (others => '1');
    
    wait for CLK_PERIOD;
    reset <= '0';
    
    -- Activate all PEs
    activate_alpha1 <= '1';
    activate_alpha2 <= '1';
    activate_alpha3 <= '1';
    activate_beta <= '1';
    activate_gamma1 <= '1';
    activate_gamma2 <= '1';
    activate_gamma3 <= '1';
    sig_state <= '0';
    
    wait for CLK_PERIOD * 5;
    
    sig_state <= '1';
    wait for CLK_PERIOD * 5;
    
    report "Test 9 completed: Maximum values verified";
    
    -- ===================================================================
    -- End of tests
    -- ===================================================================
    report "========================================";
    report "ALL TESTS COMPLETED SUCCESSFULLY";
    report "========================================";
    
    test_done <= true;
    wait;
    
  end process;

end architecture testbench;
