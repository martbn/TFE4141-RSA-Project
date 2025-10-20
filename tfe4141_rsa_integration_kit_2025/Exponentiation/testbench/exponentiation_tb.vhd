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
    signal ready_out : std_logic;
    signal valid_out : std_logic;
    signal result    : std_logic_vector(C_block_size-1 downto 0);
    signal modulus   : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal R_mod_n_tb : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal R_squared_tb : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    -- expected results for small test vectors (padded to 256 bits)
    -- Test A: n=37, m=7, e=13 => m^e mod n = 33 (0x21)
    constant expected_A : std_logic_vector(C_block_size-1 downto 0) := (others => '0') when false else x"0000000000000000000000000000000000000000000000000000000000000021";
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
    begin
        -- reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 20 ns;

    -- Run Test A (small vector)
    -- n = 37, m = 7, e = 13
    modulus <= x"0000000000000000000000000000000000000000000000000000000000000025"; -- 0x25
    message <= x"0000000000000000000000000000000000000000000000000000000000000007"; -- 7
    key <= x"000000000000000000000000000000000000000000000000000000000000000D"; -- 13
    -- R = 64 (k=6), R mod n = 64 mod 37 = 27 (0x1B), R^2 mod n = 26 (0x1A)
    R_mod_n_tb <= x"000000000000000000000000000000000000000000000000000000000000001B";
    R_squared_tb <= x"000000000000000000000000000000000000000000000000000000000000001A";

    wait for 20 ns;

    -- pulse valid_in for one clock
    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';

    -- wait for valid_out with timeout
    cycles := 0;
    while valid_out /= '1' loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out (Test A)" severity failure;
            wait;
        end if;
    end loop;

    -- check result for Test A
    if result = expected_A then
        report "Test A PASSED: result matches expected (7^13 mod 37 = 33)" severity note;
    else
        report "Test A FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_A) severity note;
        report "Got     : " & to_hex_str(result) severity note;
    end if;

    wait for 100 ns;

    -- Run Test B (small vector)
    -- n = 101, m = 45, e = 17
    modulus <= x"0000000000000000000000000000000000000000000000000000000000000065"; -- 0x65
    message <= x"000000000000000000000000000000000000000000000000000000000000002D"; -- 45
    key <= x"0000000000000000000000000000000000000000000000000000000000000011"; -- 17
    -- R = 128 (k=7), R mod n = 128 mod 101 = 27 (0x1B), R^2 mod n = 22 (0x16)
    R_mod_n_tb <= x"000000000000000000000000000000000000000000000000000000000000001B";
    R_squared_tb <= x"0000000000000000000000000000000000000000000000000000000000000016";

    wait for 20 ns;

    valid_in <= '1';
    wait until rising_edge(clk);
    valid_in <= '0';

    cycles := 0;
    while valid_out /= '1' loop
        wait for 10 ns;
        cycles := cycles + 1;
        if cycles > TIMEOUT_CYCLES then
            report "TIMEOUT waiting for valid_out (Test B)" severity failure;
            wait;
        end if;
    end loop;

    -- check result for Test B
    if result = expected_B then
        report "Test B PASSED: result matches expected (45^17 mod 101 = 66)" severity note;
    else
        report "Test B FAILED: result does not match expected" severity failure;
        report "Expected: " & to_hex_str(expected_B) severity note;
        report "Got     : " & to_hex_str(result) severity note;
    end if;

        wait for 100 ns;
        report "Simulation finished" severity note;
        wait;
    end process stim;

end behavior;
