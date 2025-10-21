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
        -- integer helpers for expected-value computation
        variable A_int      : integer := 0;
        variable B_int      : integer := 0;
        variable N_int      : integer := 0;
        variable R_mod_N    : integer := 0;
        variable R_inv      : integer := 0;
        variable expected_i : integer := 0;
        variable i          : integer := 0;
        variable seed       : integer := 123; -- deterministic seed for pseudo-random tests
    begin
        -- initial reset
        reset <= '1';
        enable <= '0';
        wait for 30 ns;
        reset <= '0';
        wait for 20 ns;

        -- TEST 1: A=3, B=5, N=7
        report "--- Starting Test 1 ---";
        A <= std_logic_vector(to_unsigned(3, WIDTH));
        B <= std_logic_vector(to_unsigned(5, WIDTH));
        N <= std_logic_vector(to_unsigned(7, WIDTH));
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
        -- compute expected Montgomery product: A*B*R^{-1} mod N, where R = 2^WIDTH
        A_int := to_integer(unsigned(A));
        B_int := to_integer(unsigned(B));
        N_int := to_integer(unsigned(N));
        R_mod_N := (2 ** WIDTH) mod N_int;
        R_inv := 0;
        for i in 0 to N_int-1 loop
            if (R_mod_N * i) mod N_int = 1 then
                R_inv := i;
                exit;
            end if;
        end loop;
        expected_i := (A_int * B_int * R_inv) mod N_int;
        if expected_i = to_integer(unsigned(S)) then
            report "Test1 PASSED: S=" & integer'image(expected_i) severity note;
        else
            report "Test1 FAILED: expected=" & integer'image(expected_i) & " got=" & integer'image(to_integer(unsigned(S))) severity failure;
        end if;

        -- small gap before next test
        wait for 40 ns;

        -- TEST 4: Conversion check via R^2: Mont(R^2, m) should equal m*R mod N
        report "--- Starting Test 4 (conversion via R^2) ---";
        -- choose N and m (ensure N is odd and >1)
        A <= std_logic_vector(to_unsigned(0, WIDTH)); -- will set A to R^2 mod N in stimulus below
        B <= std_logic_vector(to_unsigned(7, WIDTH)); -- m = 7
        N <= std_logic_vector(to_unsigned(11, WIDTH)); -- N = 11
        wait for 10 ns;
        -- compute R^2 mod N in variables and place into A
        A_int := to_integer(unsigned(A)); -- clear
        N_int := to_integer(unsigned(N));
        R_mod_N := (2 ** WIDTH) mod N_int;
        -- R^2 mod N
        A_int := (R_mod_N * R_mod_N) mod N_int;
        A <= std_logic_vector(to_unsigned(A_int, WIDTH));

        -- pulse enable
        enable <= '1'; wait for 10 ns; enable <= '0';
        wait until done = '1'; wait for 10 ns;
        -- expected = m * R mod N
        expected_i := (to_integer(unsigned(B)) * (2 ** WIDTH)) mod N_int;
        if expected_i = to_integer(unsigned(S)) then
            report "Test4 PASSED: conversion Mont(R^2,m) == m*R mod N => " & integer'image(expected_i) severity note;
        else
            report "Test4 FAILED: expected=" & integer'image(expected_i) & " got=" & integer'image(to_integer(unsigned(S))) severity failure;
        end if;

        wait for 40 ns;

        -- TEST 5..12: Deterministic pseudo-random tests
    report "--- Starting deterministic random tests (8 cases) ---";
        for j in 1 to 8 loop
            -- simple LCG-like generator (small, safe integers)
            seed := (seed * 73 + 17) mod 251;
            -- construct an odd modulus N between 3 and 127
            N_int := (seed mod 125) + 3;
            if (N_int mod 2) = 0 then
                N_int := N_int + 1;
            end if;
            -- pick operands A and B in range 0..N-1
            A_int := seed mod N_int;
            seed := (seed * 73 + 17) mod 251;
            B_int := seed mod N_int;

            A <= std_logic_vector(to_unsigned(A_int, WIDTH));
            B <= std_logic_vector(to_unsigned(B_int, WIDTH));
            N <= std_logic_vector(to_unsigned(N_int, WIDTH));
            wait for 10 ns;
            enable <= '1'; wait for 10 ns; enable <= '0';
            wait until done = '1'; wait for 10 ns;

            -- compute expected Mont(A,B) = A*B*R^{-1} mod N
            R_mod_N := (2 ** WIDTH) mod N_int;
            R_inv := 0;
            for i in 0 to N_int-1 loop
                if (R_mod_N * i) mod N_int = 1 then
                    R_inv := i;
                    exit;
                end if;
            end loop;
            expected_i := (A_int * B_int * R_inv) mod N_int;
            if expected_i = to_integer(unsigned(S)) then
                report "Rand test " & integer'image(j) & " PASSED: A=" & integer'image(A_int) & " B=" & integer'image(B_int) & " N=" & integer'image(N_int) & " S=" & integer'image(expected_i) severity note;
            else
                report "Rand test " & integer'image(j) & " FAILED: A=" & integer'image(A_int) & " B=" & integer'image(B_int) & " N=" & integer'image(N_int) & " expected=" & integer'image(expected_i) & " got=" & integer'image(to_integer(unsigned(S))) severity failure;
            end if;
            wait for 20 ns;
        end loop;

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
        -- compute expected for Test2
        A_int := to_integer(unsigned(A));
        B_int := to_integer(unsigned(B));
        N_int := to_integer(unsigned(N));
        R_mod_N := (2 ** WIDTH) mod N_int;
        R_inv := 0;
        for i in 0 to N_int-1 loop
            if (R_mod_N * i) mod N_int = 1 then
                R_inv := i;
                exit;
            end if;
        end loop;
        expected_i := (A_int * B_int * R_inv) mod N_int;
        if expected_i = to_integer(unsigned(S)) then
            report "Test2 PASSED: S=" & integer'image(expected_i) severity note;
        else
            report "Test2 FAILED: expected=" & integer'image(expected_i) & " got=" & integer'image(to_integer(unsigned(S))) severity failure;
        end if;

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
        -- compute expected for Test3
        A_int := to_integer(unsigned(A));
        B_int := to_integer(unsigned(B));
        N_int := to_integer(unsigned(N));
        R_mod_N := (2 ** WIDTH) mod N_int;
        R_inv := 0;
        for i in 0 to N_int-1 loop
            if (R_mod_N * i) mod N_int = 1 then
                R_inv := i;
                exit;
            end if;
        end loop;
        expected_i := (A_int * B_int * R_inv) mod N_int;
        if expected_i = to_integer(unsigned(S)) then
            report "Test3 PASSED: S=" & integer'image(expected_i) severity note;
        else
            report "Test3 FAILED: expected=" & integer'image(expected_i) & " got=" & integer'image(to_integer(unsigned(S))) severity failure;
        end if;

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
