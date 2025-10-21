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

    -- Control signals for exponentiation datapath (ready/valid)
    start         : in  std_logic;  -- master -> valid
    ready_in      : out std_logic;  -- controller signals ready to accept input
    done          : out std_logic;  -- controller -> valid (result available)
    ready_out     : in  std_logic;  -- consumer -> ready to accept result

        -- Signals for exponentiation
        message       : in  std_logic_vector(C_block_size-1 downto 0);
        key           : in  std_logic_vector(C_block_size-1 downto 0);
        modulus       : in  std_logic_vector(C_block_size-1 downto 0);
        R_mod_n       : in  std_logic_vector(C_block_size-1 downto 0);
        R_squared_mod_n     : in  std_logic_vector(C_block_size-1 downto 0);
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
    -- R_mod_n and R_squared_mod_n are provided as inputs to the controller

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
    -- Flag to skip the initial base^2 write so we store only odd powers (3,5,7,...)
    signal precomp_first_done : std_logic := '0';
    signal precomp_first_done_next : std_logic := '0';

    -- Internal C and P registers
    signal C_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal P_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    -- Stored base^2 (Montgomery domain)
    signal base_sq_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');

    -- Montgomery start/pulse
    signal mont_request       : std_logic := '0';  -- combinational request from comb_proc
    signal mont_enable_pulse  : std_logic := '0';  -- one-cycle pulse generated in seq proc
    signal mont_running       : std_logic := '0';  -- indicates core is running

    -- CLNW signals
    signal MSB_index   : integer range 0 to C_block_size-1       := 0;
    signal MSB_index_next : integer range 0 to C_block_size-1  := 0;
    signal exp_counter : integer range 0 to C_block_size-1       := 0;
    signal NW          : integer range 0 to (2**window_size - 1) := 0;
    signal NW_next     : integer range 0 to (2**window_size - 1) := 0;
    signal window_type : integer range 0 to 1 := 0;  -- 0: zero window, 1: non-zero window
    signal window_type_next : integer range 0 to 1 := 0;
    
    -- MSB scan (run concurrently with PRECOMPUTE)
    signal msb_ptr        : integer range 0 to C_block_size-1 := C_block_size-1;
    signal msb_found      : std_logic := '0';
    signal msb_has_one    : std_logic := '0';
    signal msb_scan_active: std_logic := '0';
    signal msb_scan_request: std_logic := '0';
    signal wait_mem_ctr    : integer range 0 to 1 := 0;
    -- Flag indicating the EXP_INIT window was just read (one-shot)
    signal exp_init_done_sig : std_logic := '0';
    signal exp_init_done_next : std_logic := '0';

    -- Exponentiation done signal
    signal exp_done : std_logic := '0';
    signal exp_done_next : std_logic := '0';

    -- Handshake internal
    signal data_accept : std_logic := '0'; -- asserted when start AND ready_in

    -- Square counter used when performing repeated squarings
    signal square_count : integer range 0 to C_block_size-1 := 0;
    signal square_count_next : integer range 0 to C_block_size-1 := 0;
    -- Fast-path flag to indicate NW==1 (use base directly instead of BRAM read)
    signal precomp_fastpath : std_logic := '0';
begin


