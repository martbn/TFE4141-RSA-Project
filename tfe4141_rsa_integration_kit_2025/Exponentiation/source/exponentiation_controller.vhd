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
    
    function calc_bit_length(key_val : STD_LOGIC_VECTOR) return integer is
    begin
        for i in key_val'high downto key_val'low loop
            if key_val(i) = '1' then
                return i + 1;
            end if;
        end loop;
        return 1; 
    end function;
    
    -- State machine RL Binary Method
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
    
    -- Input registers, latch message and key when accepted
    signal message_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    signal key_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    
    -- Output register, holds result until next computation completes
    signal result_reg : STD_LOGIC_VECTOR(C_block_size-1 downto 0);
    
    -- Exponent processing
    signal bit_index : unsigned(8 downto 0) := (others => '0');  -- 0-255
    signal key_length : unsigned(8 downto 0) := (others => '0'); -- 0-256
    
    -- Area optimization attributes
    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of message_reg : signal is "no";
    attribute SHREG_EXTRACT of key_reg : signal is "no";
    attribute SHREG_EXTRACT of C_reg : signal is "no";
    attribute SHREG_EXTRACT of P_reg : signal is "no";
    
begin
    
    montgomery_N <= modulus;
    result <= result_reg;
    
    -- FSM
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
            bit_index <= (others => '0');
            key_length <= (others => '0');
            
        elsif rising_edge(clk) then
            
            case state is
                
                when IDLE =>
                    montgomery_enable <= '0';
                    done <= '0';
                    bit_index <= (others => '0');
                    
                    if start = '1' and ready_in = '1' then
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
                    key_length <= to_unsigned(calc_bit_length(key_reg), 9);
                    state <= CONVERT_M_TO_MONT;
                
                when CONVERT_M_TO_MONT =>
                    montgomery_A <= message_reg;  
                    montgomery_B <= R_squared_mod_n;
                    montgomery_enable <= '1';
                    state <= WAIT_M_CONV;
                
                when WAIT_M_CONV =>
                    montgomery_enable <= '1'; 
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        M_mont <= montgomery_S;
                        state <= CONVERT_1_TO_MONT;
                    end if;
                
                when CONVERT_1_TO_MONT =>
                    montgomery_A <= std_logic_vector(to_unsigned(1, C_block_size));
                    montgomery_B <= R_squared_mod_n;
                    montgomery_enable <= '1';
                    state <= WAIT_1_CONV;
                
                when WAIT_1_CONV =>
                    montgomery_enable <= '1'; 
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
                    bit_index <= (others => '0');
                    state <= LOOP_CHECK;
                
                when LOOP_CHECK =>
                    montgomery_enable <= '0';
                    if bit_index < key_length then
                        if key_reg(to_integer(bit_index)) = '1' then
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
                    montgomery_enable <= '1'; 
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        C_reg <= montgomery_S;
                        state <= MULT_P_P;
                    end if;
                
                -- Step 2b: P := P * P (mod n)
                when MULT_P_P =>
                    montgomery_A <= P_reg;
                    montgomery_B <= P_reg;
                    montgomery_enable <= '1';
                    state <= WAIT_P_P;
                
                when WAIT_P_P =>
                    montgomery_enable <= '1'; 
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
                    montgomery_enable <= '1';  
                    if montgomery_done = '1' then
                        montgomery_enable <= '0';
                        result_reg <= montgomery_S;  
                        done <= '1';
                        state <= OUTPUT_RESULT;
                    end if;
                
                when OUTPUT_RESULT =>
                    montgomery_enable <= '0';
                    if ready_out = '1' then
                        done <= '0';  
                        state <= DONE_STATE;
                    end if;
                
                -- Cleanup state: ensure clean transition back to IDLE
                when DONE_STATE =>
                    montgomery_enable <= '0';
                    done <= '0';  
                    ready_in <= '1';  
                    -- Only clear bit_index (other registers cleared on next start)
                    bit_index <= (others => '0');
                    state <= IDLE; 
                
                when others =>
                    state <= IDLE;
                    
            end case;
        end if;
    end process;
    
end Behavioral;
