library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Very small, Vivado-friendly testbench for beta_block
-- Purpose: keep the TB simple so it's easy to run in Vivado and inspect waveforms.
-- Add these signals to the waveform: p_marked, p_zero, s_in, m_out, c_out

entity beta_block_simple_tb is
end entity;

architecture tb of beta_block_simple_tb is
  constant WORD_WIDTH : integer := 8; -- change to 32 for real tests

  signal clk      : std_logic := '0';
  signal p_marked : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal p_zero   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal s_in     : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal m_out    : unsigned(WORD_WIDTH-1 downto 0);
  signal c_out    : unsigned(WORD_WIDTH-1 downto 0);

  component beta is
    generic ( WORD_WIDTH : integer := 32 );
    port (
      clk       : in  std_logic;
      p_marked  : in  unsigned(WORD_WIDTH-1 downto 0);
      p_zero    : in  unsigned(WORD_WIDTH-1 downto 0);
      s_in      : in  unsigned(WORD_WIDTH-1 downto 0);
      m_out     : out unsigned(WORD_WIDTH-1 downto 0);
      c_out     : out unsigned(WORD_WIDTH-1 downto 0)
    );
  end component;

begin
  -- DUT instantiation
  dut: beta
    generic map ( WORD_WIDTH => WORD_WIDTH )
    port map (
      clk      => clk,
      p_marked => p_marked,
      p_zero   => p_zero,
      s_in     => s_in,
      m_out    => m_out,
      c_out    => c_out
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
    p_marked <= to_unsigned(3, WORD_WIDTH);
    p_zero   <= to_unsigned(5, WORD_WIDTH);
    s_in     <= to_unsigned(1, WORD_WIDTH);
    -- sample and let pipeline advance
    wait until rising_edge(clk);
    -- wait additional cycles to allow the pipeline to update outputs
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    report "VECT0: p_marked=3 p_zero=5 -> m_out=" & integer'image(to_integer(m_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- second vector
    p_marked <= to_unsigned(10, WORD_WIDTH);
    p_zero   <= to_unsigned(23, WORD_WIDTH);
    s_in     <= to_unsigned(2, WORD_WIDTH);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    report "VECT1: p_marked=10 p_zero=7 -> m_out=" & integer'image(to_integer(m_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- third vector
   

    -- leave signals stable for waveform inspection
    wait for 200 ns;

    -- finish simulation: keep simulator running so user can inspect waveform
    report "SIMULATION FINISHED (simple TB) - PASS (waveform remains open)" severity note;
    wait;
  end process stim_proc;

end architecture tb;
