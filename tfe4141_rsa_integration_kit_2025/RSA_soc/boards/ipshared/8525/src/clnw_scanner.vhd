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
        curr_pos          : in  integer;
        CLNW_found        : out std_logic;

        -- Results
        window_LSB        : out integer;
        window_MSB        : out integer;
        zero_window_count : out integer;
        window_type       : out integer
    );
end clnw_scanner;

architecture RTL of clnw_scanner is
    signal LSB : integer;
    signal MSB : integer;
    signal zero_count : integer;
    signal active : std_logic;
begin

process(clk, reset_n)
    variable exp_counter : integer range 0 to C_block_size-1 := 0;
    variable next_cnt : integer range 0 to C_block_size-1 := 0;
begin
    if reset_n = '0' then
        active <= '0';
        CLNW_found <= '0';
        LSB <= 0;
        MSB <= 0;
        zero_count <= 0;
        window_type <= 0;
        next_cnt := 0;
        exp_counter := 0;
    elsif rising_edge(clk) then
        if CLNW_scan_request = '1' then
            next_cnt := 0;
            CLNW_found <= '0';
            active <= '1';
            LSB <= 0;
            MSB <= 0;
            zero_count <= 0;
            window_type <= 0;

        elsif active = '1' and (exp_counter <= curr_pos or curr_pos <= window_size) then
            -- Use the current exp_counter to index key, and compute next_cnt in a variable
            if key(exp_counter) = '1' then
                zero_count <= 0;
                MSB <= exp_counter + window_size-1;
                LSB <= exp_counter;
                next_cnt := exp_counter + window_size;
                window_type <= 1;  -- non-zero window
            else
                zero_count <= zero_count + 1;
                window_type <= 0;  -- zero window
                next_cnt := exp_counter + 1;
            end if;

            if next_cnt <= curr_pos then
                CLNW_found <= '0';
            else
                CLNW_found <= '1';
                active <= '0';
                next_cnt := 0;
            end if;
        else
            -- Default: keep counter unchanged
            next_cnt := exp_counter;
        end if;

    -- assign computed next state to the register-variable
    exp_counter := next_cnt;
    end if;
end process;

window_LSB        <= LSB;
window_MSB        <= MSB;
zero_window_count <= zero_count;

end RTL;
