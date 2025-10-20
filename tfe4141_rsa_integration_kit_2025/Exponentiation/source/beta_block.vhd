library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity beta is
  generic (
    WORD_WIDTH : integer := 32
  );
  port (
    clk       : in  std_logic;
    p_marked  : in  unsigned(WORD_WIDTH-1 downto 0);
    p_zero    : in  unsigned(WORD_WIDTH-1 downto 0);
    s_in      : in  unsigned(WORD_WIDTH-1 downto 0);
    m_out     : out unsigned(WORD_WIDTH-1 downto 0);
    c_out     : out unsigned(WORD_WIDTH-1 downto 0)
  );
end entity beta;

-- combinational version (no registers)
architecture comb of beta is

begin
  comb_proc: process(p_marked, p_zero, s_in)
    variable temp1      : unsigned((2*WORD_WIDTH)-1 downto 0);
    variable temp2      : unsigned((2*WORD_WIDTH)-1 downto 0);
    variable temp3      : unsigned((2*WORD_WIDTH)-1 downto 0);
    variable m_temp     : unsigned(WORD_WIDTH-1 downto 0);
    variable prod2_low  : unsigned(WORD_WIDTH-1 downto 0);
    variable prod2_high : unsigned(WORD_WIDTH-1 downto 0);
  begin
    -- temp1 = s_in * p_marked (full 2*WORD_WIDTH product)
    temp1 := s_in * p_marked;

    -- m_temp := low WORD_WIDTH bits of temp1
    m_temp := temp1(WORD_WIDTH-1 downto 0);

    -- temp2 = m_temp * p_zero (full product)
    temp2 := m_temp * p_zero;
    prod2_low := temp2(WORD_WIDTH-1 downto 0);
    prod2_high := temp2((2*WORD_WIDTH)-1 downto WORD_WIDTH);

    -- temp3 = s_in + temp2 (s_in resized to full width)
    temp3 := resize(s_in, temp3'length) + temp2;

    -- outputs: m_out is the low word from temp1; c_out is high WORD_WIDTH bits of temp3
    m_out <= m_temp;
    c_out <= temp3((2*WORD_WIDTH)-1 downto WORD_WIDTH);
  end process;
end architecture comb;
