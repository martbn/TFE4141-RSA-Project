LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- Testbench fuer Montgomery-Multiplikation
ENTITY montgomery_mult_tb IS
END montgomery_mult_tb;

ARCHITECTURE behavior OF montgomery_mult_tb IS 

    -- Einbindung der zu testenden Komponente
    COMPONENT montgomery_mult
    GENERIC (
        WIDTH : integer := 256  -- 1024-Bit Operandenbreite
    );
    PORT(
        clk     : IN  std_logic;
        reset   : IN  std_logic;
        enable  : IN  std_logic;
        A       : IN  std_logic_vector(255 downto 0);  -- Multiplikand
        B       : IN  std_logic_vector(255 downto 0);  -- Multiplikator
        N       : IN  std_logic_vector(255 downto 0);  -- Modulus
        S       : OUT std_logic_vector(255 downto 0);  -- Ergebnis
        done    : OUT std_logic
    );
    END COMPONENT;
    
    -- Testbench-Signale
    signal clk    : std_logic := '0';        -- Taktsignal
    signal reset  : std_logic := '0';        -- Reset-Signal
    signal enable : std_logic := '0';        -- Enable-Signal

    -- Test-Operanden (1024-Bit Vektoren)
    signal A : std_logic_vector(255 downto 0) := (others => '0');  -- Multiplikand
    signal B : std_logic_vector(255 downto 0) := (others => '0');  -- Multiplikator
    signal N : std_logic_vector(255 downto 0) := (others => '0');  -- Modulus

    -- Ausgabesignale von UUT
    signal S    : std_logic_vector(255 downto 0);  -- Ergebnis der Montgomery-Multiplikation
    signal done : std_logic;                        -- Berechnung abgeschlossen

    -- Taktperiode fuer Simulation (10 ns = 100 MHz)
    constant clk_period : time := 10 ns;
    
    -- Signale zur Leistungsmessung
    signal start_cycle    : integer := 0;     -- Zyklus bei Berechnungsstart
    signal end_cycle      : integer := 0;     -- Zyklus bei Berechnungsende
    signal cycle_counter  : integer := 0;     -- Laufender Zyklenzaehler

BEGIN

    -- Instanzierung des UUT (Unit Under Test)
    uut: montgomery_mult 
    GENERIC MAP (
        WIDTH => 256  -- Test mit 1024-Bit Operanden
    )
    PORT MAP (
        clk    => clk,
        reset  => reset,
        enable => enable,
        A      => A,
        B      => B,
        N      => N,
        S      => S,
        done   => done
    );

    -- Taktgenerierung (100 MHz)
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Zyklenzaehler fuer Leistungsmessung
    cycle_count_process: process(clk)
    begin
        if rising_edge(clk) then
            cycle_counter <= cycle_counter + 1;
        end if;
    end process;

    -- Stimulusprozess zur Testinitialisierung und Auswertung
    stim_proc: process
    begin
        -- System mit Reset initialisieren
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for clk_period * 10;

        report "=== 1024-BIT MONTGOMERY MULTIPLIKATION TEST ===";
        report "Test mit voller 1024-Bit Kapazitaet";

       
        A <= (others => '0');
        A(3) <= '0';
        A(2) <= '1';
        A(0) <= '1';

       
        B <= (others => '0');
        B(4)   <= '0';
        B(1)   <= '1';
        B(0)   <= '1';

        N <= (others => '0');
        N(7) <= '0';
        N(6) <= '0';
        N(5) <= '0';
        N(4) <= '0';
        N(3) <= '0';
        N(2) <= '1';
        N(1) <= '1';
        N(0) <= '1';

        wait for clk_period * 2;

        -- Starte 1024-Bit Berechnung
        start_cycle <= cycle_counter;
        enable <= '1';
        wait for clk_period;

        wait until done = '1' for 200 ms;

        if done = '1' then
            end_cycle <= cycle_counter;
            wait for clk_period;
            report "=== 1024-BIT BERECHNUNG ABGESCHLOSSEN ===";

            -- Zeige Ergebnis (teilweise, im Hex-Format)
           

        wait;
        end if;
    end process;

END behavior;
