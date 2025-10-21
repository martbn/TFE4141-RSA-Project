library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma3_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    m     : in  unsigned(WORD_WIDTH-1 downto 0);
    p_i      : in  unsigned(WORD_WIDTH-1 downto 0);
    s_a2_out    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_a3_out    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_g2_out        : in  unsigned(WORD_WIDTH-1 downto 0);
    s_g3_out       : out unsigned(WORD_WIDTH-1 downto 0);
    c_g3_out       : out unsigned(WORD_WIDTH-1 downto 0);
    sig_state   : in  std_logic
  );
end entity gamma3_pe;

architecture behavior of gamma3_pe is
  -- Internal signals for mux outputs
  signal t_in : unsigned(WORD_WIDTH-1 downto 0);
  signal c_in : unsigned(WORD_WIDTH-1 downto 0);
  signal c_internal : unsigned(WORD_WIDTH-1 downto 0);
  signal c_prev : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');  -- Registered previous carry
  signal t_out : unsigned(WORD_WIDTH-1 downto 0); 
  begin
  -- Register the carry output on clock edge to get previous value
  reg_process: process(clk, reset)
  begin
    if reset = '1' then
      c_prev <= (others => '0');
    elsif rising_edge(clk) then
      c_prev <= c_internal;
    end if;
  end process;

  -- Combinational process to select inputs based on sig_state
  mux_process: process(sig_state, s_a2_out, s_a3_out, c_g2_out, c_prev)
  begin
    if sig_state = '0' then
      t_in <= s_a2_out;
      c_in <= c_g2_out;
    else
      t_in <= s_a3_out;
      c_in <= c_prev;  -- Use registered previous value
    end if;
  end process;

  -- Instantiate alpha_block
  gamma3_pe_inst : entity work.gamma
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
     -- clk     => clk,
      m       => m,
      p_i     => p_i,
      t_in    => t_in,
      c_in    => c_in,
      t_out   => t_out,
      c_out   => c_internal
    );

  -- Connect internal signals to output ports
  s_g3_out <= t_out;
  c_g3_out <= c_internal;

end architecture behavior;