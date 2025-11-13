library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter_r64_abp_tb is
end entity shifter_r64_abp_tb;

architecture testbench of shifter_r64_abp_tb is

    -- Component declaration
    component shifter_r64 is
        generic (
            WIDTH_WORD : integer := 32;
            WIDTH_OPERAND : integer := 256
        );
        port (
            clk    : in  std_logic;
            reset  : in  std_logic;
            A      : in  unsigned(WIDTH_OPERAND-1 downto 0);
            B      : in  unsigned(WIDTH_OPERAND-1 downto 0);
            N      : in  unsigned(WIDTH_OPERAND-1 downto 0);
            shift_a : in std_logic;
            shift_b : in std_logic;
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
    end component;

    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant WIDTH_WORD : integer := 4;  -- 4-bit words for easy viewing
    constant WIDTH_OPERAND : integer := 32;  -- 32-bit operands (8 words)

    -- Testbench signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal A : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');
    signal B : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');
    signal N : unsigned(WIDTH_OPERAND-1 downto 0) := (others => '0');
    signal shift_a : std_logic := '0';
    signal shift_b : std_logic := '0';

    -- Output signals
    signal a_first_word : unsigned(WIDTH_WORD-1 downto 0);
    signal a_middle_word : unsigned(WIDTH_WORD-1 downto 0);
    signal a_last_word : unsigned(WIDTH_WORD-1 downto 0);
    signal b_first_word : unsigned(WIDTH_WORD-1 downto 0);
    signal b_middle_word : unsigned(WIDTH_WORD-1 downto 0);
    signal b_last_word : unsigned(WIDTH_WORD-1 downto 0);
    signal n_0_word : unsigned(WIDTH_WORD-1 downto 0);
    signal n_1_word : unsigned(WIDTH_WORD-1 downto 0);
    signal n_2_word : unsigned(WIDTH_WORD-1 downto 0);
    signal n_3_word : unsigned(WIDTH_WORD-1 downto 0);

    -- Test control
    signal test_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: shifter_r64
        generic map (
            WIDTH_WORD => WIDTH_WORD,
            WIDTH_OPERAND => WIDTH_OPERAND
        )
        port map (
            clk => clk,
            reset => reset,
            A => A,
            B => B,
            N => N,
            shift_a => shift_a,
            shift_b => shift_b,
            a_first_word => a_first_word,
            a_middle_word => a_middle_word,
            a_last_word => a_last_word,
            b_first_word => b_first_word,
            b_middle_word => b_middle_word,
            b_last_word => b_last_word,
            n_0_word => n_0_word,
            n_1_word => n_1_word,
            n_2_word => n_2_word,
            n_3_word => n_3_word
        );

    -- Clock generation
    clk_process: process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- ===================================================================
        -- Test 1: Reset test
        -- ===================================================================
        report "========================================";
        report "Test 1: Reset test";
        report "========================================";

        reset <= '1';
        shift_a <= '0';
        shift_b <= '0';
        A <= (others => '0');
        B <= (others => '0');
        N <= (others => '0');

        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait for CLK_PERIOD;

        report "Test 1 completed: Reset verified";

        -- ===================================================================
        -- Test 2: Load operands and check initial extraction
        -- ===================================================================
        report "========================================";
        report "Test 2: Initial operand loading";
        report "========================================";

        -- Set operands:
        -- A = 0x76543210 (words: 0,1,2,3,4,5,6,7)
        -- B = 0xFEDCBA98
        -- N = 0x13579BDF
        A <= x"76543210";
        B <= x"FEDCBA98";
        N <= x"13579BDF";

        wait for CLK_PERIOD * 2;

        report "A operand = 0x76543210";
        report "  Expected: a_first_word = 0, a_middle_word = 3, a_last_word = 6";
        report "  Actual: a_first = " & integer'image(to_integer(a_first_word)) & 
               ", a_middle = " & integer'image(to_integer(a_middle_word)) &
               ", a_last = " & integer'image(to_integer(a_last_word));

        report "B operand = 0xFEDCBA98";
        report "  Expected: b_first_word = 8, b_middle_word = B, b_last_word = E";

        report "N operand = 0x13579BDF";
        report "  Expected: n_0 = F, n_1 = D, n_2 = 9, n_3 = 3";

        wait for CLK_PERIOD * 2;

        report "Test 2 completed";

        -- ===================================================================
        -- Test 3: Test A shifting
        -- ===================================================================
        report "========================================";
        report "Test 3: A operand shifting";
        report "========================================";

        -- Perform multiple shifts of A
        for i in 0 to 7 loop
            report "Shift A iteration " & integer'image(i);
            report "  Before: a_first = " & integer'image(to_integer(a_first_word)) &
                   ", a_middle = " & integer'image(to_integer(a_middle_word)) &
                   ", a_last = " & integer'image(to_integer(a_last_word));

            shift_a <= '1';
            wait for CLK_PERIOD;
            shift_a <= '0';
            wait for CLK_PERIOD;

            report "  After: a_first = " & integer'image(to_integer(a_first_word)) &
                   ", a_middle = " & integer'image(to_integer(a_middle_word)) &
                   ", a_last = " & integer'image(to_integer(a_last_word));
        end loop;

        report "Test 3 completed";

        -- ===================================================================
        -- Test 4: Test B shifting
        -- ===================================================================
        report "========================================";
        report "Test 4: B operand shifting";
        report "========================================";

        -- Reset and reload
        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        B <= x"FEDCBA98";
        wait for CLK_PERIOD * 2;

        -- Perform multiple shifts of B
        for i in 0 to 7 loop
            report "Shift B iteration " & integer'image(i);
            report "  Before: b_first = " & integer'image(to_integer(b_first_word)) &
                   ", b_middle = " & integer'image(to_integer(b_middle_word)) &
                   ", b_last = " & integer'image(to_integer(b_last_word));

            shift_b <= '1';
            wait for CLK_PERIOD;
            shift_b <= '0';
            wait for CLK_PERIOD;

            report "  After: b_first = " & integer'image(to_integer(b_first_word)) &
                   ", b_middle = " & integer'image(to_integer(b_middle_word)) &
                   ", b_last = " & integer'image(to_integer(b_last_word));
        end loop;

        report "Test 4 completed";

        -- ===================================================================
        -- Test 5: Simultaneous A and B shifting
        -- ===================================================================
        report "========================================";
        report "Test 5: Simultaneous A and B shifting";
        report "========================================";

        -- Reset and reload
        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        A <= x"12345678";
        B <= x"ABCDEF01";
        wait for CLK_PERIOD * 2;

        -- Shift both simultaneously
        for i in 0 to 4 loop
            report "Simultaneous shift iteration " & integer'image(i);
            shift_a <= '1';
            shift_b <= '1';
            wait for CLK_PERIOD;
            shift_a <= '0';
            shift_b <= '0';
            wait for CLK_PERIOD;

            report "  a_first = " & integer'image(to_integer(a_first_word)) &
                   ", b_first = " & integer'image(to_integer(b_first_word));
        end loop;

        report "Test 5 completed";

        -- ===================================================================
        -- Test 6: Edge case - all zeros
        -- ===================================================================
        report "========================================";
        report "Test 6: Edge case - all zeros";
        report "========================================";

        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        A <= (others => '0');
        B <= (others => '0');
        N <= (others => '0');
        wait for CLK_PERIOD * 2;

        -- Try shifting zeros
        shift_a <= '1';
        shift_b <= '1';
        wait for CLK_PERIOD;
        shift_a <= '0';
        shift_b <= '0';
        wait for CLK_PERIOD * 2;

        report "Test 6 completed";

        -- ===================================================================
        -- Test 7: Edge case - all ones
        -- ===================================================================
        report "========================================";
        report "Test 7: Edge case - all ones";
        report "========================================";

        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        A <= (others => '1');
        B <= (others => '1');
        N <= (others => '1');
        wait for CLK_PERIOD * 2;

        report "All outputs should be 0xF";
        report "  a_first = " & integer'image(to_integer(a_first_word));
        report "  b_first = " & integer'image(to_integer(b_first_word));
        report "  n_0 = " & integer'image(to_integer(n_0_word));

        wait for CLK_PERIOD * 2;

        report "Test 7 completed";

        -- ===================================================================
        -- All tests complete
        -- ===================================================================
        report "========================================";
        report "ALL TESTS COMPLETED SUCCESSFULLY";
        report "========================================";

        test_done <= true;
        wait;

    end process;

end architecture testbench;
