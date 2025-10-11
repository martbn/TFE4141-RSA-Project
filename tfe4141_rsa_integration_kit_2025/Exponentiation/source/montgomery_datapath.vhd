library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity montgomery_datapath is
    generic (
        C_block_size : integer := 256
    );
    port (
        clk : in std_logic;
        reset_n : in std_logic;
        
        -- Data inputs
        A : in std_logic_vector(C_block_size-1 downto 0);
        B : in std_logic_vector(C_block_size-1 downto 0);
        N : in std_logic_vector(C_block_size-1 downto 0);

        -- Control inputs
        load_A_reg : in std_logic;
        load_B_reg : in std_logic;
        load_N_reg : in std_logic;
        load_result_reg : in std_logic;
        
        -- Output
        result : out std_logic_vector(C_block_size-1 downto 0)
    );
end montgomery_datapath;

architecture Behavioral of montgomery_datapath is

    signal A_reg, B_reg, N_reg : std_logic_vector(C_block_size-1 downto 0);
    signal result_reg : std_logic_vector(C_block_size-1 downto 0);
    signal div_2_reg : std_logic_vector(C_block_size-1 downto 0);

    signal A_lsb : std_logic;
    signal Ai_B_mux : std_logic_vector(C_block_size-1 downto 0);
    signal N_mux : std_logic_vector(C_block_size-1 downto 0);

    signal AiB_res_adder : std_logic_vector(C_block_size downto 0);
    signal AiB_res_adder_reg : std_logic_vector(C_block_size downto 0);
    signal AiB_res_adder_lsb : std_logic;
    signal AiB_res_plus_N_adder : std_logic_vector(C_block_size downto 0);

begin

    A_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            A_reg <= (others => '0');
            A_lsb <= '0';
        elsif clk'event and clk = '1' then
            if load_A_reg = '1' then
                A_reg <= A;
                A_lsb <= A(0);  -- Capture LSB of new input
            else
                A_lsb <= A_reg(0);  -- Capture current LSB before shift
                A_reg <= '0' & A_reg(C_block_size-1 downto 1);
            end if;
        end if;
    end process;

    B_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            B_reg <= (others => '0');
        elsif clk'event and clk = '1' then
            if load_B_reg = '1' then
                B_reg <= B;
            else
                B_reg <= B_reg; 
            end if;
        end if;
    end process;

    N_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            N_reg <= (others => '0');
        elsif clk'event and clk = '1' then
            if load_N_reg = '1' then
                N_reg <= N;
            else
                N_reg <= N_reg; 
            end if;
        end if;
    end process;


    process(A_reg, B_reg, A_lsb)
    begin
        if A_lsb = '1' then
            Ai_B_mux <= B_reg;
        else
            Ai_B_mux <= (others => '0');
        end if;
    end process;

    process(N_reg, AiB_res_adder_lsb)
    begin
        if AiB_res_adder_lsb = '1' then
            N_mux <= N_reg;
        else
            N_mux <= (others => '0');
        end if;
    end process;

    -- First adder: registered for better timing
    add1_reg: process(clk, reset_n)
    begin
        if reset_n = '0' then
            AiB_res_adder_reg <= (others => '0');
        elsif clk'event and clk = '1' then
            AiB_res_adder_reg <= std_logic_vector(unsigned('0' & Ai_B_mux) + unsigned('0' & result_reg));
        end if;
    end process;
    
    -- Extract LSB for next stage (combinational)
    AiB_res_adder_lsb <= AiB_res_adder_reg(0);

    -- Second adder: registered for better timing
    add2_reg: process(clk, reset_n)
    begin
        if reset_n = '0' then
            AiB_res_plus_N_adder <= (others => '0');
        elsif clk'event and clk = '1' then
            AiB_res_plus_N_adder <= std_logic_vector(unsigned(AiB_res_adder_reg) + unsigned('0' & N_mux));
        end if;
    end process;

    -- Divide by 2: registered (right shift by 1)
    div2_process : process(clk, reset_n)
    begin
        if reset_n = '0' then
            div_2_reg <= (others => '0');
        elsif clk'event and clk = '1' then
            div_2_reg <= '0' & AiB_res_plus_N_adder(C_block_size downto 1);
        end if;
    end process;

    result_process : process(clk, reset_n)
    begin   
        if reset_n = '0' then
            result_reg <= (others => '0');
        elsif clk'event and clk = '1' then
            if load_result_reg = '1' then
                result_reg <= div_2_reg;
            -- Don't clear result_reg when load_result_reg is not active
            -- Keep the current value for iterative computation
            end if;
        end if;
    end process;


    result <= result_reg;



end Behavioral;


