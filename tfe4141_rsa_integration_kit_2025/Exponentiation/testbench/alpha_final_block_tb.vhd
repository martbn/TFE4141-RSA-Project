library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha_final_block_tb is
end entity;

architecture tb of alpha_final_block_tb is
  constant WORD_WIDTH : integer := 8;

  signal t_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s1_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_out  : unsigned(WORD_WIDTH-1 downto 0);

  component alpha_final is
    generic ( WORD_WIDTH : integer := 32 );
    port (
      t_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      s1_out  : out unsigned(WORD_WIDTH-1 downto 0);
      s2_out  : out unsigned(WORD_WIDTH-1 downto 0)
    );
  end component;

begin
  -- Instantiate DUT
  dut: alpha_final
    generic map ( WORD_WIDTH => WORD_WIDTH )
    port map (
      t_in   => t_in,
      c_in   => c_in,
      s1_out => s1_out,
      s2_out => s2_out
    );

  -- Stimulus
  stim: process
  begin
    wait for 20 ns;

    -- Test vector 1
    t_in <= to_unsigned(10, WORD_WIDTH);
    c_in <= to_unsigned(5, WORD_WIDTH);
    wait for 10 ns;
    report "Test 1: t_in=10, c_in=5 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    -- Test vector 2
    t_in <= to_unsigned(100, WORD_WIDTH);
    c_in <= to_unsigned(200, WORD_WIDTH);
    wait for 10 ns;
    report "Test 2: t_in=100, c_in=200 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    -- Test vector 3
    t_in <= to_unsigned(255, WORD_WIDTH);
    c_in <= to_unsigned(255, WORD_WIDTH);
    wait for 10 ns;
    report "Test 3: t_in=255, c_in=255 => s1_out=" & 
           integer'image(to_integer(s1_out)) & 
           ", s2_out=" & integer'image(to_integer(s2_out));

    wait for 100 ns;
    report "ALPHA_FINAL TESTBENCH COMPLETE - waveform remains open" severity note;
    wait;
  end process;

end architecture tb;
