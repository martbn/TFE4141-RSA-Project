library ieee;
use ieee.std_logic_1164.all;

entity exponentiation is
	generic (
		C_block_size : integer := 256
	);
	port (
		--input controll
		valid_in	      : in STD_LOGIC;
		ready_in	      : out STD_LOGIC;

		--input data
		message 	      : in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		key 		      : in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

		--output control
		ready_out	      : in STD_LOGIC;
		valid_out	      : out STD_LOGIC;

		--output data
		result 		      : out STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--modulus
		modulus 	      : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
		
		-- Montgomery R constants
		R_mod_n           : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);
		R_squared_mod_n   : in STD_LOGIC_VECTOR(C_block_size-1 downto 0);


		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end exponentiation;

architecture Structural of exponentiation is
	-- Montgomery multiplication signals
	signal  A : STD_LOGIC_VECTOR (C_block_size-1 downto 0);
	signal  B : STD_LOGIC_VECTOR (C_block_size-1 downto 0);
	signal  N : STD_LOGIC_VECTOR (C_block_size-1 downto 0);
	signal  S : STD_LOGIC_VECTOR (C_block_size-1 downto 0);
	-- internal reset (montgomery expects active-high reset)
	signal  reset : std_logic;
	signal  enable_mult : STD_LOGIC;
	signal  done_mult : STD_LOGIC;

begin
	
	-- Instantiate Exponentiation Controller
	controller_inst : entity work.exponentiation_controller
	generic map (
		C_block_size => C_block_size
	)
	port map (
		clk    => clk,
		reset_n => reset_n,
		start  => valid_in,
		ready_in => ready_in,
		done   => valid_out,
		ready_out => ready_out,
		message => message,
		key     => key,
		modulus => modulus,
		result  => result,
		montgomery_enable => enable_mult,
		montgomery_done   => done_mult,
		montgomery_A      => A,
		montgomery_B      => B,
		montgomery_N      => N,
		montgomery_S      => S,
		R_mod_n => R_mod_n,
		R_squared_mod_n => R_squared_mod_n
	);

	-- Instantiate Montgomery Multiplier
	-- tie internal reset (montgomery expects active-high reset)
	reset <= not reset_n;

	montgomery_inst : entity work.montgomery
	generic map (
		WIDTH => C_block_size
	)
	port map (
		clk    => clk,
		reset  => reset,
		enable => enable_mult,
		done   => done_mult,
		A      => A,
		B      => B,
		N      => N,
		S      => S
	);

end Structural;				
