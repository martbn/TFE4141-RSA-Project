library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_datapath_high_freq_tb is
end montgomery_datapath_high_freq_tb;

architecture tb of montgomery_datapath_high_freq_tb is
    constant WIDTH : integer := 32;

    -- DUT signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal load_registers : std_logic := '0';
    signal shift_registers : std_logic := '0';
    signal compute_AiB : std_logic := '0';
    signal compute_S   : std_logic := '0';

    signal A : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal B : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal N : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal S : std_logic_vector(WIDTH-1 downto 0);

    -- Debug outputs
    signal debug_res_reg : std_logic_vector(WIDTH-1 downto 0);
    signal debug_S_reg   : std_logic_vector(WIDTH downto 0);
    signal debug_AiB     : std_logic_vector(WIDTH downto 0);
    signal debug_a_lsb   : std_logic;
    signal debug_qi      : std_logic;
    signal debug_res_add1: std_logic_vector(WIDTH downto 0);

    constant clk_period : time := 10 ns;
    -- Number of Montgomery iterations per test (use WIDTH for full run)
    constant ITERATIONS : integer := WIDTH;

begin
    -- Instantiate DUT
    uut: entity work.montgomery_mult_datapath
        generic map (WIDTH => WIDTH)
        port map (
            clk => clk,
            reset => reset,
            load_registers => load_registers,
            shift_registers => shift_registers,
            compute_AiB => compute_AiB,
            compute_S => compute_S,
            A => A,
            B => B,
            N => N,
            S => S,
            debug_res_reg => debug_res_reg,
            debug_S_reg => debug_S_reg,
            debug_AiB => debug_AiB,
            debug_a_lsb => debug_a_lsb,
            debug_qi => debug_qi,
            debug_res_add1 => debug_res_add1
        );

    -- Clock generation
    clk_process : process
    begin
        while now < 10 ms loop
            clk <= '0';
            wait for clk_period/2;
            clk <= '1';
            wait for clk_period/2;
        end loop;
        wait;
    end process clk_process;

    -- Stimulus
    stim: process
    begin
        -- initial reset
        reset <= '1';
        load_registers <= '0';
        shift_registers <= '0';
        compute_AiB <= '0';
        compute_S <= '0';
        wait for 25 ns;
        reset <= '0';
        wait for clk_period;

    -- Run 3 sequential tests. Each test will perform ITERATIONS full Montgomery cycles

        -- Test 1
        A <= x"00000003"; -- 3
        B <= x"00000005"; -- 5
        N <= x"00000007"; -- 7
        load_registers <= '1';
        wait for clk_period;
        load_registers <= '0';

        for i in 0 to ITERATIONS-1 loop
            compute_AiB <= '1'; wait for clk_period; compute_AiB <= '0';
            compute_S <= '1'; wait for clk_period; compute_S <= '0';
            shift_registers <= '1'; wait for clk_period; shift_registers <= '0';
            wait for clk_period/2; -- small gap
        end loop;

        -- wait a couple clocks before starting next test
        wait for 4*clk_period;

        -- Test 2
        A <= x"00000001"; -- 1
        B <= x"00000002"; -- 2
        N <= x"00000003"; -- 3
        load_registers <= '1';
        wait for clk_period;
        load_registers <= '0';

        for i in 0 to ITERATIONS-1 loop
            compute_AiB <= '1'; wait for clk_period; compute_AiB <= '0';
            compute_S <= '1'; wait for clk_period; compute_S <= '0';
            shift_registers <= '1'; wait for clk_period; shift_registers <= '0';
            wait for clk_period/2;
        end loop;

        wait for 4*clk_period;

        -- Test 3
        A <= x"00000000"; -- 0
        B <= x"00000007"; -- 7
        N <= x"00000005"; -- 5
        load_registers <= '1';
        wait for clk_period;
        load_registers <= '0';

        for i in 0 to ITERATIONS-1 loop
            compute_AiB <= '1'; wait for clk_period; compute_AiB <= '0';
            compute_S <= '1'; wait for clk_period; compute_S <= '0';
            shift_registers <= '1'; wait for clk_period; shift_registers <= '0';
            wait for clk_period/2;
        end loop;

        -- Finish
        wait for 100 ns;
        assert false report "End of simulation" severity failure;
    end process stim;

    -- Monitor: ensure AiB_reg (debug_res_add1) only changes when compute_AiB was asserted
    monitor_proc: process
        variable prev_aiB : std_logic_vector(WIDTH downto 0) := (others => '0');
        variable compute_now : std_logic := '0';
    begin
        wait until rising_edge(clk);
        compute_now := compute_AiB; -- sample current strobe at this edge
        -- check if debug_res_add1 changed on this edge but compute_AiB was not asserted on the same edge
        if debug_res_add1 /= prev_aiB then
            if compute_now = '0' then
                report "ERROR: AiB_reg changed but compute_AiB was 0 on the triggering edge. prev=" & to_hstring(prev_aiB) & " now=" & to_hstring(debug_res_add1) severity error;
            else
                report "INFO: AiB_reg updated as expected (compute_AiB=1). prev=" & to_hstring(prev_aiB) & " now=" & to_hstring(debug_res_add1) severity note;
            end if;
        end if;
        prev_aiB := debug_res_add1;
    end process monitor_proc;

end tb;
