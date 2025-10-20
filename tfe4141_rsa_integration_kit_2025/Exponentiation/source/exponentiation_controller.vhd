library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation_controller is
    generic (
        C_block_size : integer := 256;
        window_size  : integer := 4
    );
    port (
        -- Clock and reset
        clk    : in  std_logic;
        reset_n : in  std_logic;

        -- Control signals for exponentiation datapath
        start         : in  std_logic;
        done          : out std_logic;

        -- Signals for exponentiation
        message       : in  std_logic_vector(C_block_size-1 downto 0);
        key           : in  std_logic_vector(C_block_size-1 downto 0);
        modulus       : in  std_logic_vector(C_block_size-1 downto 0);
    R_mod_n       : in  std_logic_vector(C_block_size-1 downto 0);
    R_squared     : in  std_logic_vector(C_block_size-1 downto 0);
        result        : out std_logic_vector(C_block_size-1 downto 0);

        -- Control signals for Montgomery multiplier
        montgomery_enable : out std_logic;
        montgomery_done   : in  std_logic;

        -- Signals for montgomery multiplier
        montgomery_A      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_B      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_N      : out std_logic_vector(C_block_size-1 downto 0);
        montgomery_S      : in  std_logic_vector(C_block_size-1 downto 0);

        -- Control signals for precomputation memory
        precomp_addr   : out std_logic_vector(window_size-1 downto 0);
        precomp_we     : out std_logic;
        precomp_din    : out std_logic_vector(C_block_size-1 downto 0);
        precomp_dout   : in  std_logic_vector(C_block_size-1 downto 0)
    );
end exponentiation_controller;

architecture RTL of exponentiation_controller is

    -- R values (now supplied by top-level/testbench via ports):
    -- R_mod_n and R_squared are provided as inputs to the controller

    -- State machine states
    type state_type is (
        IDLE, 
        CONV_2_MONT, 
        PRECOMPUTE, 
        WAIT_MEM_WRITE,
        EXP_INIT,
        WINDOW_SCAN,
        WINDOW_READ_MEM,
        WINDOW_WAIT_MEM,
        WINDOW_SQUARE_START,
        WINDOW_WAIT_MONT,
        WINDOW_SQUARE_CONTINUE,
        WINDOW_MULT_START,
        WINDOW_DONE,
        CONV_2_NORMAL,
        FINISHED
    );
    signal state, next_state : state_type := IDLE;

    -- Precomputation index (tracks odd numbers: 3, 5, 7, ... up to 2^window_size-1)
    signal precomp_index : integer range 0 to (2**window_size) := 0;
    signal precomp_index_next : integer range 0 to (2**window_size) := 0;
    signal precomp_curr_exp : integer range 0 to (2**window_size) := 0;

    -- Internal C and P registers
    signal C_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal P_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');

    -- Montgomery start/pulse
    signal mont_request       : std_logic := '0';  -- combinational request from comb_proc
    signal mont_enable_pulse  : std_logic := '0';  -- one-cycle pulse generated in seq proc
    signal mont_running       : std_logic := '0';  -- indicates core is running

    -- CLNW signals
    signal MSB_index   : integer range 0 to C_block_size-1       := 0;
    signal MSB_index_next : integer range 0 to C_block_size-1  := 0;
    signal exp_counter : integer range 0 to C_block_size-1       := 0;
    signal NW          : integer range 0 to (2**window_size - 1) := 0;
    signal window_type : integer range 0 to 1 := 0;  -- 0: zero window, 1: non-zero window
    -- MSB scan (run concurrently with PRECOMPUTE)
    signal msb_ptr        : integer range 0 to C_block_size-1 := C_block_size-1;
    signal msb_found      : std_logic := '0';
    signal msb_scan_active: std_logic := '0';
    signal msb_scan_request: std_logic := '0';
    signal wait_mem_ctr    : integer range 0 to 1 := 0;
    -- Flag indicating the EXP_INIT window was just read (one-shot)
    signal exp_init_done_sig : std_logic := '0';
    signal exp_init_done_next : std_logic := '0';

    -- Square counter used when performing repeated squarings
    signal square_count : integer range 0 to C_block_size-1 := 0;
    signal square_count_next : integer range 0 to C_block_size-1 := 0;
begin


