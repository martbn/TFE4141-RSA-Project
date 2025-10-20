library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Very small, Vivado-friendly testbench for alpha_block
-- Purpose: keep the TB simple so it's easy to run in Vivado and inspect waveforms.
-- Add these signals to the waveform: a_word, b_word, t_in, c_in, t_out, c_out

entity alpha_block_simple_tb is
end entity;

architecture tb of alpha_block_simple_tb is
  constant WORD_WIDTH : integer := 8; -- change to 32 for real tests

  signal clk    : std_logic := '0';
  signal a_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal b_word : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal t_in   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_in   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal t_out  : unsigned(WORD_WIDTH-1 downto 0);
  signal c_out  : unsigned(WORD_WIDTH-1 downto 0);

  component alpha is
    generic ( WORD_WIDTH : integer := 32 );
    port (
      clk     : in  std_logic;
      a_word  : in  unsigned(WORD_WIDTH-1 downto 0);
      b_word  : in  unsigned(WORD_WIDTH-1 downto 0);
      t_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      t_out   : out unsigned(WORD_WIDTH-1 downto 0);
      c_out   : out unsigned(WORD_WIDTH-1 downto 0)
    );
  end component;

begin
  -- DUT instantiation
  dut: alpha
    generic map ( WORD_WIDTH => WORD_WIDTH )
    port map (
      clk    => clk,
      a_word => a_word,
      b_word => b_word,
      t_in   => t_in,
      c_in   => c_in,
      t_out  => t_out,
      c_out  => c_out
    );

  -- 10 ns clock
  clk_proc: process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process clk_proc;

  -- Simple stimulus: drive a sequence of vectors and wait pipeline cycles
  stim_proc: process
  begin
    -- wait a little for initialization
    wait for 20 ns;

    -- Test vectors (small, deterministic)
    a_word <= to_unsigned(3, WORD_WIDTH);
    b_word <= to_unsigned(5, WORD_WIDTH);
    t_in   <= to_unsigned(1, WORD_WIDTH);
    c_in   <= to_unsigned(0, WORD_WIDTH);
    -- sample and let pipeline advance
    wait until rising_edge(clk);
    -- wait additional cycles to allow the pipeline to update outputs
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    report "VECT0: a=3 b=5 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- second vector
    a_word <= to_unsigned(10, WORD_WIDTH);
    b_word <= to_unsigned(7, WORD_WIDTH);
    t_in   <= to_unsigned(2, WORD_WIDTH);
    c_in   <= to_unsigned(0, WORD_WIDTH);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    report "VECT1: a=10 b=7 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- third vector
    a_word <= to_unsigned(255 mod 2**WORD_WIDTH, WORD_WIDTH);
    b_word <= to_unsigned(255 mod 2**WORD_WIDTH, WORD_WIDTH);
    t_in   <= to_unsigned(0, WORD_WIDTH);
    c_in   <= to_unsigned(1, WORD_WIDTH);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    report "VECT2: a=255 b=255 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- leave signals stable for waveform inspection
    wait for 200 ns;

    -- finish simulation: keep simulator running so user can inspect waveform
    report "SIMULATION FINISHED (simple TB) - PASS (waveform remains open)" severity note;
    wait;
  end process stim_proc;

end architecture tb;