-- Sequential process: state transitions and register updates
process(clk, reset_n)
begin
    if reset_n = '0' then
        -- Reset registered state and counters only (do not drive comb-only *_next signals)
        state <= IDLE;
        exp_counter <= 0;
        precomp_index <= 0;
        C_reg <= (others => '0');
        P_reg <= (others => '0');
        MSB_index <= 0;
        NW <= 0;
        window_type <= 0;
        exp_init_done_sig <= '0';
        square_count <= 0;
        -- Montgomery control flags
        mont_enable_pulse <= '0';
        mont_running <= '0';
        -- Memory wait counter
        exp_init_done_sig <= '0';
        wait_mem_ctr <= 0;
        exp_done <= '0';
    elsif rising_edge(clk) then
        state <= next_state;

        -- Update registered MSB index from next-state value
        MSB_index <= MSB_index_next;
        NW <= NW_next;
        window_type <= window_type_next;
        -- Update other registered values from their next-state drivers
        precomp_index <= precomp_index_next;
        precomp_first_done <= precomp_first_done_next;
        exp_init_done_sig <= exp_init_done_next;
        square_count <= square_count_next;
    exp_done <= exp_done_next;

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
        
        -- Initialize C and P on data accept (synchronous load)
        if state = IDLE and data_accept = '1' then
            C_reg <= R_squared_mod_n;
            P_reg <= message;
            -- precomp_index is driven by precomp_index_next (set in comb_proc)
        end if;

        -- Update C and P after Montgomery multiplication completes after CONV_2_MONT
        if montgomery_done = '1' and state = CONV_2_MONT then
            C_reg <= montgomery_S;
            P_reg <= montgomery_S;
        end if;

        -- Update C or base_sq after Montgomery multiplication completes during PRECOMPUTE
        if montgomery_done = '1' and state = PRECOMPUTE then
            if precomp_first_done = '0' then
                -- first result is base^2; store it in base_sq_reg and mark done via comb_proc
                base_sq_reg <= montgomery_S;
            else
                -- subsequent results are odd powers; keep in C_reg as last_odd
                C_reg <= montgomery_S;
            end if;
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
            if precomp_fastpath = '1' then
                -- NW == 1: use base (P_reg) directly as the multiplicand
                C_reg <= R_mod_n;
            else
                C_reg <= precomp_dout;
            end if;
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
        msb_has_one <= '0';
        msb_scan_active <= '0';
    elsif rising_edge(clk) then
        -- Initialize MSB scan when requested by comb_proc
        if msb_scan_request = '1' then
            msb_ptr <= C_block_size - 1;
            msb_found <= '0';
            msb_has_one <= '0';
            msb_scan_active <= '1';
        elsif msb_scan_active = '1' and msb_found = '0' then
            -- Walk down the key bits until we find a '1' or reach bit 0
            if key(msb_ptr) = '1' then
                msb_found <= '1';
                msb_has_one <= '1';
            else
                if msb_ptr > 0 then
                    msb_ptr <= msb_ptr - 1;
                else
                    msb_found <= '1';
                    -- reached bit 0 and didn't see a '1'
                    msb_has_one <= '0';
                end if;
            end if;
        end if;
    end if;
end process msb_scan_proc;

comb_proc : process(all)
    variable start_idx : integer;
    variable window_val : integer;
