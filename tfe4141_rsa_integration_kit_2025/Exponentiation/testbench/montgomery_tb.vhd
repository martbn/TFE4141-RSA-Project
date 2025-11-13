library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_tb is
end montgomery_tb;

architecture sim of montgomery_tb is
    constant WIDTH : integer := 8; -- small width for quick simulation

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal done   : std_logic;

    signal A : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal B : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal N : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal S : std_logic_vector(WIDTH-1 downto 0);
    signal debug_res_reg : std_logic_vector(WIDTH-1 downto 0);
    signal debug_S_reg   : std_logic_vector(WIDTH downto 0);

begin
    -- Instantiate top-level montgomery unit (uses controller + datapath inside)
    uut: entity work.montgomery
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk    => clk,
            reset  => reset,
            enable => enable,
            done   => done,
            A      => A,
            B      => B,
            N      => N,
            S      => S,
            debug_res_reg => debug_res_reg,
            debug_S_reg   => debug_S_reg
        );

    -- Clock generation (100 MHz -> 10 ns period)
    clk_proc : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process clk_proc;

    -- Stimulus
    stim_proc : process
    begin
        -- initial reset
        reset <= '1';
        enable <= '0';
        wait for 30 ns;
        reset <= '0';
        wait for 20 ns;

        -- TEST 1: A=3, B=5, N=7
        report "--- Starting Test 1 ---";
        A <= std_logic_vector(to_unsigned(81, WIDTH));
        B <= std_logic_vector(to_unsigned(14, WIDTH));
        N <= std_logic_vector(to_unsigned(23, WIDTH));
        wait for 10 ns;

        -- pulse enable to start
        enable <= '1';
        wait for 10 ns;
        enable <= '0';

        -- wait until controller signals done
        wait until done = '1';
        wait for 10 ns; -- let outputs settle
        report "Test1 done. debug_res_reg = " & integer'image(to_integer(unsigned(debug_res_reg)));
        report "Test1 done. debug_S_reg   = " & integer'image(to_integer(unsigned(debug_S_reg)));

        -- small gap before next test
        wait for 40 ns;

        -- TEST 2: A=1, B=2, N=3
        report "--- Starting Test 2 ---";
        A <= std_logic_vector(to_unsigned(1, WIDTH));
        B <= std_logic_vector(to_unsigned(2, WIDTH));
        N <= std_logic_vector(to_unsigned(3, WIDTH));
        wait for 10 ns;
        enable <= '1'; wait for 10 ns; enable <= '0';
        wait until done = '1';
        wait for 10 ns;
        report "Test2 done. debug_res_reg = " & integer'image(to_integer(unsigned(debug_res_reg)));
        report "Test2 done. debug_S_reg   = " & integer'image(to_integer(unsigned(debug_S_reg)));

        -- small gap before next test
        wait for 40 ns;

        -- TEST 3: A=0, B=7, N=5
        report "--- Starting Test 3 ---";
        A <= std_logic_vector(to_unsigned(0, WIDTH));
        B <= std_logic_vector(to_unsigned(7, WIDTH));
        N <= std_logic_vector(to_unsigned(5, WIDTH));
        wait for 10 ns;
        enable <= '1'; wait for 10 ns; enable <= '0';
        wait until done = '1';
        wait for 10 ns;
        report "Test3 done. debug_res_reg = " & integer'image(to_integer(unsigned(debug_res_reg)));
        report "Test3 done. debug_S_reg   = " & integer'image(to_integer(unsigned(debug_S_reg)));

        -- Print final result to console (for simulator output)
        report "All tests finished. Final S = " & integer'image(to_integer(unsigned(S)));

        wait;
    end process stim_proc;

    -- Monitor: print S and debug regs each clock so we can see where X appears
    monitor_proc : process
    begin
        wait until rising_edge(clk);
     report "time=" & time'image(now) & " S=" & integer'image(to_integer(unsigned(S))) &
         " debug_res_reg=" & integer'image(to_integer(unsigned(debug_res_reg))) &
         " debug_S_reg=" & integer'image(to_integer(unsigned(debug_S_reg))) &
         " done=" & std_logic'image(done);
        wait;
    end process monitor_proc;

end sim;
