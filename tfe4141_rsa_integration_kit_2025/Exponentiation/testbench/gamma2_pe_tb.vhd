library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma2_pe_tb is
end entity gamma2_pe_tb;

architecture sim of gamma2_pe_tb is
  -- Testbench parameters
  constant WORD_WIDTH : integer := 8;
  constant CLK_PERIOD : time := 10 ns;
  
  -- Signals
  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal m         : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal p_i       : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_a1_out  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_a2_out  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_g1_out  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_g2_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal c_g2_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal sig_state : std_logic := '0';
  
begin
  -- Device Under Test
  dut : entity work.gamma2_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      m         => m,
      p_i       => p_i,
      s_a1_out  => s_a1_out,
      s_a2_out  => s_a2_out,
      c_g1_out  => c_g1_out,
      s_g2_out  => s_g2_out,
      c_g2_out  => c_g2_out,
      sig_state => sig_state
    );
  
  -- Clock generation
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD/2;
    clk <= '1';
    wait for CLK_PERIOD/2;
  end process;
  
  -- Stimulus process
  stim_process: process
  begin
    report "Starting gamma2_pe testbench";
    
    -- Apply reset
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);
    report "Reset completed";
    
    -- Test 1: sig_state = '0', should use s_a1_out and c_g1_out
    -- m * p_i + s_a1_out + c_g1_out
    m <= to_unsigned(5, WORD_WIDTH);
    p_i <= to_unsigned(3, WORD_WIDTH);
    s_a1_out <= to_unsigned(10, WORD_WIDTH);
    s_a2_out <= to_unsigned(20, WORD_WIDTH);
    c_g1_out <= to_unsigned(2, WORD_WIDTH);
    sig_state <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;  -- Small delay after clock edge to read outputs
    report "Test 1: sig_state=0, m=" & integer'image(to_integer(m)) & 
           ", p_i=" & integer'image(to_integer(p_i)) & 
           ", s_a1=" & integer'image(to_integer(s_a1_out)) &
           ", c_g1=" & integer'image(to_integer(c_g1_out)) &
           " -> s_g2_out=" & integer'image(to_integer(s_g2_out)) & 
           ", c_g2_out=" & integer'image(to_integer(c_g2_out));
    
    -- Test 2: sig_state = '1', should use s_a2_out and PREVIOUS c_g2_out (0 from Test 1)
    -- m * p_i + s_a2_out + prev_c_g2_out
    m <= to_unsigned(4, WORD_WIDTH);
    p_i <= to_unsigned(6, WORD_WIDTH);
    s_a1_out <= to_unsigned(100, WORD_WIDTH);
    s_a2_out <= to_unsigned(50, WORD_WIDTH);
    c_g1_out <= to_unsigned(5, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 2: sig_state=1, m=" & integer'image(to_integer(m)) & 
           ", p_i=" & integer'image(to_integer(p_i)) & 
           ", s_a2=" & integer'image(to_integer(s_a2_out)) &
           " (uses prev_c=0)" &
           " -> s_g2_out=" & integer'image(to_integer(s_g2_out)) & 
           ", c_g2_out=" & integer'image(to_integer(c_g2_out));
    
    -- Test 3: sig_state = '1' again, now uses c_g2_out from Test 2
    -- m * p_i + s_a2_out + prev_c_g2_out
    m <= to_unsigned(100, WORD_WIDTH);
    p_i <= to_unsigned(200, WORD_WIDTH);
    s_a1_out <= to_unsigned(100, WORD_WIDTH);
    s_a2_out <= to_unsigned(25, WORD_WIDTH);
    c_g1_out <= to_unsigned(3, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 3: sig_state=1, m=" & integer'image(to_integer(m)) & 
           ", p_i=" & integer'image(to_integer(p_i)) & 
           ", s_a2=" & integer'image(to_integer(s_a2_out)) &
           " (uses prev_c from Test 2)" &
           " -> s_g2_out=" & integer'image(to_integer(s_g2_out)) & 
           ", c_g2_out=" & integer'image(to_integer(c_g2_out));
    
    -- Test 4: Back to sig_state = '0'
    -- m * p_i + s_a1_out + c_g1_out
    m <= to_unsigned(150, WORD_WIDTH);
    p_i <= to_unsigned(200, WORD_WIDTH);
    s_a1_out <= to_unsigned(15, WORD_WIDTH);
    s_a2_out <= to_unsigned(25, WORD_WIDTH);
    c_g1_out <= to_unsigned(7, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 4: sig_state=0, m=" & integer'image(to_integer(m)) & 
           ", p_i=" & integer'image(to_integer(p_i)) & 
           ", s_a1=" & integer'image(to_integer(s_a1_out)) &
           ", c_g1=" & integer'image(to_integer(c_g1_out)) &
           " -> s_g2_out=" & integer'image(to_integer(s_g2_out)) & 
           ", c_g2_out=" & integer'image(to_integer(c_g2_out));
    
    report "Testbench completed successfully" severity note;
    wait;
  end process;

end architecture sim;
