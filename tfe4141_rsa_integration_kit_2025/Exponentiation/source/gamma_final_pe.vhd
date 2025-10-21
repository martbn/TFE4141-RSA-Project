library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma_final_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    
    s1_gf_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s2_gf_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_gf_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s1_gf_out       : out unsigned(WORD_WIDTH-1 downto 0);
    s2_gf_out       : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity gamma_final_pe;

architecture behavior of gamma_final_pe is
  -- Internal signals
  signal s1_out : unsigned(WORD_WIDTH-1 downto 0);
  signal s2_out : unsigned(WORD_WIDTH-1 downto 0);
begin

  -- Instantiate gamma_final block
  gamma_final_pe_inst : entity work.gamma_final
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      s1_in    => s1_gf_in,
      s2_in    => s2_gf_in,
      c_in     => c_gf_in,
      s1_out   => s1_out,
      s2_out   => s2_out
    );

  -- Connect internal signals to output ports
  s1_gf_out <= s1_out;
  s2_gf_out <= s2_out;

end architecture behavior;