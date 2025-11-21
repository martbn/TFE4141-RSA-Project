library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity exponentiation_tb is
    generic (
        AUTO_FINISH : boolean := false  -- if true, TB will call finish(0) at end
    );
end exponentiation_tb;

architecture behavior of exponentiation_tb is
    constant C_block_size : integer := 256;

    -- clocks and control
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';

    -- top-level ports
    signal valid_in  : std_logic := '0';
    signal ready_in  : std_logic;
    signal message   : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal key       : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal ready_out : std_logic := '0';
    signal valid_out : std_logic;
    signal result    : std_logic_vector(C_block_size-1 downto 0);
    signal modulus   : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal R_mod_n_tb : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal R_squared_tb : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    -- expected results for small test vectors (padded to 256 bits)
    -- Test A: n=53, m=10, e=7 => m^e mod n = 13 (0x0D)
    constant expected_A : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"000000000000000000000000000000000000000000000000000000000000000D";
    -- Test B: n=101, m=45, e=17 => m^e mod n = 85 (0x55)
    constant expected_B : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"0000000000000000000000000000000000000000000000000000000000000055";
    -- Test B2: n=65537, m=0xDEADBEEF, e=65537 => computed result 0xE043
    constant expected_B2 : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"000000000000000000000000000000000000000000000000000000000000E043";
    -- Test C: larger modulus/message example — computed expected result
    constant expected_C : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"5635AB8CFD7390F2A13BD77238E4DFD2089E0216021806DB3B4E8BEE2B29C735";
    -- TEST D: new vector using provided exponent/key; expected computed = message^key mod modulus
    -- key: 0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9
    constant expected_D : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"1A186AAF91F650BD5CA4DCA6CFB7A041E28F5F11EDECCF8949A39ED10A65C246";

    -- helper: convert std_logic_vector to hex string (MSB first)
    constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
    function to_hex_str(sv : std_logic_vector) return string is
        constant hexlen : integer := sv'length / 4;
        variable res : string(1 to hexlen);
        variable nib : std_logic_vector(3 downto 0);
        variable idx : integer;
    begin
        for i in 0 to hexlen-1 loop
            nib := sv(sv'high - 4*i downto sv'high - 4*i - 3);
            idx := to_integer(unsigned(nib)) + 1; -- 1..16
            res(i+1) := HEX_CHARS(idx);
        end loop;
        return res;
    end function;

