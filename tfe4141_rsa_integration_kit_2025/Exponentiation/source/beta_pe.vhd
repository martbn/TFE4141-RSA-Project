library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity beta_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    
    p_marked  : in  unsigned(WORD_WIDTH-1 downto 0);
    p_zero    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_b_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    
    m    : out unsigned(WORD_WIDTH-1 downto 0);
    c_b_out    : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity beta_pe;

architecture behavior of beta_pe is
  -- Internal signals
  signal m_out : unsigned(WORD_WIDTH-1 downto 0); 
  signal c_out : unsigned(WORD_WIDTH-1 downto 0);
begin

  -- Instantiate beta block
  beta_pe_inst : entity work.beta
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk       => clk,
      s_in      => s_b_in,
      p_zero    => p_zero,
      p_marked  => p_marked,
      m_out     => m_out,
      c_out     => c_out
    );

  -- Connect internal signals to output ports
  m <= m_out;
  c_b_out <= c_out;

end architecture behavior;