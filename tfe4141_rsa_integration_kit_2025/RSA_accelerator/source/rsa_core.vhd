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
		Num_Cores             : integer := 9
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

	-- Matrix for core outputs and flags
	type t_matrix is array (0 to Num_Cores-1) of std_logic_vector(C_BLOCK_SIZE-1 downto 0);
	signal msgout_vector       : t_matrix;
	signal core_flag_out       : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Core control signals
	signal cores_start         : std_logic_vector(Num_Cores-1 downto 0);
	signal cores_start_nxt     : std_logic_vector(Num_Cores-1 downto 0);
	signal cores_clear         : std_logic_vector(Num_Cores-1 downto 0);
	signal cores_clear_nxt     : std_logic_vector(Num_Cores-1 downto 0);
	signal cores_done          : std_logic_vector(Num_Cores-1 downto 0);
	signal cores_busy          : std_logic_vector(Num_Cores-1 downto 0);
	
	-- Round-robin counters
	signal next_to_start       : integer range 0 to Num_Cores-1;
	signal next_to_start_nxt   : integer range 0 to Num_Cores-1;
	signal next_to_finish      : integer range 0 to Num_Cores-1;
	signal next_to_finish_nxt  : integer range 0 to Num_Cores-1;
	
	-- FSM types and signals
	type state_type_input is (IDLE, CHECK_CORES, WAIT_FOR_CORE_START);
	signal Input_State, NIS    : state_type_input;
	
	type state_type_output is (MONITOR_CORE_OUTPUT, WRITE_DATA);
	signal Output_State, NOS   : state_type_output;

begin
	-- Generate Num_Cores exponentiation cores with start/clear control
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
				valid_in        => cores_start(i),
				ready_in        => open,  -- Not used in this architecture
				ready_out       => cores_clear(i),
				valid_out       => cores_done(i),
				result          => msgout_vector(i),
				modulus         => key_n,
				clk             => clk,
				reset_n         => reset_n
			);
		
		-- Track busy state: set on start, cleared on clear
		process(clk, reset_n)
		begin
			if reset_n = '0' then
				cores_busy(i) <= '0';
				core_flag_out(i) <= '0';
			elsif rising_edge(clk) then
				if cores_start(i) = '1' then
					cores_busy(i) <= '1';
					core_flag_out(i) <= msgin_last;
				elsif cores_clear(i) = '1' then
					cores_busy(i) <= '0';
				end if;
			end if;
		end process;
	end generate Cores;
	
	-- Input FSM: Synchronous state update
	Sync_input : process(clk, reset_n)
	begin
		if reset_n = '0' then
			cores_start <= (others => '0');
			next_to_start <= 0;
			Input_State <= IDLE;
		elsif rising_edge(clk) then
			cores_start <= cores_start_nxt;
			next_to_start <= next_to_start_nxt;
			Input_State <= NIS;
		end if;
	end process;
	
	-- Input FSM: Combinational next-state logic
	Input_fsm : process(Input_State, msgin_valid, cores_busy, next_to_start)
	begin
		msgin_ready <= '0';
		cores_start_nxt <= (others => '0');
		next_to_start_nxt <= next_to_start;
		
		case Input_State is
			when IDLE =>
				if msgin_valid = '1' then
					NIS <= CHECK_CORES;
				else
					NIS <= IDLE;
				end if;
				
			when CHECK_CORES =>
				if cores_busy(next_to_start) = '0' then
					cores_start_nxt(next_to_start) <= '1';
					
					-- Increment counter with wrap-around
					if next_to_start >= (Num_Cores - 1) then
						next_to_start_nxt <= 0;
					else
						next_to_start_nxt <= next_to_start + 1;
					end if;
					
					NIS <= WAIT_FOR_CORE_START;
				else
					NIS <= CHECK_CORES;
				end if;
				
			when WAIT_FOR_CORE_START =>
				msgin_ready <= '1';
				NIS <= IDLE;
				
			when others =>
				NIS <= IDLE;
		end case;
	end process;
	
	-- Output FSM: Synchronous state update
	Sync_output : process(clk, reset_n)
	begin
		if reset_n = '0' then
			cores_clear <= (others => '0');
			next_to_finish <= 0;
			Output_State <= MONITOR_CORE_OUTPUT;
		elsif rising_edge(clk) then
			cores_clear <= cores_clear_nxt;
			next_to_finish <= next_to_finish_nxt;
			Output_State <= NOS;
		end if;
	end process;
	
	-- Output FSM: Combinational next-state logic
	Output_fsm : process(Output_State, next_to_finish, cores_done, msgout_ready, msgout_vector, core_flag_out)
	begin
		msgout_data <= (others => '0');
		msgout_valid <= '0';
		msgout_last <= '0';
		cores_clear_nxt <= (others => '0');
		next_to_finish_nxt <= next_to_finish;
		
		case Output_State is
			when MONITOR_CORE_OUTPUT =>
				if cores_done(next_to_finish) = '1' then
					NOS <= WRITE_DATA;
				else
					NOS <= MONITOR_CORE_OUTPUT;
				end if;
				
			when WRITE_DATA =>
				if msgout_ready = '1' then
					msgout_data <= msgout_vector(next_to_finish);
					msgout_last <= core_flag_out(next_to_finish);
					msgout_valid <= '1';
					
					cores_clear_nxt(next_to_finish) <= '1';
					
					-- Increment counter with wrap-around
					if next_to_finish >= (Num_Cores - 1) then
						next_to_finish_nxt <= 0;
					else
						next_to_finish_nxt <= next_to_finish + 1;
					end if;
					
					NOS <= MONITOR_CORE_OUTPUT;
				else
					NOS <= WRITE_DATA;
				end if;
				
			when others =>
				NOS <= MONITOR_CORE_OUTPUT;
		end case;
	end process;

	rsa_status <= (others => '0');
end rtl;