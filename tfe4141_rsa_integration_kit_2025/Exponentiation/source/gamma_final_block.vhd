library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gamma_final is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    
    s1_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s2_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    c_in    : in  unsigned(WORD_WIDTH-1 downto 0);
    s1_out  : out unsigned(WORD_WIDTH-1 downto 0);
    s2_out  : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity gamma_final;

-- combinational version (no registers)
architecture comb of gamma_final is
    begin
        comb_proc: process(s1_in, s2_in, c_in)
        variable sum_v      : unsigned((2*WORD_WIDTH)-1 downto 0);
        variable sum2     : unsigned((2*WORD_WIDTH)-1 downto 0);
        variable sum_low   : unsigned(WORD_WIDTH-1 downto 0);
        variable sum2_high  : unsigned(WORD_WIDTH-1 downto 0);
        
    begin
        -- compute partial products
        sum_v := resize(s1_in, sum_v'length) + resize(c_in, sum_v'length);
        sum_low := sum_v(WORD_WIDTH-1 downto 0);
        sum2 := resize(s2_in, sum2'length) + resize(sum_low, sum2'length);
        sum2_high := sum2(2*WORD_WIDTH-1 downto WORD_WIDTH);
        -- output results
        s1_out <= sum_low;
        s2_out <= sum2_high;
    end process;
end architecture comb;