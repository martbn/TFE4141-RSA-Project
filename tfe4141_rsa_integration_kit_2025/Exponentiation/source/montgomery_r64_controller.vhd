library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_r64_controller is
    generic (
           WIDTH : integer := 256  -- Operand width (e.g. 1024 bits for RSA)
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   -- Clock
           reset  : in  std_logic;   -- Active-high reset

            sig_state   : out  std_logic;
            shift_a : out std_logic;
            shift_b : out std_logic;
            --first_Outer_loop_state : in unsigned(1 downto 0);
            
            last_outer_loop_state : out std_logic_vector(3 downto 0);

            activate_gamma_final : out std_logic;
            activate_gamma1 : out std_logic;
            activate_gamma2 : out std_logic;
            activate_gamma3 : out std_logic;
            activate_beta : out std_logic;
            activate_alpha1 : out std_logic;
            activate_alpha2 : out std_logic;
            activate_alpha3 : out std_logic;
            activate_alpha_final : out std_logic;
          enable : in  std_logic;   -- Level-sensitive start signal
          done   : out std_logic;   -- Goes high when computation is finished (stays high until enable='0')
          
          -- Debug outputs to see state in waveform
          current_state_debug : out integer range 0 to 4;  -- 0=IDLE, 1=STATE1, 2=STATE2, 3=STATE3, 4=FINISHED
          outer_iteration_counter_debug : out unsigned(3 downto 0)  -- Current iteration counter

    );
end montgomery_r64_controller;

architecture Behavioral of montgomery_r64_controller is

    -- State machine states
    type state_type is (IDLE, INIT, STATE1, STATE2, STATE3, FINISHED);
    signal state, next_state : state_type := IDLE;

    -- Bit counter
    signal outer_iteration_counter : unsigned(3 downto 0) := (others => '0');
    signal last_outer_loop_state_reg : unsigned(3 downto 0) := (others => '0');
    
begin
    -- Connect internal register to output port (convert unsigned to std_logic_vector)
    last_outer_loop_state <= std_logic_vector(last_outer_loop_state_reg);
    outer_iteration_counter_debug <= outer_iteration_counter;
    
    -- Convert state to integer for waveform viewing
    with state select current_state_debug <=
        0 when IDLE,
        1 when INIT,
        2 when STATE1,
        3 when STATE2,
        4 when STATE3,
        5 when FINISHED,
        0 when others;
    
    -- Combinational process: compute next state and outputs based on current state
    comb_proc : process(state, enable, outer_iteration_counter, last_outer_loop_state_reg)
    begin
        -- Default outputs
        sig_state <= '0';
        shift_a <= '0';
        shift_b <= '0';
        done <= '0';
        activate_gamma_final <= '0';
        activate_gamma1 <= '0';
        activate_gamma2 <= '0';
        activate_gamma3 <= '0';
        activate_beta <= '0';
        activate_alpha1 <= '0';
        activate_alpha2 <= '0';
        activate_alpha3 <= '0';
        activate_alpha_final <= '0';
        next_state <= state;

        case state is
            when IDLE =>
                if enable = '1' then
                    next_state <= INIT;
                end if;

            when INIT =>
                -- In INIT state: operands get loaded into shifters
                -- NO shift here - let STATE1 see word 0 first
                next_state <= STATE1;
                shift_b <= '1';

            when STATE1 =>
                sig_state <= '0';
                -- Use word 0 in STATE1
                -- Shift B here so word 2 is ready when we enter STATE3
                shift_b <= '1';
                activate_beta <= '1';
                activate_alpha1 <= '1';
                
                if outer_iteration_counter >= 1 then
                    activate_alpha2 <= '1';
                    activate_gamma2 <= '1';
                end if;
                
                if outer_iteration_counter >= 2 then
                    activate_alpha3 <= '1';
                    activate_gamma3 <= '1';
                end if;
                
                if outer_iteration_counter > 2 then
                    activate_gamma_final <= '1';
                end if;
                
                if last_outer_loop_state_reg = "1000" then
                    next_state <= FINISHED;
                else
                    next_state <= STATE2;
                end if;

            when STATE2 =>
                sig_state <= '1';
                -- Use word 1 in STATE2
                -- Shift B here so word 0 (next iteration) is ready when we enter next STATE1
                shift_b <= '1';
                activate_beta <= '0';
                
                -- Keep sticky activations
                activate_alpha1 <= '1';
                if outer_iteration_counter >= 1 then
                    activate_alpha2 <= '1';
                    activate_gamma2 <= '1';
                end if;
                if outer_iteration_counter >= 2 then
                    activate_alpha3 <= '1';
                    activate_gamma3 <= '1';
                end if;
                
                next_state <= STATE3;

            when STATE3 =>
                sig_state <= '1';
                -- Use word 2 in STATE3
                -- Shift BOTH A and B here so new words are ready for next iteration
                shift_b <= '1';
                shift_a <= '1';
                activate_gamma1 <= '1';
                
                -- Keep sticky activations
                activate_alpha1 <= '1';
                if outer_iteration_counter >= 1 then
                    activate_alpha2 <= '1';
                    activate_gamma2 <= '1';
                end if;
                if outer_iteration_counter >= 2 then
                    activate_alpha3 <= '1';
                    activate_gamma3 <= '1';
                end if;
                
                if outer_iteration_counter >= 2 then
                    activate_alpha_final <= '1';
                end if;
                
                next_state <= STATE1;

            when FINISHED =>
                done <= '1';
                if enable = '0' then
                    next_state <= IDLE;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process comb_proc;

    -- Synchronous process: update state and counters on clock edge with active-high reset
    seq_proc : process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            outer_iteration_counter <= (others => '0');
            last_outer_loop_state_reg <= (others => '0');
        elsif rising_edge(clk) then
            state <= next_state;
            
            -- Update counters based on state
            if state = IDLE then
                outer_iteration_counter <= (others => '0');
                last_outer_loop_state_reg <= (others => '0');
            elsif state = STATE3 then
                outer_iteration_counter <= outer_iteration_counter + 1;
                if outer_iteration_counter > 6 then
                    last_outer_loop_state_reg <= last_outer_loop_state_reg + 1;
                end if;
            elsif state = STATE2 then
                if outer_iteration_counter > 6 then
                    last_outer_loop_state_reg <= last_outer_loop_state_reg + 1;
                end if;
            elsif state = STATE1 then
                if outer_iteration_counter > 7 then
                    last_outer_loop_state_reg <= last_outer_loop_state_reg + 1;
                end if;
            end if;
        end if;
    end process seq_proc;
end Behavioral;