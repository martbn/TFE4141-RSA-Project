
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter_r64 is
    generic (
           WIDTH_WORD : integer := 32;  -- Operand width (e.g. 1024 bits for RSA)
           WIDTH_OPERAND : integer := 8 * WIDTH_WORD  -- Total operand width (e.g. 2048 bits for RSA)
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   -- Clock
           reset  : in  std_logic;   -- Active-high reset


           A      : in  unsigned(WIDTH_OPERAND-1 downto 0);  -- Multiplicand
           B      : in  unsigned(WIDTH_OPERAND-1 downto 0);  -- Multiplier
           N      : in  unsigned(WIDTH_OPERAND-1 downto 0);  -- Modulus (must be odd)
           
           --N_prime : in std_logic_vector((WIDTH_WORD)-1 downto 0);  -- Precomputed N' values for Montgomery reduction

           shift_a : in std_logic;   -- Shift signal for A operand
           shift_b : in std_logic;   -- Shift signal for B operand

           a_first_word : out unsigned(WIDTH_WORD-1 downto 0);
           a_middle_word : out unsigned(WIDTH_WORD-1 downto 0);
           a_last_word : out unsigned(WIDTH_WORD-1 downto 0);

           b_first_word : out unsigned(WIDTH_WORD-1 downto 0);
           b_middle_word : out unsigned(WIDTH_WORD-1 downto 0);
           b_last_word : out unsigned(WIDTH_WORD-1 downto 0);

           n_0_word : out unsigned(WIDTH_WORD-1 downto 0);
           n_1_word : out unsigned(WIDTH_WORD-1 downto 0);
           n_2_word : out unsigned(WIDTH_WORD-1 downto 0);
           n_3_word : out unsigned(WIDTH_WORD-1 downto 0)
    );

end shifter_r64;

architecture behavioral of shifter_r64 is

    signal a_operand : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');
    signal b_operand : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');
    signal n_operand : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');

    signal a_first : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal a_middle : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal a_last : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    
    -- Flags to track if operands have been loaded
    signal a_loaded : std_logic := '0';
    signal b_loaded : std_logic := '0';

    signal b_first3_loop : unsigned(3*WIDTH_WORD-1 downto 0) := (others => '0');
    signal b_middle3_loop : unsigned(3*WIDTH_WORD-1 downto 0) := (others => '0');
    signal b_last2_loop : unsigned(2*WIDTH_WORD-1 downto 0) := (others => '0');

    signal b_first : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal b_middle : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal b_last : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');

    signal n_0 : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal n_1 : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal n_2 : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal n_3 : unsigned(WIDTH_WORD-1 downto 0) := (others => '0');
    signal n_2_loop : unsigned(3*WIDTH_WORD-1 downto 0) := (others => '0');
    signal n_3_loop : unsigned(3*WIDTH_WORD-1 downto 0) := (others => '0');

