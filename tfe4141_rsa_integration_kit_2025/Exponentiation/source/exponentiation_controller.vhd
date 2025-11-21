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
    
    -- Function to calculate the bit length of a key (MSB position + 1)
    -- This is purely combinational and synthesizes to a priority encoder
    function calc_bit_length(key_val : STD_LOGIC_VECTOR) return integer is
    begin
        for i in key_val'high downto key_val'low loop
            if key_val(i) = '1' then
                return i + 1;
            end if;
        end loop;
        return 1; -- Minimum length
    end function;
    
    -- State machine for RL Binary Method
    type state_type is (
        IDLE,
        LATCH_INPUTS,           -- Latch inputs and calculate key length
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
        CONVERT_FROM_MONT,      -- Convert result from Montgomery domain: C_final = C' * 1 * R^-1
        WAIT_FROM_CONV,         -- Wait for final conversion
        OUTPUT_RESULT,          -- Output the result
        DONE_STATE              -- Cleanup state before returning to IDLE
    );
    attribute ENUM_ENCODING : string;
    attribute ENUM_ENCODING of state_type : type is "sequential";
    
    signal state : state_type := IDLE;
    
    -- Internal registers for RL algorithm
    signal C_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- Accumulator (in Montgomery domain)
    signal P_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- Power register (in Montgomery domain)
    signal M_mont : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- M in Montgomery domain
    signal one_mont : STD_LOGIC_VECTOR(C_block_size-1 downto 0); -- 1 in Montgomery domain (= R mod n)
    
    -- Input registers - latch message and key when accepted
    signal message_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal key_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    
    -- Output register - holds result until next computation completes
    signal result_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    
    -- Exponent processing
    signal bit_index : integer range 0 to C_block_size-1 := 0;
    signal key_length : integer range 0 to C_block_size := 0;
    
begin
    
    -- Always use modulus directly (it's stable from AXI registers)
    montgomery_N <= modulus;
    
    -- Output result directly from computation for debugging
    result <= result_reg;
    
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
            result_reg <= (others => '0');
            C_reg <= (others => '0');
            P_reg <= (others => '0');
            M_mont <= (others => '0');
            one_mont <= (others => '0');
            message_reg <= (others => '0');
            key_reg <= (others => '0');
            bit_index <= 0;
            key_length <= 0;
            
        elsif rising_edge(clk) then
            
            case state is
                
                when IDLE =>
                    montgomery_enable <= '0';
                    done <= '0';
                    bit_index <= 0;
                    
                    if start = '1' and ready_in = '1' then
                        -- Latch message and key when handshake occurs
                        message_reg <= message;
                        key_reg <= key;
                        ready_in <= '0';
                        state <= LATCH_INPUTS;
                    else
                        ready_in <= '1';
                    end if;
                
                -- Calculate key length from latched key_reg
                when LATCH_INPUTS =>
                    montgomery_enable <= '0';
                    -- Calculate bit length using function (combinational)
                    key_length <= calc_bit_length(key_reg);
                    state <= CONVERT_M_TO_MONT;
                
                -- Convert M to Montgomery domain: M' = M * R mod n = M * R^2 * R^-1 mod n
                when CONVERT_M_TO_MONT =>
                    montgomery_A <= message_reg;  -- Use latched message
                    montgomery_B <= R_squared_mod_n;
                    montgomery_enable <= '1';
                    state <= WAIT_M_CONV;
                
                when WAIT_M_CONV =>
                    montgomery_enable <= '1';  -- Keep enable HIGH until done
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
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
                    montgomery_enable <= '1';  -- Keep enable HIGH until done
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        one_mont <= montgomery_S;
                        state <= INIT_RL;
                    end if;
                
                -- Initialize: C := 1 (in Montgomery domain), P := M (in Montgomery domain)
                when INIT_RL =>
                    montgomery_enable <= '0';
                    C_reg <= one_mont;  -- C = 1 in Montgomery domain
                    P_reg <= M_mont;    -- P = M in Montgomery domain
                    bit_index <= 0;
                    state <= LOOP_CHECK;
                
                        -- Check if we should continue the main loop (i = 0 to h-1)
                when LOOP_CHECK =>
                    montgomery_enable <= '0';
                    if bit_index < key_length then
                        -- Sample current bit and check if ei is 1
                        if key_reg(bit_index) = '1' then
                            state <= MULT_C_P;
                        else
                            -- Skip C*P multiplication, go directly to P*P squaring
                            state <= MULT_P_P;
                        end if;
                    else
                        -- All bits processed, convert result back from Montgomery domain
                        state <= CONVERT_FROM_MONT;
                    end if;
                
                -- Step 2a: C := C * P (mod n)
                when MULT_C_P =>
                    montgomery_A <= C_reg;
                    montgomery_B <= P_reg;
                    montgomery_enable <= '1';
                    state <= WAIT_C_P;
                
                when WAIT_C_P =>
                    montgomery_enable <= '1';  -- Keep enable HIGH until done
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
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
                    montgomery_enable <= '1';  -- Keep enable HIGH until done
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        P_reg <= montgomery_S;
                        bit_index <= bit_index + 1;
                        state <= LOOP_CHECK;
                    end if;
                
                -- Convert result from Montgomery domain: result = C' * 1 * R^-1 mod n
                when CONVERT_FROM_MONT =>
                    montgomery_A <= C_reg;
                    montgomery_B <= std_logic_vector(to_unsigned(1, C_block_size));
                    montgomery_enable <= '1';
                    state <= WAIT_FROM_CONV;
                
                when WAIT_FROM_CONV =>
                    montgomery_enable <= '1';  -- Keep enable HIGH until done
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        result_reg <= montgomery_S;  -- Store in result register
                        done <= '1';
                        state <= OUTPUT_RESULT;
                    end if;
                
                -- Output the final result
                when OUTPUT_RESULT =>
                    montgomery_enable <= '0';
                    -- done stays HIGH (set in previous state)
                    -- Keep result stable
                    if ready_out = '1' then
                        -- Handshake complete - transition to cleanup state
                        done <= '0';  -- Clear done only when handshake completes
                        state <= DONE_STATE;
                    end if;
                
                -- Cleanup state: ensure clean transition back to IDLE
                when DONE_STATE =>
                    montgomery_enable <= '0';
                    done <= '0';  -- Keep done LOW
                    ready_in <= '1';  -- Ready for next input
                    -- Clear internal computation registers to prevent state leakage
                    C_reg <= (others => '0');
                    P_reg <= (others => '0');
                    M_mont <= (others => '0');
                    one_mont <= (others => '0');
                    bit_index <= 0;
                    state <= IDLE;  -- Go back to idle on next clock
                
                when others =>
                    state <= IDLE;
                    
            end case;
        end if;
    end process;
    
end Behavioral;
