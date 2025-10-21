library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity beta_pe_tb is
end entity beta_pe_tb;

architecture sim of beta_pe_tb is
  -- Testbench parameters
  constant WORD_WIDTH : integer := 8;
  constant CLK_PERIOD : time := 10 ns;
  
  -- Signals
  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal p_marked  : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal p_zero    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_b_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal m         : unsigned(WORD_WIDTH-1 downto 0);
  signal c_b_out   : unsigned(WORD_WIDTH-1 downto 0);
  
begin
  -- Device Under Test
  dut : entity work.beta_pe
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      reset     => reset,
      p_marked  => p_marked,
      p_zero    => p_zero,
      s_b_in    => s_b_in,
      m         => m,
      c_b_out   => c_b_out
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
    report "Starting beta_pe testbench";
    
    -- Apply reset
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);
    report "Reset completed";
    
    -- Test 1: Basic values
    -- m = (s_b_in * p_marked) low word
    -- c_b_out = (s_b_in + m * p_zero) high word
    p_marked <= to_unsigned(5, WORD_WIDTH);
    p_zero <= to_unsigned(3, WORD_WIDTH);
    s_b_in <= to_unsigned(10, WORD_WIDTH);
    wait until rising_edge(clk);
    wait for 1 ns;  -- Small delay after clock edge to read outputs
    report "Test 1: p_marked=" & integer'image(to_integer(p_marked)) & 
           ", p_zero=" & integer'image(to_integer(p_zero)) & 
           ", s_b_in=" & integer'image(to_integer(s_b_in)) &
           " -> m=" & integer'image(to_integer(m)) & 
           ", c_b_out=" & integer'image(to_integer(c_b_out));
    
    -- Test 2: Different values
    p_marked <= to_unsigned(7, WORD_WIDTH);
    p_zero <= to_unsigned(4, WORD_WIDTH);
    s_b_in <= to_unsigned(20, WORD_WIDTH);
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 2: p_marked=" & integer'image(to_integer(p_marked)) & 
           ", p_zero=" & integer'image(to_integer(p_zero)) & 
           ", s_b_in=" & integer'image(to_integer(s_b_in)) &
           " -> m=" & integer'image(to_integer(m)) & 
           ", c_b_out=" & integer'image(to_integer(c_b_out));
    
    -- Test 3: Larger values to test overflow
    p_marked <= to_unsigned(100, WORD_WIDTH);
    p_zero <= to_unsigned(150, WORD_WIDTH);
    s_b_in <= to_unsigned(200, WORD_WIDTH);
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 3: p_marked=" & integer'image(to_integer(p_marked)) & 
           ", p_zero=" & integer'image(to_integer(p_zero)) & 
           ", s_b_in=" & integer'image(to_integer(s_b_in)) &
           " -> m=" & integer'image(to_integer(m)) & 
           ", c_b_out=" & integer'image(to_integer(c_b_out));
    
    -- Test 4: Edge case with maximum values
    p_marked <= to_unsigned(255, WORD_WIDTH);
    p_zero <= to_unsigned(255, WORD_WIDTH);
    s_b_in <= to_unsigned(255, WORD_WIDTH);
    wait until rising_edge(clk);
    wait for 1 ns;
    report "Test 4: p_marked=" & integer'image(to_integer(p_marked)) & 
           ", p_zero=" & integer'image(to_integer(p_zero)) & 
           ", s_b_in=" & integer'image(to_integer(s_b_in)) &
           " -> m=" & integer'image(to_integer(m)) & 
           ", c_b_out=" & integer'image(to_integer(c_b_out));
    
    report "Testbench completed successfully" severity note;
    wait;
  end process;

end architecture sim;
