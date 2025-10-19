Library UNISIM;
use UNISIM.vcomponents.all;
library UNIMACRO;
use UNIMACRO.Vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simple wrapper that implements a N-word memory of 256-bit words
-- Implemented with 4 instances of BRAM_SINGLE_MACRO (72-bit wide each)
entity memory is
	generic (
		DATA_WIDTH : integer := 256;
		WINDOW_SIZE : integer := 4
	);
	port (
		clk  : in  std_logic;
		en   : in  std_logic;
		we   : in  std_logic; -- write enable
		addr : in  std_logic_vector(WINDOW_SIZE-1 downto 0);
		din  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
		dout : out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
end memory;

architecture rtl of memory is
	constant BRAM_WIDTH  : integer := 72;
	constant BRAM_BANKS  : integer := 4; -- 4 banks of 72 -> 288 bits
	constant TOTAL_WIDTH : integer := BRAM_WIDTH * BRAM_BANKS;
	constant NUM_WORDS   : integer := 2**WINDOW_SIZE-1;
	-- internal busses sized to TOTAL_WIDTH (288)
	signal DI_bus : std_logic_vector(TOTAL_WIDTH-1 downto 0);
	signal DO_bus : std_logic_vector(TOTAL_WIDTH-1 downto 0);

	-- BRAM expects a wider address (for 72-bit width on 36Kb BRAM address is 9 bits)
	signal ADDR_ext : std_logic_vector(8 downto 0);
	signal WE_vec  : std_logic_vector(7 downto 0);
begin

	-- extend the user address to the BRAM address width; upper bits are zeros
	ADDR_ext <= std_logic_vector(resize(unsigned(addr), 9));
	

	-- expand single-bit write enable to the BRAM byte-enable width (8 bits for 72-bit mode)
	WE_vec <= (others => '1') when we = '1' else (others => '0');

	-- pack the user data into DI_bus (lower DATA_WIDTH bits valid, rest zero)
	DI_bus <= std_logic_vector(resize(unsigned(din), TOTAL_WIDTH));

	-- Concatenate DO outputs, then present the lower DATA_WIDTH bits as dout
	dout <= DO_bus(DATA_WIDTH-1 downto 0);

	-- Instantiate 4 BRAM_SINGLE_MACRO primitives. Each handles 72 bits.
	BRAM0 : BRAM_SINGLE_MACRO
	generic map (
		BRAM_SIZE => "36Kb",
		DEVICE => "7SERIES",
		DO_REG => 0,
		WRITE_WIDTH => BRAM_WIDTH,
		READ_WIDTH  => BRAM_WIDTH,
		WRITE_MODE => "NO_CHANGE"
	)
	port map (
		DO => DO_bus(71 downto 0),
		ADDR => ADDR_ext,
		CLK => clk,
		DI  => DI_bus(71 downto 0),
		EN  => en,
		REGCE => '0',
		RST  => '0',
		WE   => WE_vec
	);

	BRAM1 : BRAM_SINGLE_MACRO
	generic map (
		BRAM_SIZE => "36Kb",
		DEVICE => "7SERIES",
		DO_REG => 0,
		WRITE_WIDTH => BRAM_WIDTH,
		READ_WIDTH  => BRAM_WIDTH,
		WRITE_MODE => "NO_CHANGE"
	)
	port map (
		DO => DO_bus(143 downto 72),
		ADDR => ADDR_ext,
		CLK => clk,
		DI  => DI_bus(143 downto 72),
		EN  => en,
		REGCE => '0',
		RST  => '0',
		WE   => WE_vec
	);

	BRAM2 : BRAM_SINGLE_MACRO
	generic map (
		BRAM_SIZE => "36Kb",
		DEVICE => "7SERIES",
		DO_REG => 0,
		WRITE_WIDTH => BRAM_WIDTH,
		READ_WIDTH  => BRAM_WIDTH,
		WRITE_MODE => "NO_CHANGE"
	)
	port map (
		DO => DO_bus(215 downto 144),
		ADDR => ADDR_ext,
		CLK => clk,
		DI  => DI_bus(215 downto 144),
		EN  => en,
		REGCE => '0',
		RST  => '0',
		WE   => WE_vec
	);

	BRAM3 : BRAM_SINGLE_MACRO
	generic map (
		BRAM_SIZE => "36Kb",
		DEVICE => "7SERIES",
		DO_REG => 0,
		WRITE_WIDTH => BRAM_WIDTH,
		READ_WIDTH  => BRAM_WIDTH,
		WRITE_MODE => "NO_CHANGE"
	)
	port map (
		DO => DO_bus(287 downto 216),
		ADDR => ADDR_ext,
		CLK => clk,
		DI  => DI_bus(287 downto 216),
		EN  => en,
		REGCE => '0',
		RST  => '0',
		WE   => WE_vec
	);

end rtl;


