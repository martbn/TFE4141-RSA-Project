library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Beta process element (combinational)
-- Implements one word of: T := T + u * N; then output low word and carry
-- For a systolic CIOS Montgomery array, multiple PEs compute in parallel.

entity gamma is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    -- inputs
    m       : in  unsigned(WORD_WIDTH-1 downto 0); -- scalar multiplier (from earlier stage)
    p_i  : in  unsigned(WORD_WIDTH-1 downto 0); -- one word of modulus N
    t_in    : in  unsigned(WORD_WIDTH-1 downto 0); -- current T word
    c_in    : in  unsigned(WORD_WIDTH downto 0);   -- incoming carry (width WORD_WIDTH+1)
    -- outputs (combinational)
    t_out   : out unsigned(WORD_WIDTH-1 downto 0); -- updated T word (low)
    c_out   : out unsigned(WORD_WIDTH downto 0)    -- updated carry (may be wider)
  );
end entity gamma;

architecture comb of gamma is
  -- product width = 2*WORD_WIDTH
  constant PROD_W : integer := 2 * WORD_WIDTH;
begin
  process(m, p_i, t_in, c_in)
    variable prod   : unsigned(PROD_W-1 downto 0);
    variable prod_low : unsigned(WORD_WIDTH-1 downto 0);
    variable prod_high: unsigned(WORD_WIDTH-1 downto 0);
    variable sum_v  : unsigned(WORD_WIDTH downto 0); -- temporary for overflow detection
    variable carry_v: unsigned(WORD_WIDTH downto 0);
    variable sum_full : unsigned(PROD_W downto 0);
  begin
    -- full product
    prod := m * p_i;
    prod_low := prod(WORD_WIDTH-1 downto 0);
    prod_high := prod(PROD_W-1 downto WORD_WIDTH);

    -- sum the low part with t_in and incoming carry (we need space for overflow)
    sum_full := resize(prod_low, sum_full'length)
                + resize(t_in, sum_full'length)
                + resize(c_in, sum_full'length);

    -- low output word
    t_out <= sum_full(WORD_WIDTH-1 downto 0);

    -- carry out is product high plus overflow from low-part addition
    carry_v := resize(prod_high, carry_v'length) + resize(sum_full(sum_full'high downto WORD_WIDTH), carry_v'length);
    c_out <= carry_v;
  end process;
end architecture comb;
