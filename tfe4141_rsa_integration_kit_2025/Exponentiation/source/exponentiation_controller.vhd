library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation_controller is
    generic (
        C_block_size : integer := 256
    );
    port (
        clk    : in STD_LOGIC;
        reset_n : in STD_LOGIC;
        
        -- Control interface
        start  : in STD_LOGIC;
        ready_in : out STD_LOGIC;
        done   : out STD_LOGIC;
        ready_out : in STD_LOGIC;
        
        -- Input data
        message : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        key     : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        modulus : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        result  : out STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        
        -- Montgomery multiplier interface
        montgomery_enable : out STD_LOGIC;
        montgomery_done   : in STD_LOGIC;
        montgomery_A      : out STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        montgomery_B      : out STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        montgomery_N      : out STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        montgomery_S      : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        
        -- Montgomery constants
        R_mod_n : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
        R_squared_mod_n : in STD_LOGIC_VECTOR(C_block_size-1 downto 0)
    );
end exponentiation_controller;

architecture Behavioral of exponentiation_controller is
    
    -- State machine for RL Binary Method
    type state_type is (
        IDLE,
        -- Montgomery domain conversion states
        CONVERT_M_TO_MONT,      -- Convert M to Montgomery: M' = M * R^2 * R^-1 = M * R
        WAIT_M_CONV,            -- Wait for M conversion
        CONVERT_1_TO_MONT,      -- Convert 1 to Montgomery: 1' = 1 * R^2 * R^-1 = R
        WAIT_1_CONV,            -- Wait for 1 conversion
        -- RL algorithm states
        INIT_RL,                -- Initialize C := 1, P := M (in Montgomery domain)
        LOOP_CHECK,             -- Check if loop should continue
        MULT_C_P,               -- Step 2a: if ei = 1, C := C * P (mod n)
        WAIT_C_P,               -- Wait for C*P multiplication
        MULT_P_P,               -- Step 2b: P := P * P (mod n)
        WAIT_P_P,               -- Wait for P*P multiplication
        FINAL_CHECK,            -- Check if final bit (eh-1) needs processing
        FINAL_MULT,             -- Step 3: C := C * P (mod n)
        WAIT_FINAL,             -- Wait for final multiplication
        CONVERT_FROM_MONT,      -- Convert result from Montgomery domain: C_final = C' * 1 * R^-1
        WAIT_FROM_CONV,         -- Wait for final conversion
        OUTPUT_RESULT           -- Output the result
    );
    
    signal state : state_type := IDLE;
    
    -- Internal registers for RL algorithm
    signal C_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- Accumulator (in Montgomery domain)
    signal P_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- Power register (in Montgomery domain)
    signal M_mont : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- M in Montgomery domain
    signal one_mont : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- 1 in Montgomery domain (= R mod n)
    
    -- Exponent processing
    signal key_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal bit_index : integer range 0 to C_block_size-1 := 0;
    signal current_bit : STD_LOGIC;
    signal key_length : integer range 0 to C_block_size := 0;
    
