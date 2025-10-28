library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_mult_datapath is
    generic (
           WIDTH : integer := 256  
    );
    port (
           -- Clock and reset
           clk    : in  std_logic;   
           reset  : in  std_logic;   

           -- Control strobes (driven by controller)
           load_registers : in std_logic;
           shift_registers : in std_logic;
           compute_AiB : in std_logic;  
           compute_S   : in std_logic;
          finalize     : in std_logic;

           -- Control interface
     -- Goes high when computation is finished (stays high until enable='0')

           A      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplicand
           B      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplier
           N      : in  std_logic_vector(WIDTH-1 downto 0);  -- Modulus (must be odd)
           S      : out std_logic_vector(WIDTH-1 downto 0)  -- Result: S = (A * B * R⁻¹) mod N
    );
end montgomery_mult_datapath;

architecture Behavioral of montgomery_mult_datapath is
    -- Registers and pipeline signals
    -- S_reg needs one extra bit to hold AiB_reg + N without overflow
    signal S_reg : std_logic_vector(WIDTH+1 downto 0);
    -- res_reg also needs one extra bit to hold the shifted result
    signal res_reg : std_logic_vector(WIDTH downto 0);  -- accumulator (WIDTH+1 bits)
    signal A_reg : std_logic_vector(WIDTH-1 downto 0);
    signal B_reg : std_logic_vector(WIDTH-1 downto 0);
    signal N_reg : std_logic_vector(WIDTH-1 downto 0);

    -- Intermediate signals
    signal AiB_input : std_logic_vector(WIDTH downto 0);
    signal AiB_comb  : std_logic_vector(WIDTH+1 downto 0);
    signal AiB_reg   : std_logic_vector(WIDTH+1 downto 0);
    signal qi_reg    : std_logic := '0';
    signal N_mux     : std_logic_vector(WIDTH downto 0);
    signal a_lsb : std_logic := '0';

begin
    a_lsb <= A_reg(0);
    AiB_input <= ('0' & B_reg) when a_lsb = '1' else (others => '0');
    -- Compute full WIDTH+2-bit sum from res_reg and AiB_input (avoid accidental MSB truncation)
    AiB_comb <= std_logic_vector(resize(unsigned(res_reg), WIDTH+2) + resize(unsigned(AiB_input), WIDTH+2));

    N_mux <= ('0' & N_reg) when qi_reg = '1' else (others => '0');

    
    ResShift_proc : process(clk, reset)
        -- temporary unsigned variables for final subtraction
        variable r_u  : unsigned(WIDTH downto 0);
        variable n_ext: unsigned(WIDTH downto 0);
    begin
        if reset = '1' then
            A_reg <= (others => '0');
            B_reg <= (others => '0');
            N_reg <= (others => '0');
            res_reg <= (others => '0');
           
        elsif rising_edge(clk) then
            if load_registers = '1' then
                A_reg <= A;
                B_reg <= B;
                N_reg <= N;
                res_reg <= (others => '0');

            elsif finalize = '1' then
                -- Final conditional subtraction: if res_reg >= N then res_reg := res_reg - N
                -- Work in unsigned arithmetic with matching widths (WIDTH+1 bits)
                r_u := unsigned(res_reg);
                n_ext := unsigned('0' & N_reg);
                if r_u >= n_ext then
                    res_reg <= std_logic_vector(r_u - n_ext);
                else
                    -- keep res_reg unchanged (no action)
                    null;
                end if;

            elsif shift_registers = '1' then
                -- shift right by one: take bits [WIDTH+1 downto 1] -> WIDTH+1 bits into res_reg
                res_reg <= S_reg(WIDTH+1 downto 1);
                A_reg <= '0' & A_reg(WIDTH-1 downto 1);
               
            end if;
        end if;
    end process ResShift_proc;

    -- Cycle 1: register AiB_comb and its LSB into AiB_reg and qi_reg when compute_AiB asserted
    AiB_reg_proc : process(clk, reset)
    begin
        if reset = '1' then
            AiB_reg <= (others => '0');
            qi_reg <= '0';
        elsif rising_edge(clk) then
            if load_registers = '1' then
                AiB_reg <= (others => '0');
                qi_reg <= '0';
            elsif compute_AiB = '1' then
                AiB_reg <= AiB_comb;
                qi_reg <= AiB_comb(0);
            end if;
        end if;
    end process AiB_reg_proc;

    -- Cycle 2: compute S_reg = AiB_reg + (qi_reg ? N : 0) when compute_S asserted
    S_compute_proc : process(clk, reset)
        -- need one extra bit to hold AiB_reg + N without overflow
        variable sum2 : unsigned(WIDTH+1 downto 0);
    begin
        if reset = '1' then
            S_reg <= (others => '0');
        elsif rising_edge(clk) then
            if load_registers = '1' then
                S_reg <= (others => '0');
            elsif compute_S = '1' then
                if qi_reg = '0' then
                    -- place AiB_reg into S_reg
                    S_reg <= AiB_reg;
                else
                    -- sum = AiB_reg + N (both WIDTH+1 bits) -> requires WIDTH+2 bits
                    sum2 := resize(unsigned(AiB_reg), WIDTH+2) + resize(unsigned('0' & N_reg), WIDTH+2);
                    S_reg <= std_logic_vector(sum2);
                end if;
            end if;
        end if;
    end process S_compute_proc;

    S <= res_reg(WIDTH-1 downto 0);
end Behavioral;