-- Sequential process: state transitions and register updates
process(clk, reset_n)
begin
    if reset_n = '0' then
        state <= IDLE;
        exp_counter <= 0;
        precomp_index <= 0;
        precomp_index_next <= 0;
        C_reg <= (others => '0');
        P_reg <= (others => '0');
    MSB_index <= 0;
    exp_init_done_sig <= '0';
    exp_init_done_next <= '0';
    square_count <= 0;
    square_count_next <= 0;
    elsif rising_edge(clk) then
        state <= next_state;

        -- Update registered MSB index from next-state value
        MSB_index <= MSB_index_next;
        -- Update other registered values from their next-state drivers
        precomp_index <= precomp_index_next;
        exp_init_done_sig <= exp_init_done_next;
        square_count <= square_count_next;

        -- Generate one-cycle start pulse for Montgomery core when requested
        mont_enable_pulse <= '0';
        if mont_request = '1' and mont_running = '0' then
            mont_enable_pulse <= '1';
            mont_running <= '1';
        end if;

        -- Clear mont_running when core signals done (sampled synchronously)
        if mont_running = '1' and montgomery_done = '1' then
            mont_running <= '0';
        end if;
        
        -- Initialize C and P on start (synchronous load)
        if state = IDLE and start = '1' then
            C_reg <= R_squared;
            P_reg <= message;
            -- precomp_index is driven by precomp_index_next (set in comb_proc)
        end if;

        -- Update C and P after Montgomery multiplication completes after CONV_2_MONT
        if montgomery_done = '1' and state = CONV_2_MONT then
            C_reg <= montgomery_S;
            P_reg <= montgomery_S;
        end if;

        -- Update C after Montgomery multiplication completes during PRECOMPUTE
        if montgomery_done = '1' and state = PRECOMPUTE then
            C_reg <= montgomery_S;
        end if;

        -- Update P after Montgomery multiplication completes during WINDOW_WAIT_MONT
        if montgomery_done = '1' and state = WINDOW_WAIT_MONT then
            P_reg <= montgomery_S;
        end if;

        -- Capture final conversion result after CONV_2_NORMAL completes
        if montgomery_done = '1' and state = CONV_2_NORMAL then
            -- store converted (normal-domain) result into P_reg so `result` follows
            P_reg <= montgomery_S;
        end if;


        -- Sample BRAM read data into C_reg when in WINDOW_WAIT_MEM
        if state = WINDOW_WAIT_MEM then
            C_reg <= precomp_dout;
        end if;

        -- Wait-counter after a memory write (state WAIT_MEM_WRITE)
        -- precomp_index is advanced by the comb_proc via precomp_index_next to avoid
        -- combinational/sequential multiple drivers.
        if state = WAIT_MEM_WRITE then
            if wait_mem_ctr < 1 then
                wait_mem_ctr <= wait_mem_ctr + 1;
            else
                wait_mem_ctr <= wait_mem_ctr;
            end if;
        else
            wait_mem_ctr <= 0;
        end if;

    end if;
end process;

-- MSB scan process: runs when msb_scan_active = '1', searches key from MSB down
msb_scan_proc: process(clk, reset_n)
begin
    if reset_n = '0' then
        msb_ptr <= C_block_size - 1;
        msb_found <= '0';
        msb_scan_active <= '0';
    elsif rising_edge(clk) then
        -- Initialize MSB scan when requested by comb_proc
        if msb_scan_request = '1' then
            msb_ptr <= C_block_size - 1;
            msb_found <= '0';
            msb_scan_active <= '1';
        elsif msb_scan_active = '1' and msb_found = '0' then
            -- Walk down the key bits until we find a '1' or reach bit 0
            if key(msb_ptr) = '1' then
                msb_found <= '1';
            else
                if msb_ptr > 0 then
                    msb_ptr <= msb_ptr - 1;
                else
                    msb_found <= '1';
                end if;
            end if;
        end if;
    end if;
end process msb_scan_proc;

comb_proc : process(all)
    variable start_idx : integer := 0;