begin
    
    -- Always use modulus for Montgomery operations
    montgomery_N <= modulus;
    
    -- Extract current bit from exponent
    current_bit <= key_reg(bit_index);
    
    -- Main FSM process
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            montgomery_enable <= '0';
            montgomery_A <= (others => '0');
            montgomery_B <= (others => '0');
            ready_in <= '1';
            done <= '0';
            result <= (others => '0');
            C_reg <= (others => '0');
            P_reg <= (others => '0');
            M_mont <= (others => '0');
            one_mont <= (others => '0');
            key_reg <= (others => '0');
            bit_index <= 0;
            key_length <= 0;
            
        elsif rising_edge(clk) then
            -- Default: disable Montgomery multiplier unless explicitly enabled
            montgomery_enable <= '0';
            
            case state is
                
                when IDLE =>
                    ready_in <= '1';
                    done <= '0';
                    bit_index <= 0;
                    
                    if start = '1' then
                        -- Latch inputs
                        key_reg <= key;
                        
                        -- Find the most significant bit of the key (key_length)
                        key_length <= C_block_size;
                        for i in C_block_size-1 downto 0 loop
                            if key(i) = '1' then
                                key_length <= i + 1;
                                exit;
                            end if;
                        end loop;
                        
                        ready_in <= '0';
                        state <= CONVERT_M_TO_MONT;
                    end if;
                
                -- Convert M to Montgomery domain: M' = M * R mod n = M * R^2 * R^-1 mod n
                when CONVERT_M_TO_MONT =>
                    montgomery_A <= message;
                    montgomery_B <= R_squared_mod_n;
                    montgomery_enable <= '1';
                    state <= WAIT_M_CONV;
                
                when WAIT_M_CONV =>
                    if montgomery_done = '1' then
                        M_mont <= montgomery_S;
                        state <= CONVERT_1_TO_MONT;
                    end if;
                
                -- Convert 1 to Montgomery domain: 1' = 1 * R^2 * R^-1 mod n = R mod n
                when CONVERT_1_TO_MONT =>
                    montgomery_A <= std_logic_vector(to_unsigned(1, C_block_size));
                    montgomery_B <= R_squared_mod_n;
                    montgomery_enable <= '1';
                    state <= WAIT_1_CONV;
                
                when WAIT_1_CONV =>
                    if montgomery_done = '1' then
                        one_mont <= montgomery_S;
                        state <= INIT_RL;
                    end if;
                
                -- Initialize: C := 1 (in Montgomery domain), P := M (in Montgomery domain)
                when INIT_RL =>
                    C_reg <= one_mont;  -- C = 1 in Montgomery domain
                    P_reg <= M_mont;    -- P = M in Montgomery domain
                    bit_index <= 0;
                    state <= LOOP_CHECK;
                
                -- Check if we should continue the main loop (i = 0 to h-2)
                when LOOP_CHECK =>
                    if bit_index < key_length - 1 then
                        -- Check if current bit ei is 1
                        if current_bit = '1' then
                            state <= MULT_C_P;
                        else
                            -- Skip step 2a, go directly to step 2b
                            state <= MULT_P_P;
                        end if;
                    else
                        -- Loop complete, check final bit
                        state <= FINAL_CHECK;
                    end if;
                
                -- Step 2a: C := C * P (mod n)
                when MULT_C_P =>
                    montgomery_A <= C_reg;
                    montgomery_B <= P_reg;
                    montgomery_enable <= '1';
                    state <= WAIT_C_P;
                
                when WAIT_C_P =>
                    if montgomery_done = '1' then
                        C_reg <= montgomery_S;
                        state <= MULT_P_P;
                    end if;
                
                -- Step 2b: P := P * P (mod n) - squaring
                when MULT_P_P =>
                    montgomery_A <= P_reg;
                    montgomery_B <= P_reg;
                    montgomery_enable <= '1';
                    state <= WAIT_P_P;
                
                when WAIT_P_P =>
                    if montgomery_done = '1' then
                        P_reg <= montgomery_S;
                        bit_index <= bit_index + 1;
                        state <= LOOP_CHECK;
                    end if;
                
                -- Step 3: Check if final bit eh-1 = 1
                when FINAL_CHECK =>
                    if key_length > 0 and key_reg(key_length - 1) = '1' then
                        state <= FINAL_MULT;
                    else
                        -- Skip final multiplication
                        state <= CONVERT_FROM_MONT;
                    end if;
                
                -- Step 3: C := C * P (mod n)
                when FINAL_MULT =>
                    montgomery_A <= C_reg;
                    montgomery_B <= P_reg;
                    montgomery_enable <= '1';
                    state <= WAIT_FINAL;
                
                when WAIT_FINAL =>
                    if montgomery_done = '1' then
                        C_reg <= montgomery_S;
                        state <= CONVERT_FROM_MONT;
                    end if;
                
                -- Convert result from Montgomery domain: result = C' * 1 * R^-1 mod n
                when CONVERT_FROM_MONT =>
                    montgomery_A <= C_reg;
                    montgomery_B <= std_logic_vector(to_unsigned(1, C_block_size));
                    montgomery_enable <= '1';
                    state <= WAIT_FROM_CONV;
                
                when WAIT_FROM_CONV =>
                    if montgomery_done = '1' then
                        result <= montgomery_S;
                        done <= '1';
                        state <= OUTPUT_RESULT;
                    end if;
                
                -- Output the final result
                when OUTPUT_RESULT =>
                    done <= '1';
                    if ready_out = '1' then
                        state <= IDLE;
                    end if;
                
                when others =>
                    state <= IDLE;
                    
            end case;
        end if;
    end process;
    
end Behavioral;
