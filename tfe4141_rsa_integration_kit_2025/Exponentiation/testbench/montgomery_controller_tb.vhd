library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_controller_tb is
end montgomery_controller_tb;

architecture sim of montgomery_controller_tb is
    constant WIDTH : integer := 8; -- small width for testing

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal enable : std_logic := '0';
    signal load_registers : std_logic;
    signal shift_registers : std_logic;
    signal state_out : std_logic_vector(2 downto 0);
    signal counter_out : std_logic_vector(31 downto 0);
    signal done   : std_logic;

begin
    uut: entity work.montgomery_mult_controller
        generic map(
            WIDTH => WIDTH
        )
        port map(
            clk => clk,
            reset => reset,
            load_registers => load_registers,
            shift_registers => shift_registers,
            state_out => state_out,
                counter_out => counter_out,
            enable => enable,
            done => done
        );

    -- Clock
    clk_proc : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process clk_proc;
    -- Monitor process: prints key signals each clock
    monitor : process
    begin
        wait for 10 ns; -- align with clock period
        report "time=" & time'image(now) & " load=" & std_logic'image(load_registers)
            & " shift=" & std_logic'image(shift_registers) & " done=" & std_logic'image(done)
            & " state=" & integer'image(to_integer(unsigned(state_out))) &
            " counter=" & integer'image(to_integer(unsigned(counter_out)));
        wait;
    end process monitor;

    stim : process
    begin
        -- Reset
        reset <= '1';
        enable <= '0';
        wait for 20 ns;
        reset <= '0';
        wait for 20 ns;

        -- TEST 1
        report "Starting TEST 1";
        enable <= '1';
        -- Wait until controller raises done
        wait until done = '1';
        report "TEST 1 finished at " & time'image(now);
        -- release enable to allow controller to return to IDLE
        enable <= '0';
        wait for 20 ns;

        -- TEST 2
        report "Starting TEST 2";
        enable <= '1';
        wait until done = '1';
        report "TEST 2 finished at " & time'image(now);
        enable <= '0';
        wait for 20 ns;

        report "All tests finished.";
        wait;
    end process stim;
end sim;
