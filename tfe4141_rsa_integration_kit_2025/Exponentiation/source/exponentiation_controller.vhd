library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation_controller is
    generic (
        C_block_size : integer := 256
    );
    port (
        -- Clock and reset
        clk    : in  std_logic;
        reset_n : in  std_logic;

        -- Control signals for exponentiation datapath (ready/valid)
        start         : in  std_logic;  -- master -> valid
        ready_in      : out std_logic;  -- controller signals ready to accept input
        done          : out std_logic;  -- controller -> valid (result available)
        ready_out     : in  std_logic;  -- consumer -> ready to accept result

        -- Signals for exponentiation
        message          : in  std_logic_vector(C_block_size-1 downto 0);
        key              : in  std_logic_vector(C_block_size-1 downto 0);
        modulus          : in  std_logic_vector(C_block_size-1 downto 0);
        R_squared_mod_n  : in  std_logic_vector(C_block_size-1 downto 0);
        result           : out std_logic_vector(C_block_size-1 downto 0);

        -- Control signals for Montgomery multiplier
        montgomery_enable : out std_logic;
        montgomery_done   : in  std_logic;

        -- Signals for montgomery multiplier
        montgomery_A      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_B      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_N      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_S      : in  std_logic_vector(C_block_size-1 downto 0)
    );
end exponentiation_controller;

architecture RTL of exponentiation_controller is
    type   state_type is (IDLE, CONV_2_MONT, SQUARE, MULTIPLY, PROCESS_BIT, CONV_2_NORMAL, FINISHED);
    signal current_state : state_type := IDLE;

    signal reg_c : std_logic_vector(C_block_size-1 downto 0);
    signal reg_m : std_logic_vector(C_block_size-1 downto 0);
    signal bit_index : integer range 0 to C_block_size-1 := C_block_size-1;
begin
    process(clk, reset_n)
        variable found_msb : integer := -1;
    begin
        if reset_n = '0' then
            current_state <= IDLE;
            ready_in <= '0';
            done <= '0';
            montgomery_enable <= '0';
            montgomery_A <= (others => '0');
            montgomery_B <= (others => '0');
            reg_m <= (others => '0');
            reg_c <= (others => '0');
            montgomery_N <= modulus;
            bit_index <= C_block_size-1;
            result <= (others => '0');
        elsif rising_edge(clk) then
            -- Default values
            montgomery_enable <= '0';
            montgomery_N <= modulus;
            done <= '0';

            case current_state is
                when IDLE =>
                    ready_in <= '1';
                    if start = '1' then
                        bit_index <= C_block_size - 1;
                        ready_in <= '0';
                        -- Load inputs for conversion to Montgomery form
                        montgomery_A <= message;
                        montgomery_B <= R_squared_mod_n;
                        montgomery_N <= modulus;
                        montgomery_enable <= '1';
                        current_state <= CONV_2_MONT;
                    end if;

                when CONV_2_MONT =>
                    -- Find most significant bit of the key
                    found_msb := -1;
                    for i in C_block_size-1 downto 0 loop
                        if key(i) = '1' then
                            found_msb := i;
                            exit;
                        end if;
                    end loop;
                    if found_msb /= -1 then
                        bit_index <= found_msb;  -- single scheduled assignment
                    end if;

                    if montgomery_done = '1' then
                        reg_m <= montgomery_S;
                        reg_c <= montgomery_S;
                        montgomery_enable <= '1';
                        bit_index <= bit_index - 1;

                        -- Setup squaring of initial value
                        montgomery_A <= montgomery_S;
                        montgomery_B <= montgomery_S;
                        montgomery_enable <= '1';
                        current_state <= SQUARE;
                    end if;
                when PROCESS_BIT =>
                    if bit_index < 0 then
                        -- All bits processed, convert back to normal form
                        montgomery_A <= reg_c;
                        montgomery_B <= std_logic_vector(to_unsigned(1, montgomery_B'length)); -- montgomery representation of 1
                        montgomery_enable <= '1';
                        current_state <= CONV_2_NORMAL;
                    else
                        -- Setup squaring
                        montgomery_A <= reg_c;
                        montgomery_B <= reg_c;
                        montgomery_enable <= '1';
                        current_state <= SQUARE;
                    end if;
                    
                when MULTIPLY =>
                    if montgomery_done = '1' then
                        reg_c <= montgomery_S;
                        current_state <= PROCESS_BIT;
                    end if;
                when SQUARE =>
                    if montgomery_done = '1' then
                        -- Update reg_c with result of squaring
                        reg_c <= montgomery_S;

                        -- Process next bit
                        bit_index <= bit_index - 1;
                        if key(bit_index) = '1' then
                            -- Multiply step
                            montgomery_A <= montgomery_S;
                            montgomery_B <= reg_m;
                            montgomery_enable <= '1';
                            current_state <= MULTIPLY;
                        else
                            montgomery_A <= montgomery_S;
                            montgomery_B <= montgomery_S;
                            montgomery_enable <= '1';
                        end if;
                    end if;
                when CONV_2_NORMAL =>
                    if montgomery_done = '1' then
                        result <= montgomery_S;
                        done <= '1';
                        current_state <= FINISHED;
                    end if;
                when FINISHED =>
                    if ready_out = '1' then
                        done <= '0';
                        current_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
                    
end RTL;  -- This remains unchanged