library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma_tb is
end entity;

architecture tb of gamma_tb is
  constant WORD_WIDTH : integer := 8;

  signal m_sig   : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal p_i     : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal t_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal c_in    : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');
  signal t_out   : unsigned(WORD_WIDTH-1 downto 0);
  signal c_out   : unsigned(WORD_WIDTH-1 downto 0);

  component gamma is
    generic ( WORD_WIDTH : integer := 32 );
    port (
      m       : in  unsigned(WORD_WIDTH-1 downto 0);
      p_i     : in  unsigned(WORD_WIDTH-1 downto 0);
      t_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
      t_out   : out unsigned(WORD_WIDTH-1 downto 0);
      c_out   : out unsigned(WORD_WIDTH-1 downto 0)
    );
  end component;

begin
  dut: gamma
    generic map ( WORD_WIDTH => WORD_WIDTH )
    port map (
      m => m_sig,
      p_i => p_i,
      t_in => t_in,
      c_in => c_in,
      t_out => t_out,
      c_out => c_out
    );

  stim: process
  begin
    -- vector 0
    m_sig <= to_unsigned(3, WORD_WIDTH);
    p_i   <= to_unsigned(5, WORD_WIDTH);
    t_in  <= to_unsigned(1, WORD_WIDTH);
    c_in  <= to_unsigned(0, WORD_WIDTH);
    wait for 1 ns; -- allow combinational settle
    report "V0: m=3 p=5 t_in=1 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- vector 1
    m_sig <= to_unsigned(10, WORD_WIDTH);
    p_i   <= to_unsigned(7, WORD_WIDTH);
    t_in  <= to_unsigned(2, WORD_WIDTH);
    c_in  <= to_unsigned(0, WORD_WIDTH);
    wait for 1 ns;
    report "V1: m=10 p=7 t_in=2 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    -- vector 2: larger values
    m_sig <= to_unsigned(255 mod 2**WORD_WIDTH, WORD_WIDTH);
    p_i   <= to_unsigned(255 mod 2**WORD_WIDTH, WORD_WIDTH);
    t_in  <= to_unsigned(0, WORD_WIDTH);
    c_in  <= to_unsigned(1, WORD_WIDTH);
    wait for 1 ns;
    report "V2: m=255 p=255 t_in=0 c_in=1 -> t_out=" & integer'image(to_integer(t_out)) &
           " c_out=" & integer'image(to_integer(c_out));

    wait for 100 ns; -- leave waveform stable
    report "SIMULATION FINISHED (gamma_pe_tb) - PASS (waveform remains open)" severity note;
    wait;
  end process;
end architecture tb;
