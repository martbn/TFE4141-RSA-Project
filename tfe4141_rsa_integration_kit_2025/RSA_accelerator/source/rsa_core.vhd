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
		-- Number of cores
		Num_Cores             : integer := 12
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

	-- Arrays for core outputs
	type result_array_type is array (0 to Num_Cores-1) of std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal core_results        : result_array_type;
	signal boundary_markers    : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Core management signals
	signal trigger_core        : std_logic_vector(Num_Cores-1 downto 0);
	signal trigger_core_next   : std_logic_vector(Num_Cores-1 downto 0);
	signal acknowledge_core    : std_logic_vector(Num_Cores-1 downto 0);
	signal acknowledge_core_next : std_logic_vector(Num_Cores-1 downto 0);
	signal core_finished       : std_logic_vector(Num_Cores-1 downto 0);
	signal core_occupied       : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Circular scheduler for core allocation
	signal active_input_index       : integer range 0 to Num_Cores-1;
	signal active_input_index_next  : integer range 0 to Num_Cores-1;
	signal active_output_index      : integer range 0 to Num_Cores-1;
	signal active_output_index_next : integer range 0 to Num_Cores-1;
	
	-- FSM types and signals
	type input_scheduler_state is (WAITING, SCAN_AVAILABILITY, ASSIGN_TASK);
	signal current_input_state, upcoming_input_state : input_scheduler_state;
	
	type output_scheduler_state is (POLL_COMPLETION, TRANSMIT_RESULT);
	signal current_output_state, upcoming_output_state : output_scheduler_state;

begin
	-- Instantiate cores
	Core_array : for i in 0 to Num_Cores-1 generate
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
				valid_in        => trigger_core(i),
				ready_in        => open,
				ready_out       => acknowledge_core(i),
				valid_out       => core_finished(i),
				result          => core_results(i),
				modulus         => key_n,
				clk             => clk,
				reset_n         => reset_n
			);
		
		-- Monitor occupancy
		Core_status : process(clk, reset_n)
		begin
			if reset_n = '0' then
				core_occupied(i) <= '0';
				boundary_markers(i) <= '0';
			elsif rising_edge(clk) then
				if trigger_core(i) = '1' then
					core_occupied(i) <= '1';
					boundary_markers(i) <= msgin_last;
				elsif acknowledge_core(i) = '1' then
					core_occupied(i) <= '0';
				end if;
			end if;
		end process;
	end generate Core_array;
	
	-- Dispatch controller
	Dispatch_registers : process(clk, reset_n)
	begin
		if reset_n = '0' then
			trigger_core <= (others => '0');
			active_input_index <= 0;
			current_input_state <= WAITING;
		elsif rising_edge(clk) then
			trigger_core <= trigger_core_next;
			active_input_index <= active_input_index_next;
			current_input_state <= upcoming_input_state;
		end if;
	end process;
	
	Dispatch_logic : process(current_input_state, msgin_valid, core_occupied, active_input_index)
	begin
		msgin_ready <= '0';
		trigger_core_next <= (others => '0');
		active_input_index_next <= active_input_index;
		
		case current_input_state is
			when WAITING =>
				if msgin_valid = '1' then
					upcoming_input_state <= SCAN_AVAILABILITY;
				else
					upcoming_input_state <= WAITING;
				end if;
				
			when SCAN_AVAILABILITY =>
				if core_occupied(active_input_index) = '0' then
					trigger_core_next(active_input_index) <= '1';
					
					if active_input_index = (Num_Cores - 1) then
						active_input_index_next <= 0;
					else
						active_input_index_next <= active_input_index + 1;
					end if;
					
					upcoming_input_state <= ASSIGN_TASK;
				else
					upcoming_input_state <= SCAN_AVAILABILITY;
				end if;
				
			when ASSIGN_TASK =>
				msgin_ready <= '1';
				upcoming_input_state <= WAITING;
				
			when others =>
				upcoming_input_state <= WAITING;
		end case;
	end process;
	
	-- Collection controller
	Collection_registers : process(clk, reset_n)
	begin
		if reset_n = '0' then
			acknowledge_core <= (others => '0');
			active_output_index <= 0;
			current_output_state <= POLL_COMPLETION;
		elsif rising_edge(clk) then
			acknowledge_core <= acknowledge_core_next;
			active_output_index <= active_output_index_next;
			current_output_state <= upcoming_output_state;
		end if;
	end process;
	
	-- Collection controller
	Collection_logic : process(current_output_state, active_output_index, core_finished, msgout_ready, core_results, boundary_markers)
	begin
		msgout_data <= (others => '0');
		msgout_valid <= '0';
		msgout_last <= '0';
		acknowledge_core_next <= (others => '0');
		active_output_index_next <= active_output_index;
		
		case current_output_state is
			when POLL_COMPLETION =>
				if core_finished(active_output_index) = '1' then
					upcoming_output_state <= TRANSMIT_RESULT;
				else
					upcoming_output_state <= POLL_COMPLETION;
				end if;
				
			when TRANSMIT_RESULT =>
				if msgout_ready = '1' then
					msgout_data <= core_results(active_output_index);
					msgout_last <= boundary_markers(active_output_index);
					msgout_valid <= '1';
					
					acknowledge_core_next(active_output_index) <= '1';
					
					if active_output_index = (Num_Cores - 1) then
						active_output_index_next <= 0;
					else
						active_output_index_next <= active_output_index + 1;
					end if;
					
					upcoming_output_state <= POLL_COMPLETION;
				else
					upcoming_output_state <= TRANSMIT_RESULT;
				end if;
				
			when others =>
				upcoming_output_state <= POLL_COMPLETION;
		end case;
	end process;

	rsa_status <= (others => '0');
end rtl;