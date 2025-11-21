library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_mult_controller is
    generic (
           WIDTH : integer := 256
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   -- Clock
           reset  : in  std_logic;   -- Active-high reset

            Compute_AiB : out std_logic;
            Compute_S   : out std_logic;
            load_registers : out std_logic;
            shift_registers : out std_logic;
            finalize : out std_logic;
            state_out : out std_logic_vector(2 downto 0);
            counter_out : out std_logic_vector(31 downto 0);
              
          enable : in  std_logic;   
          done   : out std_logic   

    );
end montgomery_mult_controller;

architecture Behavioral of montgomery_mult_controller is

    -- State machine states - use binary encoding for area optimization
    type state_type is (IDLE, INIT, ADD1, ADD2, SHIFT, FINAL_SUB, FINISHED);
    attribute ENUM_ENCODING : string;
    attribute ENUM_ENCODING of state_type : type is "sequential";
    signal state, next_state : state_type := IDLE;

    -
    signal counter : unsigned(7 downto 0) := (others => '0');
begin
    
    state_out <= std_logic_vector(to_unsigned(state_type'pos(state), 3));
    counter_out <= std_logic_vector(resize(counter, 32));


    -- Combinational process: compute next state and outputs based on current state and inputs
    comb_proc : process(state, enable, counter)
    begin
        -- Default outputs
        load_registers <= '0';
        shift_registers <= '0';
        Compute_AiB <= '0';
        Compute_S <= '0';
        finalize <= '0';
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
                if counter < to_unsigned(WIDTH-1, 8) then
                    next_state <= ADD1;
                else
                    next_state <= FINAL_SUB;
                end if;

            when FINAL_SUB =>
                -- request final conditional subtraction in datapath
                finalize <= '1';
                next_state <= FINISHED;

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
            counter <= (others => '0');
        elsif rising_edge(clk) then
            state <= next_state;
            if state = INIT then
                counter <= (others => '0');
            elsif state = SHIFT then
                counter <= counter + 1;
            end if;
        end if;
    end process seq_proc;
end Behavioral;
   