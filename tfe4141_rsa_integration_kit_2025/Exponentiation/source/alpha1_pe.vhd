library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha1_pe is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic := '0';
    a_word      : in  unsigned(WORD_WIDTH-1 downto 0);
    b_word      : in  unsigned(WORD_WIDTH-1 downto 0);
    s_g1_out    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_g2_out    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_a1_out       : out unsigned(WORD_WIDTH-1 downto 0);
    c_a1_out       : out unsigned(WORD_WIDTH-1 downto 0);
    sig_state   : in  std_logic
  );
end entity alpha1_pe;

architecture behavior of alpha1_pe is
  -- Internal signals for mux outputs
  signal t_in : unsigned(WORD_WIDTH-1 downto 0);
  signal c_in : unsigned(WORD_WIDTH-1 downto 0);
  signal c_internal : unsigned(WORD_WIDTH-1 downto 0);
  signal c_prev : unsigned(WORD_WIDTH-1 downto 0) := (others => '0');  -- Registered previous carry
  signal t_out : unsigned(WORD_WIDTH-1 downto 0);
  signal zero : unsigned(WORD_WIDTH-1 downto 0) := (others => '0'); 
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
  mux_process: process(sig_state, s_g1_out, s_g2_out, zero, c_prev)
  begin
    if sig_state = '0' then
      t_in <= s_g1_out;
      c_in <= zero;
    else
      t_in <= s_g2_out;
      c_in <= c_prev;  -- Use registered previous value
    end if;
  end process;

  -- Instantiate alpha_block
  alpha1_pe_inst : entity work.alpha
    generic map (
      WORD_WIDTH => WORD_WIDTH
    )
    port map (
      clk     => clk,
      a_word  => a_word,
      b_word  => b_word,
      t_in    => t_in,
      c_in    => c_in,
      t_out   => t_out,
      c_out   => c_internal
    );

  -- Connect internal signals to output ports
  s_a1_out <= t_out;
  c_a1_out <= c_internal;

end architecture behavior;