begin
    -- Initialize variable to avoid latch
    start_idx := 0;
    -- default request deasserted
    msb_scan_request <= '0';
    -- Default outputs
    next_state <= state;
    -- Default next-state for MSB_index is the current registered value
    MSB_index_next <= MSB_index;
    NW_next <= NW;
    window_type_next <= window_type;
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
    precomp_first_done_next <= precomp_first_done;
    exp_init_done_next <= exp_init_done_sig;
    square_count_next <= square_count;
    -- default handshake signals
    ready_in <= '0';
    data_accept <= '0';
    case state is
        when IDLE =>
            -- Advertise ready to accept new inputs when in IDLE
            ready_in <= '1';
            -- Set default values for signals while idle
            mont_request <= '0';
            montgomery_A <= (others => '0');
            montgomery_B <= (others => '0');
            montgomery_N <= (others => '0');
            montgomery_enable <= '0';
            precomp_we <= '0';
            exp_done_next <= '0';
            exp_init_done_next <= '0';
            precomp_addr <= (others => '0');
            precomp_din <= (others => '0');
            -- keep result following P_reg and default next-state values
            
            if start = '1' then
                data_accept <= '1';
                -- Start an MSB scan for the incoming key/message so each test re-searches
                msb_scan_request <= '1';
                next_state <= CONV_2_MONT;
                precomp_index_next <= 0; -- initialize precompute index on start (we'll write odd powers starting at index 0 -> exponent 3)
                precomp_first_done_next <= '0';
            end if;
        when CONV_2_MONT =>
            if montgomery_done = '1' then
                next_state <= PRECOMPUTE;
            end if;
            -- Convert message to Montgomery form (request), R_sqared * Message
            mont_request <= '1';

        when PRECOMPUTE =>
            -- PRECOMPUTE operand selection strategy:
            -- 1) First multiply: compute base^2 = C_reg * P_reg (this is done right after CONV_2_MONT)
            -- 2) Next: compute base^3 = base_sq_reg * P_reg
            -- 3) Afterwards: compute next_odd = C_reg * base_sq_reg (chain using last odd in C_reg)
            if precomp_first_done = '0' then
                -- compute base^2
                mont_request <= '1';
                montgomery_A <= C_reg;
                montgomery_B <= P_reg;
            else
                if precomp_index = 0 then
                    -- compute base^3 = base_sq_reg * base
                    mont_request <= '1';
                    montgomery_A <= base_sq_reg;
                    montgomery_B <= P_reg;
                else
                    -- compute next_odd = last_odd * base_sq_reg
                    mont_request <= '1';
                    montgomery_A <= C_reg;
                    montgomery_B <= base_sq_reg;
                end if;
            end if;
            -- when the core completes, move to WAIT_MEM_WRITE to perform the BRAM write
            if montgomery_done = '1' then
                if precomp_first_done = '0' and precomp_index = 0 then
                    -- first result base^2 saved in seq proc; stay in PRECOMPUTE to compute base^3
                    precomp_first_done_next <= '1';
                    next_state <= PRECOMPUTE;
                else
                    next_state <= WAIT_MEM_WRITE;
                end if;
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
                -- Compute the exponent corresponding to current precomp_index: exp = 2*precomp_index + 3
                if (2 * precomp_index + 3) >= (2**window_size - 1) and msb_found = '1' then
                    -- we've written up to the maximum odd exponent; proceed to exponentiation
                    next_state <= EXP_INIT;
                else
                    next_state <= PRECOMPUTE;
                end if;
                -- On the second cycle, advance precompute index if more entries remain
                if (2 * precomp_index + 3) < (2**window_size - 1) then
                    precomp_index_next <= precomp_index + 1;
                else
                    precomp_index_next <= precomp_index;
                end if;
            end if;
        when EXP_INIT =>
            -- Initialize exponentiation process by reading the first window from MSB index
            -- prepare first window safely (handle truncated top window)
            start_idx := msb_ptr - window_size + 1;
            if start_idx < 0 then
                start_idx := 0;
                exp_done_next <= '1';
            end if;
            -- Extract window and shrink until odd so we only need odd precomputations
            window_val := to_integer(unsigned(key(msb_ptr downto start_idx)));
            while (window_val mod 2 = 0) and (start_idx < msb_ptr) loop
                start_idx := start_idx + 1;
                window_val := to_integer(unsigned(key(msb_ptr downto start_idx)));
            end loop;
            NW_next <= window_val;
            -- msb_scan_proc will clear active when done; nothing for comb to drive here
            next_state  <= WINDOW_READ_MEM;
            if start_idx /= 0 then
                MSB_index_next <= start_idx - 1;
            else
                MSB_index_next <= start_idx;
            end if;

        when WINDOW_SCAN =>
            -- mark that EXP_INIT window was read (one-shot)
            exp_init_done_next <= '1';
            -- Scan for next Non-zero window in exponent
            if MSB_index = 0 and exp_done = '1' then
                next_state <= CONV_2_NORMAL;
            else
                if key(MSB_index) = '0' then
                    window_type_next <= 0;  -- Zero window
                    MSB_index_next <= MSB_index - 1;
                    next_state <= WINDOW_SQUARE_START;
                else
                    window_type_next <= 1;  -- Non-zero window
                    -- compute safe start index for this window
                    start_idx := MSB_index - window_size + 1;
                    if start_idx < 0 then
                        start_idx := 0;
                        exp_done_next <= '1';
                    end if;

                    -- Extract window and shrink until odd so we index only odd precomputations
                    window_val := to_integer(unsigned(key(MSB_index downto start_idx )));
                    while (window_val mod 2 = 0) and (start_idx < MSB_index) loop
                        start_idx := start_idx + 1;
                        window_val := to_integer(unsigned(key(MSB_index downto start_idx )));
                    end loop;

                    NW_next <= window_val;
                    square_count_next <= MSB_index - start_idx;  -- number of bits processed in this window
                    next_state <= WINDOW_READ_MEM;
                end if;
            end if;

        when WINDOW_READ_MEM =>
            -- Read precomputed value from memory for current window NW
            -- Precompute memory stores only odd powers starting at exponent 3: mapping is
            -- index = (NW - 3) / 2 for NW >= 3. For NW == 1, we use fast-path (no BRAM read)
            if NW = 1 then
                precomp_addr <= (others => '0');
                precomp_fastpath <= '1';
            elsif NW >= 3 then
                precomp_addr <= std_logic_vector(to_unsigned((NW - 3) / 2, precomp_addr'length));
                precomp_fastpath <= '0';
            else
                precomp_addr <= (others => '0');
                precomp_fastpath <= '0';
            end if;
            next_state <= WINDOW_WAIT_MEM;

        when WINDOW_WAIT_MEM =>
            -- Memory read done; start squaring operations
            -- If this was the initial EXP_INIT window, skip squaring and go
            -- directly to WINDOW_SCAN (we already used this precompute to set P_reg).
            if exp_init_done_sig = '1' then
                next_state <= WINDOW_SQUARE_START;
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
            montgomery_A <= std_logic_vector(to_unsigned(1, montgomery_B'length));
            montgomery_B <= C_reg;
        when FINISHED =>
            done <= '1';
            next_state <= IDLE;
    end case;
end process;

end RTL;
