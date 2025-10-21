library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha_final_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    
    s_af_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_af_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s1_af_out       : out unsigned(WORD_WIDTH-1 downto 0);
    s2_af_out       : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity alpha_final_pe;

architecture behavior of alpha_final_pe is
  -- Internal signals
  signal t_out : unsigned(WORD_WIDTH-1 downto 0); 
  signal c_out : unsigned(WORD_WIDTH-1 downto 0);
begin

  -- Instantiate alpha_final block
  alpha_final_pe_inst : entity work.alpha_final
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      t_in    => s_af_in,
      c_in    => c_af_in,
      t_out   => t_out,
      c_out   => c_out
    );

  -- Connect internal signals to output ports
  s1_af_out <= t_out;
  s2_af_out <= c_out;

end architecture behavior;