library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk     : in  std_logic;
    a_word  : in  unsigned(WORD_WIDTH-1 downto 0);
    b_word  : in  unsigned(WORD_WIDTH-1 downto 0);
    t_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    t_out   : out unsigned(WORD_WIDTH-1 downto 0);
    c_out   : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity alpha;

-- combinational version (no registers)
architecture comb of alpha is

begin
  comb_proc: process(a_word, b_word, t_in, c_in)
    variable mult_res_v : unsigned((2*WORD_WIDTH)-1 downto 0);
    variable sum_v      : unsigned((2*WORD_WIDTH)-1 downto 0);
    variable prod_low   : unsigned(WORD_WIDTH-1 downto 0);
    variable prod_high  : unsigned(WORD_WIDTH-1 downto 0);
    variable carry_high : unsigned(WORD_WIDTH-1 downto 0);
  begin
    mult_res_v := a_word * b_word;
    prod_low := mult_res_v(WORD_WIDTH-1 downto 0);
    prod_high := mult_res_v((2*WORD_WIDTH)-1 downto WORD_WIDTH);

    -- sum of product low, t_in and incoming carry (this can overflow into carry_high)
    sum_v := resize(prod_low, sum_v'length)
            + resize(t_in, sum_v'length)
            + resize(c_in, sum_v'length);

    -- output low word
    t_out <= sum_v(WORD_WIDTH-1 downto 0);

    -- compute carry: high half of product plus overflow from the low-word sum
    carry_high := resize(prod_high, carry_high'length) + resize(sum_v(sum_v'high downto WORD_WIDTH), carry_high'length);
    c_out <= carry_high;
  end process;
end architecture comb;
