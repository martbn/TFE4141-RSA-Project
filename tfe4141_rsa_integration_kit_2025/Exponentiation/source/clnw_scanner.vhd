library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clnw_scanner is
    generic (
        C_block_size : integer := 256;
        window_size  : integer := 4
    );
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        key     : in  std_logic_vector(C_block_size-1 downto 0);

        -- Control interface
        CLNW_scan_request : in  std_logic;
        CLNW_scan_active  : out std_logic;
        CLNW_found        : out std_logic;

        -- Results
        window_LSB        : out integer;
        window_MSB        : out integer;
        zero_window_count : out integer;
        window_type       : out integer
    );
end clnw_scanner;

architecture RTL of clnw_scanner is
    signal exp_counter : integer range 0 to C_block_size-1 := 0;
begin

process(clk, reset_n)
begin
    if reset_n = '0' then
        exp_counter <= 0;
        CLNW_scan_active <= '0';
        CLNW_found <= '0';
        window_LSB <= 0;
        window_MSB <= 0;
        zero_window_count <= 0;
        window_type <= 0;
    elsif rising_edge(clk) then
        if CLNW_scan_request = '1' then
            exp_counter <= 0;
            CLNW_found <= '0';
            CLNW_scan_active <= '1';
            window_LSB <= 0;
            window_MSB <= 0;
            zero_window_count <= 0;
            window_type <= 0;

        elsif CLNW_scan_active = '1' and CLNW_found = '0' then
            if key(exp_counter) = '1' then
                window_MSB <= window_MSB + window_size - 1;
                window_LSB <= exp_counter;
                window_type <= 1;  -- non-zero window
                CLNW_found <= '1';
            else
                zero_window_count <= zero_window_count + 1;
                window_type <= 0;  -- zero window
            end if;
            exp_counter <= exp_counter + 1;
            if exp_counter = C_block_size - 1 then
                CLNW_scan_active <= '0';
            end if;
        end if;
    end if;
end process;

end RTL;
