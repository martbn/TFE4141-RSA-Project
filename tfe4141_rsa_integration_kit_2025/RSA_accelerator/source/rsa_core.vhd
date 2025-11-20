--------------------------------------------------------------------------------
-- Author       : Oystein Gjermundnes
-- Organization : Norwegian University of Science and Technology (NTNU)
--                Department of Electronic Systems
--                https://www.ntnu.edu/ies
-- Course       : TFE4141 Design of digital systems 1 (DDS1)
-- Year         : 2018-2019
-- Project      : RSA accelerator
-- License      : This is free and unencumbered software released into the
--                public domain (UNLICENSE)
--------------------------------------------------------------------------------
-- Purpose:
--   RSA encryption core template. This core currently computes
--   C = M xor key_n
--
--   Replace/change this module so that it implements the function
--   C = M**key_e mod key_n.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity rsa_core is
	generic (
		-- Users to add parameters here
		C_BLOCK_SIZE          : integer := 256;
		-- Number of parallel exponentiation cores
		Num_Cores             : integer := 7
	);
	port (
		-----------------------------------------------------------------------------
		-- Clocks and reset
		-----------------------------------------------------------------------------
		clk                    :  in std_logic;
		reset_n                :  in std_logic;

		-----------------------------------------------------------------------------
		-- Slave msgin interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgin_valid             : in std_logic;
		-- Slave ready to accept a new message
		msgin_ready             : out std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgin_data              :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		-- Indicates boundary of last packet
		msgin_last              :  in std_logic;

		-----------------------------------------------------------------------------
		-- Master msgout interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgout_valid            : out std_logic;
		-- Slave ready to accept a new message
		msgout_ready            :  in std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgout_data             : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		-- Indicates boundary of last packet
		msgout_last             : out std_logic;

		-----------------------------------------------------------------------------
		-- Interface to the register block
		-----------------------------------------------------------------------------
		key_e_d                 :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		key_n                   :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		R_squared_mod_n         :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		R_mod_n                 :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		rsa_status              : out std_logic_vector(31 downto 0)

	);
end rsa_core;

architecture rtl of rsa_core is

	-- Matrix for multiple core outputs
	type t_matrix is array (0 to Num_Cores-1) of std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal msgout_vector            : t_matrix;
	
	-- Vector signals connecting to each core
	signal valid_in_vector          : std_logic_vector(Num_Cores-1 downto 0);
	signal valid_out_vector         : std_logic_vector(Num_Cores-1 downto 0);
	signal ready_in_vector          : std_logic_vector(Num_Cores-1 downto 0);
	signal ready_out_vector         : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Internal helper signals for priority encoding
	signal ready_in_internal        : std_logic_vector(Num_Cores-1 downto 0);
	signal valid_out_internal       : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Last signal tracking per core
	signal last_in_core             : std_logic_vector(Num_Cores-1 downto 0);
	signal last_accepted            : std_logic;

begin
	-- Generate Num_Cores exponentiation cores
	Cores : for i in 0 to Num_Cores-1 generate
	begin
		i_exponentiation : entity work.exponentiation
			generic map (
				C_block_size => C_BLOCK_SIZE
			)
			port map (
				message         => msgin_data,
				key             => key_e_d,
				R_squared_mod_n => R_squared_mod_n,
				R_mod_n         => R_mod_n,
				valid_in        => valid_in_vector(i),
				ready_in        => ready_in_vector(i),
				ready_out       => ready_out_vector(i),
				valid_out       => valid_out_vector(i),
				result          => msgout_vector(i),
				modulus         => key_n,
				clk             => clk,
				reset_n         => reset_n
			);
	end generate Cores;
	
	-- Top-level ready/valid signals (OR of all cores)
	msgin_ready  <= '1' when (ready_in_vector /= (Num_Cores-1 downto 0 => '0')) else '0';
	msgout_valid <= '1' when (valid_out_vector /= (Num_Cores-1 downto 0 => '0')) else '0';
	
	-- Priority encoder: Generate internal ready_in and valid_out accumulation
	process(ready_in_vector, valid_out_vector)
	begin
		ready_in_internal(0) <= '0';
		valid_out_internal(0) <= '0';
		for i in 0 to Num_Cores-2 loop
			ready_in_internal(i+1) <= ready_in_vector(i) or ready_in_internal(i);
			valid_out_internal(i+1) <= valid_out_vector(i) or valid_out_internal(i);
		end loop;
	end process;
	
	-- Generate individual valid_in and ready_out signals
	-- Only the first ready core receives valid_in
	-- Only the first valid core receives ready_out
	process(ready_in_vector, ready_in_internal, msgin_valid, 
	        valid_out_internal, valid_out_vector, msgout_ready)
	begin
		for i in 0 to Num_Cores-1 loop
			valid_in_vector(i) <= (not ready_in_internal(i)) and ready_in_vector(i) and msgin_valid;
			ready_out_vector(i) <= (not valid_out_internal(i)) and valid_out_vector(i) and msgout_ready;
		end loop;
	end process;
	
	-- Output mux: Drive output from the active core
	process(msgout_vector, ready_out_vector)
	begin
		msgout_data <= (others => '0');
		for i in 0 to Num_Cores-1 loop
			if ready_out_vector(i) = '1' then
				msgout_data <= msgout_vector(i);
			end if;
		end loop;
	end process;
	
	-- Track which core received the last input message
	process(clk, reset_n)
		variable core_found : boolean;
	begin
		if reset_n = '0' then
			last_in_core <= (others => '0');
			last_accepted <= '0';
		elsif rising_edge(clk) then
			-- When msgin_last is accepted, mark which core got it
			if msgin_valid = '1' and msgin_last = '1' then
				core_found := false;
				-- Find which core is accepting and mark it
				for i in 0 to Num_Cores-1 loop
					if valid_in_vector(i) = '1' and ready_in_vector(i) = '1' and not core_found then
						last_in_core <= (others => '0');
						last_in_core(i) <= '1';
						last_accepted <= '1';
						core_found := true;
					end if;
				end loop;
			-- Clear the flag after the last message output completes
			elsif msgout_valid = '1' and msgout_ready = '1' and msgout_last = '1' then
				last_in_core <= (others => '0');
				last_accepted <= '0';
			end if;
		end if;
	end process;
	
	-- Generate msgout_last when the core with the last message outputs
	process(ready_out_vector, last_in_core, msgout_valid)
	begin
		msgout_last <= '0';
		if msgout_valid = '1' then
			for i in 0 to Num_Cores-1 loop
				if ready_out_vector(i) = '1' and last_in_core(i) = '1' then
					msgout_last <= '1';
				end if;
			end loop;
		end if;
	end process;

	rsa_status <= (others => '0');
end rtl;