library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation_tb is
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
    -- Test B: n=101, m=45, e=17 => m^e mod n = 66 (0x42)
    constant expected_B : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"0000000000000000000000000000000000000000000000000000000000000042";

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
        R_squared => R_squared_tb,
        clk       => clk,
        reset_n   => reset_n
    );

    -- stimulus process: apply reset, single test vector, wait for result
    stim : process
        variable cycles : integer := 0;
        constant TIMEOUT_CYCLES : integer := 20000; -- safety timeout
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
        report "Simulation finished" severity note;
        wait;
    end process stim;

end behavior;
