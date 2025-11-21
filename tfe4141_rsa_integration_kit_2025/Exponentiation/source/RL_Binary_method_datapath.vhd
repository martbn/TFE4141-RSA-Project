library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RL_Binary_method_datapath is
    generic (C_block_size : integer := 256);
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;

        -- inputs
        message_in        : in  std_logic_vector(C_block_size-1 downto 0);
        modulus_in        : in  std_logic_vector(C_block_size-1 downto 0);
        R_squared_mod_n_in: in  std_logic_vector(C_block_size-1 downto 0);

        -- control
        load_init   : in std_logic; -- load C<=R^2, P<=message
        sel_A       : in std_logic_vector(2 downto 0); -- 000=C,001=P,010=R2,011=message,100=const1
        sel_B       : in std_logic_vector(2 downto 0);
        
        mont_done   : in std_logic; 

        -- montgomery datapath connections
        mont_A      : out std_logic_vector(C_block_size-1 downto 0);
        mont_B      : out std_logic_vector(C_block_size-1 downto 0);
        mont_N      : out std_logic_vector(C_block_size-1 downto 0);
        mont_S      : in  std_logic_vector(C_block_size-1 downto 0);

        -- outputs
        C_out       : out std_logic_vector(C_block_size-1 downto 0);
        P_out       : out std_logic_vector(C_block_size-1 downto 0);
        result_out  : out std_logic_vector(C_block_size-1 downto 0)
    );
end RL_Binary_method_datapath;

architecture RTL of RL_Binary_method_datapath is
    signal C_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal P_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal result_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    constant ONE_VEC : std_logic_vector(C_block_size-1 downto 0) := std_logic_vector(to_unsigned(1, C_block_size));
begin

    -- combinational: drive montgomery operands from selected sources
    process(C_reg, P_reg, R_squared_mod_n_in, message_in, sel_A)
    begin
        case sel_A is
            when "000" => mont_A <= C_reg;
            when "001" => mont_A <= P_reg;
            when "010" => mont_A <= R_squared_mod_n_in;
            when "011" => mont_A <= message_in;
            when "100" => mont_A <= ONE_VEC;
            when others => mont_A <= (others => '0');
        end case;
    end process;

    process(C_reg, P_reg, R_squared_mod_n_in, message_in, sel_B)
    begin
        case sel_B is
            when "000" => mont_B <= C_reg;
            when "001" => mont_B <= P_reg;
            when "010" => mont_B <= R_squared_mod_n_in;
            when "011" => mont_B <= message_in;
            when "100" => mont_B <= ONE_VEC;
            when others => mont_B <= (others => '0');
        end case;
    end process;

    mont_N <= modulus_in;

    -- sequential: load initial values and capture montgomery result when done
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            C_reg <= (others => '0');
            P_reg <= (others => '0');
            result_reg <= (others => '0');
        elsif rising_edge(clk) then
            -- load initial values (synchronous)
            if load_init = '1' then
                C_reg <= R_squared_mod_n_in; -- will be converted to Mont(1) by controller if needed
                P_reg <= message_in;
            end if;

            -- capture montgomery result on mont_done according to capture_to
            if mont_done = '1' then
                if capture_to = "01" then
                    C_reg <= mont_S;
                elsif capture_to = "10" then
                    P_reg <= mont_S;
                elsif capture_to = "11" then
                    result_reg <= mont_S;
                end if;
            end if;
        end if;
    end process;

    C_out <= C_reg;
    P_out <= P_reg;
    result_out <= result_reg;

end RTL;
