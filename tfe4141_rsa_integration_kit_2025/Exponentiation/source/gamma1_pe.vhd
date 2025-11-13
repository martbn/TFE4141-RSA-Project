library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma1_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    activate_module : in std_logic;
    m     : in  unsigned(WORD_WIDTH-1 downto 0);
    p_i      : in  unsigned(WORD_WIDTH-1 downto 0);
    s_g1_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_g1_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_g1_out       : out unsigned(WORD_WIDTH-1 downto 0);
    c_g1_out       : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity gamma1_pe;

architecture behavior of gamma1_pe is
  -- Internal signals
  signal t_out : unsigned(WORD_WIDTH-1 downto 0); 
  signal c_out : unsigned(WORD_WIDTH-1 downto 0);
begin

  -- Instantiate gamma block
  gamma1_pe_inst : entity work.gamma
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      m       => m,
      p_i     => p_i,
      t_in    => s_g1_in,
      c_in    => c_g1_in,
      t_out   => t_out,
      c_out   => c_out
    );

  -- Output the results directly (no activation gating)
  s_g1_out <= t_out when activate_module = '1' else (others => '0');
  c_g1_out <= c_out when activate_module = '1' else (others => '0');

end architecture behavior;