begin
    -- Connect operand inputs directly (no intermediate assignment needed)
    n_0 <= N(WIDTH_WORD-1 downto 0);
    n_1 <= N(2*WIDTH_WORD-1 downto WIDTH_WORD);

  shift_a_process: process(clk, reset)
  begin
    if reset = '1' then
      a_operand <= (others => '0');
      a_first <= (others => '0');
      a_middle <= (others => '0');
      a_last <= (others => '0');
      a_loaded <= '0';
    elsif rising_edge(clk) then
      -- Load A operand only if not yet loaded
      if a_loaded = '0' then
        if A /= 0 then
          a_operand <= A;
          a_first <= A(WIDTH_WORD-1 downto 0);           -- Word 0
          a_middle <= (others => '0'); 
          a_last <= (others => '0');
          a_loaded <= '1';
        end if;
      elsif shift_a = '1' then
        -- Shift A: extract next word before shifting
        a_last <= a_middle;
        a_middle <= a_first;
        a_first <= a_operand(2*WIDTH_WORD-1 downto WIDTH_WORD); 
        a_operand <= (WIDTH_WORD-1 downto 0 => '0') & a_operand(WIDTH_OPERAND-1 downto WIDTH_WORD);
      end if;
    end if;
  end process;

  shift_b_n_process: process(clk, reset)
  begin
    if reset = '1' then
      -- Initialize to zero at reset
      b_operand <= (others => '0');
      n_operand <= (others => '0');
      b_first3_loop <= (others => '0');
      b_middle3_loop <= (others => '0');
      b_last2_loop <= (others => '0');
      b_first <= (others => '0');
      b_middle <= (others => '0');
      b_last <= (others => '0');
      n_2_loop <= (others => '0');
      n_3_loop <= (others => '0');
      n_2 <= (others => '0');
      n_3 <= (others => '0');
      b_loaded <= '0';
    elsif rising_edge(clk) then
      -- Load B and N operands only if not yet loaded
      if b_loaded = '0' then
        if B /= 0 then
          b_operand <= B;
          n_operand <= N;
          b_first3_loop <= B(3*WIDTH_WORD-1 downto 0);
          b_middle3_loop <= B(6*WIDTH_WORD-1 downto 3*WIDTH_WORD);
          b_last2_loop <= B(8*WIDTH_WORD-1 downto 6*WIDTH_WORD);
          
          -- Start with word 0 as intended (0-1-2 pattern)
          b_first <= B(WIDTH_WORD-1 downto 0);              -- word 0
          b_middle <= B(4*WIDTH_WORD-1 downto 3*WIDTH_WORD); -- word 3
          b_last <= B(7*WIDTH_WORD-1 downto 6*WIDTH_WORD);   -- word 6
          
          n_2_loop <= N(5*WIDTH_WORD-1 downto 2*WIDTH_WORD);
          n_3_loop <= N(8*WIDTH_WORD-1 downto 5*WIDTH_WORD);
          n_2 <= N(3*WIDTH_WORD-1 downto 2*WIDTH_WORD);
          n_3 <= N(6*WIDTH_WORD-1 downto 5*WIDTH_WORD);
          
          b_loaded <= '1';
        end if;
      elsif shift_b = '1' then
        -- Circular shift for B words
        b_first <= b_first3_loop(WIDTH_WORD-1 downto 0);
        b_first3_loop <= b_first3_loop(WIDTH_WORD-1 downto 0) & b_first3_loop(3*WIDTH_WORD-1 downto WIDTH_WORD);

        b_middle <= b_middle3_loop(WIDTH_WORD-1 downto 0);
        b_middle3_loop <= b_middle3_loop(WIDTH_WORD-1 downto 0) & b_middle3_loop(3*WIDTH_WORD-1 downto WIDTH_WORD);

        b_last <= b_last2_loop(WIDTH_WORD-1 downto 0);
        b_last2_loop <= b_last2_loop(WIDTH_WORD-1 downto 0) & b_last2_loop(2*WIDTH_WORD-1 downto WIDTH_WORD);
        
        -- Circular shift for N words (n_2 and n_3)
        n_2 <= n_2_loop(WIDTH_WORD-1 downto 0);
        n_2_loop <= n_2_loop(WIDTH_WORD-1 downto 0) & n_2_loop(3*WIDTH_WORD-1 downto WIDTH_WORD);

        n_3 <= n_3_loop(WIDTH_WORD-1 downto 0);
        n_3_loop <= n_3_loop(WIDTH_WORD-1 downto 0) & n_3_loop(3*WIDTH_WORD-1 downto WIDTH_WORD);
      end if;
    end if;
  end process;

    a_first_word <= a_first;
    a_middle_word <= a_middle;
    a_last_word <= a_last;

    b_first_word <= b_first;
    b_middle_word <= b_middle;
    b_last_word <= b_last;

    n_0_word <= n_0;
    n_1_word <= n_1;
    n_2_word <= n_2;
    n_3_word <= n_3;
end behavioral;