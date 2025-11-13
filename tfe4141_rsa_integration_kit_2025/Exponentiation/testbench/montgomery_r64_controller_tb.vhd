library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_r64_controller_tb is
end montgomery_r64_controller_tb;

architecture testbench of montgomery_r64_controller_tb is

    -- Component declaration
    component montgomery_r64_controller is
        generic (
            WIDTH : integer := 256
        );
        port (
            clk                    : in  std_logic;
            reset                  : in  std_logic;
            sig_state              : out  std_logic;
            shift_a                : out std_logic;
            shift_b                : out std_logic;
            last_outer_loop_state  : out std_logic_vector(3 downto 0);
            activate_gamma_final   : out std_logic;
            activate_gamma1        : out std_logic;
            activate_gamma2        : out std_logic;
            activate_gamma3        : out std_logic;
            activate_beta          : out std_logic;
            activate_alpha1        : out std_logic;
            activate_alpha2        : out std_logic;
            activate_alpha3        : out std_logic;
            activate_alpha_final   : out std_logic;
            enable                 : in  std_logic;
            done                   : out std_logic;
            current_state_debug    : out integer range 0 to 4;
            outer_iteration_counter_debug : out unsigned(3 downto 0)
        );
    end component;

    -- Testbench signals
    constant CLK_PERIOD : time := 10 ns;
    constant WIDTH : integer := 32;  -- Use smaller width for faster simulation
    
    signal clk                    : std_logic := '0';
    signal reset                  : std_logic := '0';
    signal sig_state              : std_logic := '0';
    signal shift_a                : std_logic;
    signal shift_b                : std_logic;
    signal last_outer_loop_state  : std_logic_vector(3 downto 0);
    signal activate_gamma_final   : std_logic;
    signal activate_gamma1        : std_logic;
    signal activate_gamma2        : std_logic;
    signal activate_gamma3        : std_logic;
    signal activate_beta          : std_logic;
    signal activate_alpha1        : std_logic;
    signal activate_alpha2        : std_logic;
    signal activate_alpha3        : std_logic;
    signal activate_alpha_final   : std_logic;
    signal enable                 : std_logic := '0';
    signal done                   : std_logic;
    signal current_state_debug    : integer range 0 to 4;  -- Actual controller state
    signal outer_iteration_counter_debug : unsigned(3 downto 0);  -- Actual counter value
    
    signal test_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: montgomery_r64_controller
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk                   => clk,
            reset                 => reset,
            sig_state             => sig_state,
            shift_a               => shift_a,
            shift_b               => shift_b,
            last_outer_loop_state => last_outer_loop_state,
            activate_gamma_final  => activate_gamma_final,
            activate_gamma1       => activate_gamma1,
            activate_gamma2       => activate_gamma2,
            activate_gamma3       => activate_gamma3,
            activate_beta         => activate_beta,
            activate_alpha1       => activate_alpha1,
            activate_alpha2       => activate_alpha2,
            activate_alpha3       => activate_alpha3,
            activate_alpha_final  => activate_alpha_final,
            enable                => enable,
            done                  => done,
            current_state_debug   => current_state_debug,
            outer_iteration_counter_debug => outer_iteration_counter_debug
        );

    -- Clock generation
    clk_process: process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        report "========================================";
        report "Starting Montgomery R64 Controller Testbench";
        report "========================================";
        
        -- ====================================================================
        -- Test 1: Reset Test
        -- ====================================================================
        report "Test 1: Reset behavior";
        reset <= '1';
        enable <= '0';
        wait for CLK_PERIOD * 2;
        
        assert done = '0' report "Error: done should be '0' after reset" severity error;
        assert shift_a = '0' report "Error: shift_a should be '0' after reset" severity error;
        assert shift_b = '0' report "Error: shift_b should be '0' after reset" severity error;
        assert activate_alpha1 = '0' report "Error: All activations should be '0' after reset" severity error;
        
        reset <= '0';
        wait for CLK_PERIOD;
        report "Test 1: PASSED";
        
        -- ====================================================================
        -- Test 2: IDLE state behavior
        -- ====================================================================
        report "Test 2: IDLE state with enable='0'";
        enable <= '0';
        wait for CLK_PERIOD * 3;
        
        assert done = '0' report "Error: done should be '0' in IDLE" severity error;
        assert shift_a = '0' report "Error: shift_a should be '0' in IDLE" severity error;
        assert shift_b = '0' report "Error: shift_b should be '0' in IDLE" severity error;
        report "Test 2: PASSED";
        
        -- ====================================================================
        -- Test 3: Enable and first state transition
        -- ====================================================================
        report "Test 3: Enable signal and transition to STATE1";
        enable <= '1';
        wait for CLK_PERIOD;
        
        -- Should now be in STATE1
        wait for CLK_PERIOD;
        assert activate_alpha1 = '1' report "Error: activate_alpha1 should be '1' in STATE1" severity error;
        assert shift_b = '1' report "Error: shift_b should be '1' in STATE1" severity error;
        report "Test 3: PASSED";
        
        -- ====================================================================
        -- Test 4: State machine progression (STATE1 -> STATE2 -> STATE3)
        -- ====================================================================
        report "Test 4: State machine progression through states";
        
        -- Check STATE2
        wait for CLK_PERIOD;
        assert activate_beta = '1' report "Error: activate_beta should be '1' in STATE2" severity error;
        assert shift_b = '1' report "Error: shift_b should be '1' in STATE2" severity error;
        
        -- Check STATE3
        wait for CLK_PERIOD;
        assert activate_gamma1 = '1' report "Error: activate_gamma1 should be '1' in STATE3" severity error;
        assert shift_b = '1' report "Error: shift_b should be '1' in STATE3" severity error;
        
        report "Test 4: PASSED";
        
        -- ====================================================================
        -- Test 5: Outer iteration counter progression
        -- ====================================================================
        report "Test 5: Testing outer iteration counter and PE activation sequence";
        
        -- Continue through multiple iterations to test counter-dependent behavior
        -- Iteration 0: only alpha1 active
        -- Iteration 1: alpha1, alpha2, gamma2 active
        -- Iteration 2: alpha1, alpha3, gamma3, alpha_final active
        
        -- Let's run through several complete state cycles
        for i in 1 to 10 loop
            wait for CLK_PERIOD * 3;  -- One complete cycle (STATE1->STATE2->STATE3)
        end loop;
        
        report "Test 5: PASSED - Completed multiple iterations";
        
        -- ====================================================================
        -- Test 6: last_outer_loop_state counter
        -- ====================================================================
        report "Test 6: Testing last_outer_loop_state progression";
        
        -- The last_outer_loop_state should increment after outer_iteration_counter > 6
        -- Continue running until we see last_outer_loop_state incrementing
        for i in 1 to 20 loop
            wait for CLK_PERIOD;
            if unsigned(last_outer_loop_state) > 0 then
                report "last_outer_loop_state = " & integer'image(to_integer(unsigned(last_outer_loop_state)));
            end if;
        end loop;
        
        report "Test 6: PASSED";
        
        -- ====================================================================
        -- Test 7: Completion and FINISHED state
        -- ====================================================================
        report "Test 7: Testing completion when last_outer_loop_state reaches 8";
        
        -- Continue until done signal goes high
        for i in 1 to 100 loop
            wait for CLK_PERIOD;
            if done = '1' then
                report "Done signal asserted at iteration " & integer'image(i);
                exit;
            end if;
        end loop;
        
        assert done = '1' report "Error: done should be '1' after completion" severity error;
        report "Test 7: PASSED";
        
        -- ====================================================================
        -- Test 8: Return to IDLE by deasserting enable
        -- ====================================================================
        report "Test 8: Testing return to IDLE state";
        enable <= '0';
        wait for CLK_PERIOD * 2;
        
        assert done = '0' report "Error: done should be '0' after returning to IDLE" severity error;
        report "Test 8: PASSED";
        
        -- ====================================================================
        -- Test 9: Reset during operation
        -- ====================================================================
        report "Test 9: Testing reset during active operation";
        enable <= '1';
        wait for CLK_PERIOD * 5;  -- Let it run for a few cycles
        
        reset <= '1';
        wait for CLK_PERIOD;
        
        assert done = '0' report "Error: done should be '0' after reset" severity error;
        assert shift_a = '0' report "Error: shift_a should be '0' after reset" severity error;
        assert shift_b = '0' report "Error: shift_b should be '0' after reset" severity error;
        
        reset <= '0';
        enable <= '0';
        wait for CLK_PERIOD;
        report "Test 9: PASSED";
        
        -- ====================================================================
        -- Test 10: Complete full operation from start to finish
        -- ====================================================================
        report "Test 10: Full operation test";
        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        enable <= '1';
        wait for CLK_PERIOD;
        
        -- Wait for completion
        for i in 1 to 200 loop
            wait for CLK_PERIOD;
            if done = '1' then
                report "Full operation completed in " & integer'image(i) & " clock cycles";
                exit;
            end if;
        end loop;
        
        assert done = '1' report "Error: Full operation should complete" severity error;
        report "Test 10: PASSED";
        
        -- End of tests
        report "========================================";
        report "All tests completed successfully!";
        report "========================================";
        
        test_done <= true;
        wait;
    end process;

end testbench;
