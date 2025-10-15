library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_mult_controller is
    generic (
           WIDTH : integer := 256  -- Operand width (e.g. 1024 bits for RSA)
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   -- Clock
           reset  : in  std_logic;   -- Active-high reset

              -- Control signals for datapath
              Compute_AiB : out std_logic;
              Compute_S   : out std_logic;
              load_registers : out std_logic;
              shift_registers : out std_logic;
               state_out : out std_logic_vector(2 downto 0);
               counter_out : out std_logic_vector(31 downto 0);
              -- Control interface
          enable : in  std_logic;   -- L  evel-sensitive start signal
          done   : out std_logic   -- Goes high when computation is finished (stays high until enable='0')

    );
end montgomery_mult_controller;

architecture Behavioral of montgomery_mult_controller is

    -- State machine states
    type state_type is (IDLE, INIT, ADD1, ADD2, SHIFT, FINISHED);
    signal state, next_state : state_type := IDLE;

    -- Bit counter
    signal counter : integer range 0 to WIDTH := 0;
begin
    -- Control signals for datapath
    -- Expose state as a small vector for waveform/debug
    state_out <= std_logic_vector(to_unsigned(state_type'pos(state), 3));
    counter_out <= std_logic_vector(to_unsigned(counter, 32));
    -- Combinational process: compute next state and outputs based on current state and inputs
    comb_proc : process(state, enable, counter)
    begin
        -- Default outputs
        load_registers <= '0';
        shift_registers <= '0';
        Compute_AiB <= '0';
        Compute_S <= '0';
        done <= '0';
        next_state <= state;

        case state is
            when IDLE =>
                if enable = '1' then
                    next_state <= INIT;
                else
                    next_state <= IDLE;
                end if;

            when INIT =>
                load_registers <= '1';
                next_state <= ADD1;

            when ADD1 =>
                -- wait one cycle for add1
                compute_AiB <= '1';
                next_state <= ADD2;

            when ADD2 =>
                compute_S <= '1';
                -- wait one cycle for add2
                next_state <= SHIFT;

            when SHIFT =>
                shift_registers <= '1';
                if counter < WIDTH-1 then
                    next_state <= ADD1;
                else
                    next_state <= FINISHED;
                end if;

            when FINISHED =>
                done <= '1';
                if enable = '0' then
                    next_state <= IDLE;
                else
                    next_state <= FINISHED;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process comb_proc;

    -- Synchronous process: update state and counter on clock edge with active-high reset
    seq_proc : process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            counter <= 0;
        elsif rising_edge(clk) then
            state <= next_state;
            if state = INIT then
                counter <= 0;
            elsif state = SHIFT then
                if counter < WIDTH then
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process seq_proc;
end Behavioral;
   