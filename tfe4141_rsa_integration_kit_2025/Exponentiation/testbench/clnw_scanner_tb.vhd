library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clnw_scanner_tb is
end clnw_scanner_tb;

architecture tb of clnw_scanner_tb is
    constant C_BLOCK : integer := 32;
    constant W_SIZE  : integer := 4;
    -- Large test constants (256-bit)
    constant C_BLOCK_LARGE : integer := 256;
    constant W_SIZE_LARGE  : integer := 4;

    -- DUT signals
    signal clk    : std_logic := '0';
    signal reset_n: std_logic := '0';
    signal key_sig: std_logic_vector(C_BLOCK-1 downto 0) := (others => '0');

    signal CLNW_scan_request : std_logic := '0';
    signal curr_pos          : integer := 0;
    signal CLNW_scan_active  : std_logic;
    signal CLNW_found        : std_logic;

    signal window_LSB        : integer;
    signal window_MSB        : integer;
    signal zero_window_count : integer;
    signal window_type       : integer;

    -- Signals for 256-bit DUT instance
    signal key_sig256: std_logic_vector(C_BLOCK_LARGE-1 downto 0) := (others => '0');
    signal CLNW_scan_request_256 : std_logic := '0';
    signal curr_pos_256          : integer := 0;
    signal CLNW_scan_active_256  : std_logic;
    signal CLNW_found_256        : std_logic;
    signal window_LSB_256        : integer;
    signal window_MSB_256        : integer;
    signal zero_window_count_256 : integer;
    signal window_type_256       : integer;

    -- timeout helper
    constant CLK_PERIOD : time := 10 ns;

begin
    -- Clock
    clk_proc : process
    begin
        while now < 200 ms loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process clk_proc;

    -- Instantiate DUT with smaller generics to speed simulation
    dut: entity work.clnw_scanner
        generic map (
            C_block_size => C_BLOCK,
            window_size  => W_SIZE
        )
        port map (
            clk => clk,
            reset_n => reset_n,
            key => key_sig,
            CLNW_scan_request => CLNW_scan_request,
            curr_pos => curr_pos,
            CLNW_scan_active => CLNW_scan_active,
            CLNW_found => CLNW_found,
            window_LSB => window_LSB,
            window_MSB => window_MSB,
            zero_window_count => zero_window_count,
            window_type => window_type
        );

    -- Instantiate DUT (256-bit) for performance test
    dut256: entity work.clnw_scanner
        generic map (
            C_block_size => C_BLOCK_LARGE,
            window_size  => W_SIZE_LARGE
        )
        port map (
            clk => clk,
            reset_n => reset_n,
            key => key_sig256,
            CLNW_scan_request => CLNW_scan_request_256,
            curr_pos => curr_pos_256,
            CLNW_scan_active => CLNW_scan_active_256,
            CLNW_found => CLNW_found_256,
            window_LSB => window_LSB_256,
            window_MSB => window_MSB_256,
            zero_window_count => zero_window_count_256,
            window_type => window_type_256
        );

    -- Stimulus
    stim: process
        variable wait_count : integer;
        variable cycles : integer;
        variable start_time : time;
    begin
        -- Reset
        reset_n <= '0';
        wait for 50 ns;
        reset_n <= '1';
        wait for 20 ns;

        -- Test 1: single LSB 1
        key_sig <= (others => '0');
        key_sig(0) <= '1';
        curr_pos <= 15;
        CLNW_scan_request <= '1';
        wait for CLK_PERIOD;
        CLNW_scan_request <= '0';

        -- wait for completion with timeout
        wait_count := 0;
        while CLNW_found = '0' and wait_count < 200 loop
            wait for CLK_PERIOD;
            wait_count := wait_count + 1;
        end loop;
        report "Test 1: key LSB=1 -> found=" & std_logic'image(CLNW_found) &
               " LSB=" & integer'image(window_LSB) &
               " MSB=" & integer'image(window_MSB) &
               " type=" & integer'image(window_type);
        wait for 40 ns;

        -- Test 2: non-zero window at pos=3 (pattern 0b0010_1000 -> bit3=1)
        key_sig <= (others => '0');
        key_sig(3) <= '1';
        key_sig(5) <= '1';
        curr_pos <= 15;
        CLNW_scan_request <= '1';
        wait for CLK_PERIOD;
        CLNW_scan_request <= '0';
        wait_count := 0;
        while CLNW_found = '0' and wait_count < 200 loop
            wait for CLK_PERIOD;
            wait_count := wait_count + 1;
        end loop;
        report "Test 2: key bits 3 and 5 -> found=" & std_logic'image(CLNW_found) &
               " LSB=" & integer'image(window_LSB) &
               " MSB=" & integer'image(window_MSB) &
               " type=" & integer'image(window_type);
        wait for 40 ns;

        -- Test 3: needs shrinking (bits 0..3 = 0100 -> initial window even)
        key_sig <= (others => '0');
        -- set bit2=1 so bits [3:0] => b3..b0 = 0100 (value 4), should shrink
        key_sig(2) <= '1';
        curr_pos <= 15;
        CLNW_scan_request <= '1';
        wait for CLK_PERIOD;
        CLNW_scan_request <= '0';
        wait_count := 0;
        while CLNW_found = '0' and wait_count < 200 loop
            wait for CLK_PERIOD;
            wait_count := wait_count + 1;
        end loop;
        report "Test 3: shrink case -> found=" & std_logic'image(CLNW_found) &
               " LSB=" & integer'image(window_LSB) &
               " MSB=" & integer'image(window_MSB) &
               " type=" & integer'image(window_type);
        wait for 40 ns;

     -- Test 4: 256-bit full scan timing (worst-case: all zero key)
     key_sig256 <= (others => '0');
     curr_pos_256 <= C_BLOCK_LARGE - 1;
     CLNW_scan_request_256 <= '1';
     wait for CLK_PERIOD;
     CLNW_scan_request_256 <= '0';
    -- measure cycles and time until found
    start_time := now;
    cycles := 0;
     while CLNW_found_256 = '0' and cycles < 10000 loop
         wait for CLK_PERIOD;
         cycles := cycles + 1;
     end loop;
     report "Test 4: 256-bit scan -> cycles=" & integer'image(cycles) &
         " elapsed_time=" & time'image(now - start_time) &
         " found=" & std_logic'image(CLNW_found_256);
     wait for 40 ns;

        report "CLNW scanner TB finished.";
        wait;
    end process stim;

end tb;
