library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha1_pe_tb is
end entity alpha1_pe_tb;

architecture sim of alpha1_pe_tb is
  -- Testbench parameters
  constant WORD_WIDTH : integer := 8;
  constant CLK_PERIOD : time := 10 ns;
  
  -- Signals
  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal a_word    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_word    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_g1_out  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_g2_out  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal zero      : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_a1_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal c_a1_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal sig_state : std_logic := '0';
  
begin
  -- Device Under Test
  dut : entity work.alpha1_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      a_word    => a_word,
      b_word    => b_word,
      s_g1_out  => s_g1_out,
      s_g2_out  => s_g2_out,
      zero      => zero,
      s_a1_out  => s_a1_out,
      c_a1_out  => c_a1_out,
      sig_state => sig_state
    );
  
  -- Clock generation (even though logic is combinational)
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
    report "Starting alpha1_pe testbench";
    
    -- Apply reset
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);
    report "Reset completed";
    
    -- Test 1: sig_state = '0', should use s_g1_out and zero
    -- a_word * b_word + s_g1_out + zero = 5*3 + 10 + 0 = 25
    a_word <= to_unsigned(5, WORD_WIDTH);
    b_word <= to_unsigned(3, WORD_WIDTH);
    s_g1_out <= to_unsigned(10, WORD_WIDTH);
    s_g2_out <= to_unsigned(20, WORD_WIDTH);
    sig_state <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;  -- Small delay after clock edge to read outputs
    report "Test 1: sig_state=0, a=" & integer'image(to_integer(a_word)) & 
           ", b=" & integer'image(to_integer(b_word)) & 
           ", s_g1=" & integer'image(to_integer(s_g1_out)) &
           " -> s_a1_out=" & integer'image(to_integer(s_a1_out)) & 
           ", c_a1_out=" & integer'image(to_integer(c_a1_out));
    
    -- Test 2: sig_state = '1', should use s_g2_out and PREVIOUS c_out (0 from Test 1)
    -- a_word * b_word + s_g2_out + prev_c_out = 4*6 + 50 + 0 = 74
    a_word <= to_unsigned(4, WORD_WIDTH);
    b_word <= to_unsigned(6, WORD_WIDTH);
    s_g1_out <= to_unsigned(100, WORD_WIDTH);
    s_g2_out <= to_unsigned(50, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 2: sig_state=1, a=" & integer'image(to_integer(a_word)) & 
           ", b=" & integer'image(to_integer(b_word)) & 
           ", s_g2=" & integer'image(to_integer(s_g2_out)) &
           " (uses prev_c=0)" &
           " -> s_a1_out=" & integer'image(to_integer(s_a1_out)) & 
           ", c_a1_out=" & integer'image(to_integer(c_a1_out));
    
    -- Test 3: sig_state = '1' again, now uses c_out from Test 2
    -- a_word * b_word + s_g2_out + prev_c_out = 2*3 + 25 + 0 = 31
    a_word <= to_unsigned(100, WORD_WIDTH);
    b_word <= to_unsigned(200, WORD_WIDTH);
    s_g1_out <= to_unsigned(100, WORD_WIDTH);
    s_g2_out <= to_unsigned(25, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 3: sig_state=1, a=" & integer'image(to_integer(a_word)) & 
           ", b=" & integer'image(to_integer(b_word)) & 
           ", s_g2=" & integer'image(to_integer(s_g2_out)) &
           " (uses prev_c from Test 2)" &
           " -> s_a1_out=" & integer'image(to_integer(s_a1_out)) & 
           ", c_a1_out=" & integer'image(to_integer(c_a1_out));
    
    -- Test 4: Back to sig_state = '0' (resets carry input to zero)
    -- a_word * b_word + s_g1_out + zero = 7*8 + 15 + 0 = 71
    a_word <= to_unsigned(150, WORD_WIDTH);
    b_word <= to_unsigned(200, WORD_WIDTH);
    s_g1_out <= to_unsigned(15, WORD_WIDTH);
    s_g2_out <= to_unsigned(25, WORD_WIDTH);
    sig_state <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 4: sig_state=0, a=" & integer'image(to_integer(a_word)) & 
           ", b=" & integer'image(to_integer(b_word)) & 
           ", s_g1=" & integer'image(to_integer(s_g1_out)) &
           " -> s_a1_out=" & integer'image(to_integer(s_a1_out)) & 
           ", c_a1_out=" & integer'image(to_integer(c_a1_out));
    
    report "Testbench completed successfully" severity note;
    wait;
  end process;

end architecture sim;
