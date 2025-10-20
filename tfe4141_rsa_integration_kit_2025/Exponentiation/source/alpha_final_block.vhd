library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha_final is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    
    t_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s1_out  : out unsigned(WORD_WIDTH-1 downto 0);
    s2_out   : out unsigned(WORD_WIDTH-1 downto 0)
    
  );
end entity alpha_final;

-- combinational version (no registers)
architecture comb of alpha_final is
    begin
        comb_proc: process(t_in, c_in)
        variable sum_v      : unsigned((2*WORD_WIDTH)-1 downto 0);
        variable sum_low   : unsigned(WORD_WIDTH-1 downto 0);
        variable sum_high  : unsigned(WORD_WIDTH-1 downto 0);
    begin
        -- compute partial products
        sum_v := resize(t_in, sum_v'length) + resize(c_in, sum_v'length);
        sum_low := sum_v(WORD_WIDTH-1 downto 0);
        sum_high := sum_v(2*WORD_WIDTH-1 downto WORD_WIDTH);
        -- output results
        s1_out <= sum_low;
        s2_out <= sum_high;
    end process;
end architecture comb;