begin
    -- default request deasserted
    msb_scan_request <= '0';
    -- Default outputs
    next_state <= state;
    -- Default next-state for MSB_index is the current registered value
    MSB_index_next <= MSB_index;
    montgomery_enable <= mont_enable_pulse;
    montgomery_A <= C_reg;
    montgomery_B <= P_reg;
    montgomery_N <= modulus;
    precomp_we <= '0';
    precomp_addr <= (others => '0');
    precomp_din <= (others => '0');
    mont_request <= '0';
    done <= '0';
    result <= P_reg;
    -- Default next-state values (keep current)
    precomp_index_next <= precomp_index;
    exp_init_done_next <= exp_init_done_sig;
    square_count_next <= square_count;

    case state is
        when IDLE =>
            if start = '1' then
                next_state <= CONV_2_MONT;
                precomp_index_next <= 0; -- initialize precompute index on start
            end if;
        when CONV_2_MONT =>
            if montgomery_done = '1' then
                next_state <= PRECOMPUTE;
            end if;
            -- Convert message to Montgomery form (request), R_sqared * Message
            mont_request <= '1';

        when PRECOMPUTE =>
            -- Request Montgomery to compute C_reg * P_reg mod N
            mont_request <= '1';
            montgomery_A <= C_reg;
            montgomery_B <= P_reg;
            -- when the core completes, move to WAIT_MEM_WRITE to perform the BRAM write
            if montgomery_done = '1' then
                next_state <= WAIT_MEM_WRITE;
            end if;
            -- request MSB scan while precompute is running (sequential proc will initialize)
            if msb_scan_active = '0' and msb_found = '0' then
                msb_scan_request <= '1';
            end if;

        when WAIT_MEM_WRITE =>
            -- Two-cycle wait: assert BRAM write for both cycles (address/data stable)
            precomp_we <= '1';
            precomp_addr <= std_logic_vector(to_unsigned(precomp_index, precomp_addr'length));
            precomp_din <= montgomery_S;
            if wait_mem_ctr = 0 then
                -- stay in WAIT_MEM_WRITE for second cycle
                next_state <= WAIT_MEM_WRITE;
            else
                -- second cycle: decide next state
                if precomp_index >= (2**window_size - 1) and msb_found = '1' then
                    next_state <= EXP_INIT;
                else
                    next_state <= PRECOMPUTE;
                end if;
                -- On the second cycle, advance precompute index
                if precomp_index < (2**window_size - 1) then
                    precomp_index_next <= precomp_index + 1;
                else
                    precomp_index_next <= precomp_index;
                end if;
            end if;
        when EXP_INIT =>
        -- Initialize exponentiation process by reading the first window from MSB index
            -- set initial MSB_index from the msb_ptr found by the concurrent scan
            MSB_index_next <= msb_ptr;
            -- prepare first window safely (handle truncated top window)
            start_idx := msb_ptr - window_size;
            if start_idx < 0 then
                start_idx := 0;
            end if;
            NW <= to_integer(unsigned(key(msb_ptr downto start_idx + 1 )));
            -- msb_scan_proc will clear active when done; nothing for comb to drive here
            next_state  <= WINDOW_READ_MEM;

        when WINDOW_SCAN =>
            -- mark that EXP_INIT window was read (one-shot)
            exp_init_done_next <= '1';
            -- Scan for next Non-zero window in exponent
            if MSB_index = 0 then
                next_state <= CONV_2_NORMAL;
            else
                if key(MSB_index - 1) = '0' then
                    window_type <= 0;  -- Zero window
                    MSB_index_next <= MSB_index - 1;
                    next_state <= WINDOW_SQUARE_START;
                else
                    window_type <= 1;  -- Non-zero window
                    -- compute safe start index for this window
                    start_idx := MSB_index - window_size;
                    if start_idx < 0 then
                        start_idx := 0;
                    end if;

                    NW <= to_integer(unsigned(key(MSB_index downto start_idx + 1 )));

                    next_state <= WINDOW_READ_MEM;
                end if;
            end if;

        when WINDOW_READ_MEM =>
            MSB_index_next <= start_idx;
            -- Read precomputed value from memory for current window NW
            precomp_addr <= std_logic_vector(to_unsigned(NW/2, precomp_addr'length));
            next_state <= WINDOW_WAIT_MEM;

        when WINDOW_WAIT_MEM =>
            -- Memory read done; start squaring operations
            -- If this was the initial EXP_INIT window, skip squaring and go
            -- directly to WINDOW_SCAN (we already used this precompute to set P_reg).
            if exp_init_done_sig = '1' then
                next_state <= WINDOW_SQUARE_START;
                -- clear the one-shot after observing it
                exp_init_done_next <= '0';
            else
                -- precomp_dout is sampled synchronously in the sequential process when
                -- state = WINDOW_WAIT_MEM (so one cycle is available). Proceed to
                -- the squaring start state on the next cycle.
                next_state <= WINDOW_SCAN;
            end if;
        when WINDOW_SQUARE_START =>
            -- Start squaring P_reg window_size times or once for zero window  
            if window_type = 0 then
                -- Zero window: square once
                mont_request <= '1';
                montgomery_A <= P_reg;
                montgomery_B <= P_reg;
                square_count_next <= 1;
            else
                -- Non-zero window: square window_size times
                mont_request <= '1';
                montgomery_A <= P_reg;
                montgomery_B <= P_reg;
                square_count_next <= window_size;
            end if;
            next_state <= WINDOW_WAIT_MONT;

        when WINDOW_WAIT_MONT =>
            if montgomery_done = '1' then
                if square_count > 1 then
                    -- More squarings to do
                    next_state <= WINDOW_SQUARE_CONTINUE;
                else
                    -- All squarings done; proceed to multiplication if non-zero window
                    if window_type = 1 then
                        next_state <= WINDOW_MULT_START;
                    else
                        next_state <= WINDOW_SCAN;
                    end if;
                end if;
            end if;

        when WINDOW_SQUARE_CONTINUE =>
            mont_request <= '1';
            square_count_next <= square_count - 1;
            next_state <= WINDOW_WAIT_MONT;

        when WINDOW_MULT_START =>
            -- Start multiplication P_reg * precomputed value for NW
            mont_request <= '1';
            montgomery_A <= P_reg;
            montgomery_B <= C_reg;
            next_state <= WINDOW_DONE;

        when WINDOW_DONE =>
            if montgomery_done = '1' then
                next_state <= WINDOW_SCAN;
            end if;

        when CONV_2_NORMAL =>
            if montgomery_done = '1' then
                next_state <= FINISHED;
            end if;
            -- Convert result back to normal form: Mont(P_reg, 1)
            mont_request <= '1';
            montgomery_A <= P_reg;
            montgomery_B <= std_logic_vector(to_unsigned(1, montgomery_B'length));
        when FINISHED =>
            done <= '1';
    end case;
end process;

end RTL;