begin

    -- simple clock: 10 ns period
    clk_proc : process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process clk_proc;

    -- instantiate DUT
    uut: entity work.exponentiation
    generic map (
        C_block_size => C_block_size,
        window_size  => 4
    )
    port map (
        valid_in  => valid_in,
        ready_in  => ready_in,
        message   => message,
        key       => key,
        ready_out => ready_out,
        valid_out => valid_out,
        result    => result,
        modulus   => modulus,
        R_mod_n   => R_mod_n_tb,
        R_squared_mod_n => R_squared_tb,
        clk       => clk,
        reset_n   => reset_n
    );

    -- stimulus process: apply reset, single test vector, wait for result
    stim : process
        variable cycles : integer := 0;
        constant TIMEOUT_CYCLES : integer := 30000; -- safety timeout
        variable small_timeout : integer := 500; -- short timeout for per-test ready wait (allows forcing a pulse)
        variable res_int : integer := 0;
        variable res_vec : std_logic_vector(C_block_size-1 downto 0);
    begin
        -- reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 20 ns;

    -- Run Test A (small vector)
    -- NEW VECTOR: n = 53, m = 10, e = 7
    modulus <= x"0000000000000000000000000000000000000000000000000000000000000035"; -- 0x35 = 53
    message <= x"000000000000000000000000000000000000000000000000000000000000000A"; -- 10
    key <= x"0000000000000000000000000000000000000000000000000000000000000007"; -- 7
    -- Use R = 2^256 (montgomery core WIDTH = 256). For n=53:
    -- R mod n = 2^256 mod 53 = 10 (0x0A), R^2 mod n = 10^2 mod 53 = 47 (0x2F)
    R_mod_n_tb <= x"000000000000000000000000000000000000000000000000000000000000000A";
    R_squared_tb <= x"000000000000000000000000000000000000000000000000000000000000002F";

    wait for 20 ns;

    -- Wait for DUT to indicate ready to accept inputs
    cycles := 0;
    while ready_in /= '1' loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for ready_in (Test A)" severity failure;
            wait;
        end if;
    end loop;

    -- Ensure consumer is ready to accept the result
    ready_out <= '1';

    -- pulse valid_in for one clock when ready_in is high
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';


    -- wait for both valid_out and our ready_out (consumer accept)
    cycles := 0;
    while not (valid_out = '1' and ready_out = '1') loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out & ready_out (Test A)" severity failure;
            wait;
        end if;
    end loop;

    -- read result when accepted
    res_vec := result;

    -- check result for Test A
    if res_vec = expected_A then
        report "Test A PASSED: result matches expected (10^7 mod 53 = 13)" severity note;
    else
        report "Test A FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_A) severity note;
        report "Got     : " & to_hex_str(res_vec) severity note;
    end if;

    -- we've accepted the result, deassert consumer ready
    ready_out <= '0';

    wait for 100 ns;

    -- Run Test B2 (medium vector): n = 65537, m = 0xDEADBEEF, e = 65537 (0x10001)
    -- This is more complex than Test B but smaller than the large Test C.
    modulus <= x"0000000000000000000000000000000000000000000000000000000000010001"; -- 65537
    message <= x"00000000000000000000000000000000000000000000000000000000DEADBEEF"; -- 0xDEADBEEF
    key <= x"0000000000000000000000000000000000000000000000000000000000010001"; -- 65537
    -- R = 2^256 mod 65537 = 1, R^2 mod n = 1
    R_mod_n_tb <= x"0000000000000000000000000000000000000000000000000000000000000001";
    R_squared_tb <= x"0000000000000000000000000000000000000000000000000000000000000001";

    wait for 20 ns;

    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';
    -- Wait for DUT to indicate ready to accept inputs
    cycles := 0;
    while ready_in /= '1' loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for ready_in (Test B2)" severity failure;
            wait;
        end if;
    end loop;

    -- consumer ready
    ready_out <= '1';

    -- pulse valid_in for one clock when ready_in is high
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';

    cycles := 0;
    while not (valid_out = '1' and ready_out = '1') loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out & ready_out (Test B2)" severity failure;
            wait;
        end if;
    end loop;

    -- read result when accepted
    res_vec := result;
    report "Test B2: result (hex) = " & to_hex_str(res_vec) severity note;

    -- compare with expected value for Test B2
    if res_vec = expected_B2 then
        report "Test B2 PASSED: result matches expected (DEADBEEF^65537 mod 65537)" severity note;
    else
        report "Test B2 FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_B2) severity note;
        report "Got     : " & to_hex_str(res_vec) severity note;
    end if;

    -- we've accepted the result, deassert consumer ready
    ready_out <= '0';

    wait for 100 ns;

    -- Run Test B (small vector)
    -- n = 101, m = 45, e = 17
    modulus <= x"0000000000000000000000000000000000000000000000000000000000000065"; -- 0x65
    message <= x"000000000000000000000000000000000000000000000000000000000000002D"; -- 45
    key <= x"0000000000000000000000000000000000000000000000000000000000000011"; -- 17
    -- Use R = 2^256 (montgomery core WIDTH = 256). For n=101:
    -- R mod n = 2^256 mod 101 = 37 (0x25), R^2 mod n = 37^2 mod 101 = 56 (0x38)
    R_mod_n_tb <= x"0000000000000000000000000000000000000000000000000000000000000025";
    R_squared_tb <= x"0000000000000000000000000000000000000000000000000000000000000038";

    wait for 20 ns;

    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';
    -- Wait for DUT to indicate ready to accept inputs
    cycles := 0;
    while ready_in /= '1' loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for ready_in (Test B)" severity failure;
            wait;
        end if;
    end loop;

    -- consumer ready
    ready_out <= '1';

    -- pulse valid_in for one clock when ready_in is high
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';

    cycles := 0;
    while not (valid_out = '1' and ready_out = '1') loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out & ready_out (Test B)" severity failure;
            wait;
        end if;
    end loop;

    -- read result when accepted
    res_vec := result;

    -- check result for Test B
    if res_vec = expected_B then
        report "Test B PASSED: result matches expected (45^17 mod 101 = 66)" severity note;
    else
        report "Test B FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_B) severity note;
        report "Got     : " & to_hex_str(res_vec) severity note;
    end if;

    -- we've accepted the result, deassert consumer ready
    ready_out <= '0';

    wait for 100 ns;

    -- Run Test C: encrypt one of the large messages from short_test.inp_messages.hex_pt2_in.txt
    -- NOTE: R_mod_n and R_squared_mod_n must be computed for the modulus for correct Montgomery behaviour.
    -- Here we exercise the DUT with the provided modulus/message/exponent and print the result for inspection.
    modulus <= x"99925173AD65686715385EA800CD28120288FC70A9BC98DD4C90D676F8FF768D"; -- KEY N from file
    -- Example message (first message block from the file)
    message <= x"2323232323232323232323232323232323232323232323232323232323232323";
    -- Public exponent KEY E (common 0x10001)
    key <= x"0000000000000000000000000000000000000000000000000000000000010001";
    -- Computed R_mod_n and R_squared_mod_n for this modulus
    R_mod_n_tb <= x"666DAE8C529A9798EAC7A157FF32D7EDFD77038F56436722B36F298907008973";
    R_squared_tb <= x"56DDF8B43061AD3DBCD1757244D1A19E2E8C849DDE4817E55BB29D1C20C06364";
    wait for 20 ns;

    -- Indicate consumer readiness to the DUT, aligned to the clock to avoid races.
    ready_out <= '1';
    -- give the DUT one clock to sample ready_out
    wait until rising_edge(clk);

    -- Wait for DUT to indicate it's ready to accept inputs (ready_in), sampled on rising edges.
    cycles := 0;
    while ready_in /= '1' loop
        wait until rising_edge(clk);
        cycles := cycles + 1;
        if cycles > small_timeout then
            report "WARNING: ready_in did not assert within small timeout for Test C; forcing valid_in pulse" severity warning;
            exit; -- break out and force valid pulse below
        end if;
    end loop;

    -- Pulse valid_in synchronized to the clock when ready_in asserted (or forced after timeout).
    if ready_in = '1' then
        report "TEST C: pulsing valid_in (ready_in=1)" severity note;
    else
        report "TEST C: pulsing valid_in (ready_in=0)" severity warning;
    end if;
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';
    report "TEST C: valid_in pulsed" severity note;

    cycles := 0;
    while not (valid_out = '1' and ready_out = '1') loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out & ready_out (Test B)" severity failure;
            wait;
        end if;
    end loop;

    -- Allow some time for the DUT to produce/hold the result if it hasn't already
    wait for 100 ns;

    -- read result and compare with expected value for Test C
    res_vec := result;
    if res_vec = expected_C then
        report "Test C PASSED: result matches expected" severity note;
    else
        report "Test C FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_C) severity note;
        report "Got     : " & to_hex_str(res_vec) severity note;
    end if;

    wait for 100 ns;

    -- NEW TEST D: same modulus/message as Test C, but with provided long key
    report "--- Starting Test D (provided key) ---";
    -- reuse modulus and message from Test C
    modulus <= x"99925173AD65686715385EA800CD28120288FC70A9BC98DD4C90D676F8FF768D";
    message <= x"2323232323232323232323232323232323232323232323232323232323232323";
    key <= x"0CEA1651EF44BE1F1F1476B7539BED10D73E3AAC782BD9999A1E5A790932BFE9";
    -- same R constants as Test C
    R_mod_n_tb <= x"666DAE8C529A9798EAC7A157FF32D7EDFD77038F56436722B36F298907008973";
    R_squared_tb <= x"56DDF8B43061AD3DBCD1757244D1A19E2E8C849DDE4817E55BB29D1C20C06364";
    wait for 20 ns;

    -- Indicate consumer readiness to the DUT, aligned to the clock
    ready_out <= '1';
    wait until rising_edge(clk);

    cycles := 0;
    while ready_in /= '1' loop
        wait until rising_edge(clk);
        cycles := cycles + 1;
        if cycles > small_timeout then
            report "WARNING: ready_in did not assert within small timeout for Test D; forcing valid_in pulse" severity warning;
            exit;
        end if;
    end loop;

    -- Pulse valid_in synchronized to the clock when ready_in asserted (or forced after timeout).
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';

    cycles := 0;
    while not (valid_out = '1' and ready_out = '1') loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out & ready_out (Test D)" severity failure;
            wait;
        end if;
    end loop;

    wait for 100 ns;
    res_vec := result;
    if res_vec = expected_D then
        report "Test D PASSED: result matches expected for provided key" severity note;
    else
        report "Test D FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_D) severity note;
        report "Got     : " & to_hex_str(res_vec) severity note;
    end if;

    report "Simulation finished" severity note;
    if AUTO_FINISH then
        wait for 50 ns;
        report "AUTO_FINISH enabled: terminating simulation" severity note;
        finish(0);
        wait;
    else
        wait;
    end if;
    end process stim;

end behavior;
