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
    -- expected result computed from m^e mod n (padded to 256 bits)
    constant expected_result : std_logic_vector(C_block_size-1 downto 0) := x"2A90786EB4D14DD53B266674C4B099384EA516DBFEDF21D8CA4EBC23A798349B";

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

    -- Load 256-bit test vectors generated externally
    -- n = 0x9762f99d129b9516d99b96b7804d2d2db2f3f23c8aa6d2c09846515a9dc611ab
    modulus <= (others => '0');
    modulus <= x"99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d";
    -- message m (256-bit)
    message <= x"4c39f6bd28233d66a8e052365f65a3d61914323632f2e20411942f47fbb85cdf";
    -- exponent/key (use small public exponent 0x10001)
    --key <= (others => '0');
    -- key(31 downto 0) <= std_logic_vector(to_unsigned(16#10001#, 32));
    key <= x"0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9";

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
                report "TIMEOUT waiting for valid_out" severity failure;
                wait;
            end if;
        end loop;

        -- capture and check full-width result
        if result = expected_result then
            report "Test PASSED: result matches expected ciphertext" severity note;
        else
            report "Test FAILED: result does not match expected ciphertext" severity failure;
            report "Expected: " & to_hex_str(expected_result) severity note;
            report "Got     : " & to_hex_str(result) severity note;
        end if;

        wait for 100 ns;
        report "Simulation finished" severity note;
        wait;
    end process stim;

end behavior;
