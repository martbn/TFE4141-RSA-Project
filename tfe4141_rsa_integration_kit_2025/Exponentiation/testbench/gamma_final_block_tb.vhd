library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma_final_block_tb is
end entity;

architecture tb of gamma_final_block_tb is
  constant WORD_WIDTH : integer := 8;

  signal s1_in   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s2_in   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s1_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_out  : unsigned(WORD_WIDTH-1 downto 0);

  component gamma_final is
    generic ( WORD_WIDTH : integer := 32 );
    port (
      s1_in   : in  unsigned(WORD_WIDTH-1 downto 0);
      s2_in   : in  unsigned(WORD_WIDTH-1 downto 0);
      c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      s1_out  : out unsigned(WORD_WIDTH-1 downto 0);
      s2_out  : out unsigned(WORD_WIDTH-1 downto 0)
    );
  end component;

begin
  -- Instantiate DUT
  dut: gamma_final
    generic map ( WORD_WIDTH => WORD_WIDTH )
    port map (
      s1_in  => s1_in,
      s2_in  => s2_in,
      c_in   => c_in,
      s1_out => s1_out,
      s2_out => s2_out
    );

  -- Stimulus
  stim: process
  begin
    wait for 20 ns;

    -- Test vector 1
    s1_in <= to_unsigned(10, WORD_WIDTH);
    s2_in <= to_unsigned(20, WORD_WIDTH);
    c_in  <= to_unsigned(5, WORD_WIDTH);
    wait for 10 ns;
    report "Test 1: s1_in=10, s2_in=20, c_in=5 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    -- Test vector 2
    s1_in <= to_unsigned(100, WORD_WIDTH);
    s2_in <= to_unsigned(50, WORD_WIDTH);
    c_in  <= to_unsigned(200, WORD_WIDTH);
    wait for 10 ns;
    report "Test 2: s1_in=100, s2_in=50, c_in=200 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    -- Test vector 3
    s1_in <= to_unsigned(255, WORD_WIDTH);
    s2_in <= to_unsigned(255, WORD_WIDTH);
    c_in  <= to_unsigned(255, WORD_WIDTH);
    wait for 10 ns;
    report "Test 3: s1_in=255, s2_in=255, c_in=255 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    wait for 100 ns;
    report "GAMMA_FINAL TESTBENCH COMPLETE - waveform remains open" severity note;
    wait;
  end process;

end architecture tb;
