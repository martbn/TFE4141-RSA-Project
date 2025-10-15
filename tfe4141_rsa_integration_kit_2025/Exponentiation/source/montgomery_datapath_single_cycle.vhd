library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Montgomery multiplication core
entity montgomery_mult is
    generic (
           WIDTH : integer := 256  -- Operand width (e.g. 1024 bits for RSA)
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   -- Clock
           reset  : in  std_logic;   -- Active-high reset

           -- Control interface
           enable : in  std_logic;   -- Level-sensitive start signal
           done   : out std_logic;   -- Goes high when computation is finished (stays high until enable='0')

           A      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplicand
           B      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplier
           N      : in  std_logic_vector(WIDTH-1 downto 0);  -- Modulus (must be odd)
           S      : out std_logic_vector(WIDTH-1 downto 0)   -- Result: S = (A * B * R⁻¹) mod N
    );
end montgomery_mult;

architecture Behavioral of montgomery_mult is

    -- Core registers
    signal S_reg : std_logic_vector(WIDTH downto 0);     -- Accumulator (one bit wider than WIDTH)
    signal counter : integer range 0 to WIDTH;           -- Bit counter

    -- Input registers
    signal A_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered multiplicand
    signal B_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered multiplier
    signal N_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered modulus

    -- Intermediate signals
    signal qi : std_logic;                                -- Quotient bit for Montgomery reduction
    signal temp_sum : std_logic_vector(WIDTH+1 downto 0); -- Temporary sum including carries

    -- Simple state machine
    type state_type is (IDLE, INIT, COMPUTE, FINAL_SUB, FINISHED);
    signal state : state_type;

    -- Safely indexed copy of the active A bit
    signal a_bit : std_logic := '0';

begin
    -- Select current bit of A safely
    process(counter, A_reg)
    begin
        if counter >= 0 and counter <= WIDTH-1 then
            a_bit <= A_reg(counter);
        else
            a_bit <= '0';
        end if;
    end process;

    -- Quotient bit for the Montgomery reduction
    qi <= S_reg(0) xor (a_bit and B_reg(0));

    -- Temporary sum (S + A[i]*B + qi*N)
    temp_sum <= std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '1' and qi = '1') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg)) when (A_reg(counter) = '1' and qi = '0') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '0' and qi = '1') else
                '0' & S_reg;  -- No addition required

    -- Sequential process
    FSM_montgomery: process(clk, reset)
    begin
        if reset = '1' then
            -- Reset all registers
            S_reg <= (others => '0');
            counter <= 0;
            done <= '0';
            state <= IDLE;
            A_reg <= (others => '0');
            B_reg <= (others => '0');
            N_reg <= (others => '0');

        elsif rising_edge(clk) then
            -- Update state and datapath
            -- State machine
            case state is
                when IDLE =>
                    done <= '0';
                    if enable = '1' then
                        -- Latch operands
                        A_reg <= A;
                        B_reg <= B;
                        N_reg <= N;
                        state <= INIT;
                    end if;

                when INIT =>
                    -- Initialise accumulator and counter
                    S_reg <= (others => '0');
                    counter <= 0;
                    state <= COMPUTE;

                when COMPUTE =>
                    -- Main Montgomery loop (shift-and-add logic)
                    S_reg <= temp_sum(WIDTH+1 downto 1);  -- Divide by 2 (right shift)

                    if counter = WIDTH-1 then
                        state <= FINAL_SUB;
                    else
                        counter <= counter + 1;
                    end if;

                when FINAL_SUB =>
                    -- Final correction: subtract N if S >= N
                    if unsigned(S_reg(WIDTH-1 downto 0)) >= unsigned(N_reg) then
                        S_reg(WIDTH-1 downto 0) <= std_logic_vector(unsigned(S_reg(WIDTH-1 downto 0)) - unsigned(N_reg));
                    end if;
                    state <= FINISHED;

                when FINISHED =>
                    -- Hold result until enable is released
                    done <= '1';
                    if enable = '0' then
                        state <= IDLE;
                    end if;

                when others =>
                    -- Safety fallback
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- Output: lower WIDTH bits of the accumulator
    S <= S_reg(WIDTH-1 downto 0);

end Behavioral;