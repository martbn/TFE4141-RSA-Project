library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity montgomery_r64 is
    generic (
           WIDTH : integer := 256  -- Operand width (e.g. 1024 bits for RSA)
           
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
           S      : out std_logic_vector(WIDTH-1 downto 0);   -- Result: S = (A * B * R⁻¹) mod N
           N_prime : in std_logic_vector((WIDTH/8)-1 downto 0);  -- Precomputed N' values for Montgomery reduction
        
           -- Debug outputs for waveform viewing
           current_state_debug : out integer range 0 to 4;  -- 0=IDLE, 1=STATE1, 2=STATE2, 3=STATE3, 4=FINISHED
           outer_iteration_counter_debug : out unsigned(3 downto 0);  -- Current iteration counter
           last_outer_loop_state_debug : out std_logic_vector(3 downto 0);  -- Last outer loop state counter
           
           -- Datapath gamma output debug signals
           s_g1_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           s_g2_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           s_g3_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           s1_gf_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           
           -- Datapath alpha output debug signals
           s_a1_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           s_a2_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           s_a3_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_a1_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_a2_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_a3_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           
           -- Datapath alpha IMMEDIATE carry debug signals (when produced)
           c_a1_out_immediate_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_a2_out_immediate_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_a3_out_immediate_debug : out unsigned((WIDTH/8)-1 downto 0);
           
           -- Datapath beta output debug signals
           m_debug : out unsigned((WIDTH/8)-1 downto 0);
           c_b_out_debug : out unsigned((WIDTH/8)-1 downto 0);
           
           -- Datapath operand word debug signals
           a_first_word_debug : out unsigned((WIDTH/8)-1 downto 0);
           a_middle_word_debug : out unsigned((WIDTH/8)-1 downto 0);
           a_last_word_debug : out unsigned((WIDTH/8)-1 downto 0);
           b_first_correct_debug : out unsigned((WIDTH/8)-1 downto 0);
           b_middle_correct_debug : out unsigned((WIDTH/8)-1 downto 0);
           b_last_correct_debug : out unsigned((WIDTH/8)-1 downto 0)
        
    );
end montgomery_r64;

architecture behavioral of montgomery_r64 is
    signal sig_state : std_logic;
    signal shift_a : std_logic := '0';
    signal shift_b : std_logic := '0';

    signal activate_alpha1 : std_logic := '0';
    signal activate_alpha2 : std_logic := '0';
    signal activate_alpha3 : std_logic := '0';
    signal activate_alpha_final : std_logic := '0';
    signal activate_gamma1 : std_logic := '0';
    signal activate_gamma2 : std_logic := '0';
    signal activate_gamma3 : std_logic := '0';
    signal activate_gamma_final : std_logic := '0';
    signal activate_beta : std_logic := '0';
    signal last_outer_loop_state : std_logic_vector(3 downto 0) := (others => '0');
    signal result_internal : unsigned(WIDTH + (WIDTH/8) - 1 downto 0);
    
    

begin

    -- Instantiate controller
    -- For radix-64 windowed datapath we count windows instead of bits.
    r64_controller: entity work.montgomery_r64_controller
        generic map (
            WIDTH => WIDTH
        )
        port map (
            clk    => clk,
            reset  => reset,
            sig_state => sig_state,
            shift_a => shift_a,
            shift_b => shift_b,
            last_outer_loop_state => last_outer_loop_state,
            activate_gamma_final => activate_gamma_final,
            activate_gamma1 => activate_gamma1,
            activate_gamma2 => activate_gamma2,
            activate_gamma3 => activate_gamma3,
            activate_beta => activate_beta,
            activate_alpha1 => activate_alpha1,
            activate_alpha2 => activate_alpha2,
            activate_alpha3 => activate_alpha3,
            activate_alpha_final => activate_alpha_final,
            enable => enable,
            done   => done,
            current_state_debug => current_state_debug,
            outer_iteration_counter_debug => outer_iteration_counter_debug
          
        );
    
    -- Connect debug output
    last_outer_loop_state_debug <= last_outer_loop_state;

    -- Instantiate datapath
    -- New windowed datapath (radix-64) — uses DSPs via unsigned multiplies.
    r64_datapath: entity work.montgomery_r64_datapath
        generic map (
            WORD_WIDTH => WIDTH/8,
            OPERAND_WIDTH => WIDTH
        )
        port map (
            clk    => clk,
            reset  => reset,
            a_operand => unsigned(A),
            b_operand => unsigned(B),
            n_operand => unsigned(N),
            n_marked_operand => unsigned(N_prime),
            sig_state => sig_state,
            shift_a => shift_a,
            shift_b => shift_b,
            activate_alpha1 => activate_alpha1,
            activate_alpha2 => activate_alpha2,
            activate_alpha3 => activate_alpha3,
            activate_alpha_final => activate_alpha_final,
            activate_gamma1 => activate_gamma1,
            activate_gamma2 => activate_gamma2,
            activate_gamma3 => activate_gamma3,
            activate_gamma_final => activate_gamma_final,
            activate_beta => activate_beta,
            last_outer_loop_state => unsigned(last_outer_loop_state),
            result_out      => result_internal,
            s_g1_out_debug => s_g1_out_debug,
            s_g2_out_debug => s_g2_out_debug,
            s_g3_out_debug => s_g3_out_debug,
            s1_gf_out_debug => s1_gf_out_debug,
            s_a1_out_debug => s_a1_out_debug,
            s_a2_out_debug => s_a2_out_debug,
            s_a3_out_debug => s_a3_out_debug,
            c_a1_out_debug => c_a1_out_debug,
            c_a2_out_debug => c_a2_out_debug,
            c_a3_out_debug => c_a3_out_debug,
            c_a1_out_immediate_debug => c_a1_out_immediate_debug,
            c_a2_out_immediate_debug => c_a2_out_immediate_debug,
            c_a3_out_immediate_debug => c_a3_out_immediate_debug,
            m_debug => m_debug,
            c_b_out_debug => c_b_out_debug,
            a_first_word_debug => a_first_word_debug,
            a_middle_word_debug => a_middle_word_debug,
            a_last_word_debug => a_last_word_debug,
            b_first_correct_debug => b_first_correct_debug,
            b_middle_correct_debug => b_middle_correct_debug,
            b_last_correct_debug => b_last_correct_debug
        );
    
    -- Extract the lower WIDTH bits of result as the final output
    S <= std_logic_vector(result_internal(WIDTH-1 downto 0));

    -- Original bit-serial datapath (kept for reference)
    -- u_datapath: entity work.montgomery_mult_datapath
    --     generic map ( WIDTH => WIDTH )
    --     port map ( ... );

end behavioral;