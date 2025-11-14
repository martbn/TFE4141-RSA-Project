library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery is
    generic (
           WIDTH : integer := 256  -- Operand width (e.g. 256 bits for RSA)
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
           S      : out std_logic_vector(WIDTH-1 downto 0)   -- Result: S = (A * B * R^(-1)) mod N
        
    );
end montgomery;

architecture behavioral of montgomery is

    signal load_registers : std_logic := '0';
    signal shift_registers : std_logic := '0';
    signal compute_AiB : std_logic := '0';
    signal compute_S   : std_logic := '0';
    signal finalize : std_logic := '0';

begin

    -- Instantiate controller
    u_controller: entity work.montgomery_mult_controller
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk    => clk,
            reset  => reset,
            load_registers => load_registers,
            shift_registers => shift_registers,
            compute_AiB => compute_AiB,
            compute_S => compute_S,
            finalize => finalize,
            enable => enable,
            done   => done,
            state_out => open,
            counter_out => open
        );

    -- Instantiate datapath
    u_datapath: entity work.montgomery_mult_datapath
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk    => clk,
            reset  => reset,
            load_registers => load_registers,
            shift_registers => shift_registers,
            compute_AiB => compute_AiB,
            compute_S   => compute_S,
            finalize      => finalize,
            A      => A,
            B      => B,
            N      => N,
            S      => S
        );

end behavioral;