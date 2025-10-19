library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench for `memory` (4 x 256-bit words implemented with BRAM_SINGLE_MACRO)
-- Writes four distinct 256-bit patterns, reads them back and checks equality.

entity memory_tb is
end memory_tb;

architecture tb of memory_tb is
    -- DUT signals
    constant WINDOW_SIZE : integer := 4; -- must match memory generic
    constant NUM_ADDR : integer := 2**WINDOW_SIZE;

    signal clk  : std_logic := '0';
    signal en   : std_logic := '1';
    signal we   : std_logic := '0';
    signal addr : std_logic_vector(WINDOW_SIZE-1 downto 0) := (others => '0');
    signal din  : std_logic_vector(255 downto 0) := (others => '0');
    signal dout : std_logic_vector(255 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    signal errors : integer := 0;
begin

    -- Clock
    clk_proc : process
    begin
        while now < 5 ms loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process clk_proc;

    -- Instantiate DUT
    uut: entity work.memory
        port map (
            clk => clk,
            en  => en,
            we  => we,
            addr => addr,
            din => din,
            dout => dout
        );

    -- Stimulus: write all locations, then read back and compare
    stimulus_proc : process
        variable expected : std_logic_vector(255 downto 0);
    begin
        wait for 100 ns; -- reset time

        -- Write all locations
        for i in 0 to NUM_ADDR-1 loop
            addr <= std_logic_vector(to_unsigned(i, addr'length));
         -- generate a deterministic 256-bit test pattern for this address
         din <= std_logic_vector(to_unsigned(i, 32)) &
             std_logic_vector(to_unsigned(i + 16#A5A5#, 32)) &
             std_logic_vector(to_unsigned(i + 16#5A5A#, 32)) &
             std_logic_vector(not to_unsigned(i, 32)) &
             std_logic_vector(to_unsigned(i*3, 32)) &
             std_logic_vector(to_unsigned(i*7, 32)) &
             std_logic_vector(to_unsigned(i*11, 32)) &
             std_logic_vector(to_unsigned(i*13, 32));
            we <= '1';
            wait for CLK_PERIOD; -- write on rising edge
            we <= '0';
            wait for CLK_PERIOD/2;
        end loop;

        -- Small pause
        wait for 5 * CLK_PERIOD;

        -- Read and check
        for i in 0 to NUM_ADDR-1 loop
            addr <= std_logic_vector(to_unsigned(i, addr'length));
            wait for CLK_PERIOD*3; -- allow data to appear
            -- regenerate expected pattern
            expected := std_logic_vector(to_unsigned(i, 32)) &
                        std_logic_vector(to_unsigned(i + 16#A5A5#, 32)) &
                        std_logic_vector(to_unsigned(i + 16#5A5A#, 32)) &
                        std_logic_vector(not to_unsigned(i, 32)) &
                        std_logic_vector(to_unsigned(i*3, 32)) &
                        std_logic_vector(to_unsigned(i*7, 32)) &
                        std_logic_vector(to_unsigned(i*11, 32)) &
                        std_logic_vector(to_unsigned(i*13, 32));
            if dout /= expected then
                report "Mismatch at address " & integer'image(i) severity error;
                errors <= errors + 1;
            else
                report "Match at address " & integer'image(i) severity note;
            end if;
            wait for CLK_PERIOD/2;
        end loop;

        if errors = 0 then
            report "memory_tb: PASS" severity note;
        else
            report "memory_tb: FAIL: " & integer'image(errors) & " mismatches" severity error;
        end if;

        wait;
    end process stimulus_proc;
end tb;
