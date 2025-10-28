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

    -- R_mod_n and R_squared_mod_n are provided as inputs to the controller

    -- State machine states
    type state_type is (
        IDLE,                   -- Wait for start signal, advertise ready
        CONV_2_MONT,            -- Convert message to Montgomery domain (R**2 * M)
        PRECOMPUTE,             -- Compute odd powers: base**2, base**3, base**5, ... base**(2**(w-1))
        WAIT_MEM_WRITE,         -- 2-cycle BRAM write latency for precomputed values
        WINDOW_SCAN,            -- Scan exponent for next window (zero/non-zero)
        WINDOW_READ_MEM,        -- Read precomputed value from BRAM
        WINDOW_WAIT_MEM,        -- Wait for BRAM read latency (1 cycle)
        WINDOW_SQUARE_START,    -- Start squaring sequence for window
        WINDOW_MULT_START,      -- Multiply by precomputed window value
        CONV_2_NORMAL,          -- Convert from Montgomery domain (result * 1)
        FINISHED               -- Assert done signal, return to IDLE
    );
    signal state, next_state : state_type := IDLE;

    -- Precomputation index (tracks odd numbers: 3, 5, 7, ... up to 2^window_size-1)
    signal precomp_index : integer range 0 to (2**window_size) := 0;
    signal precomp_index_next : integer range 0 to (2**window_size) := 0;
    -- Flag to skip the initial base^2 write so we store only odd powers (3,5,7,...)
    signal precomp_first_done : std_logic := '0';
    signal precomp_first_done_next : std_logic := '0';

    -- Internal C and P registers
    signal C_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');
    signal P_reg : std_logic_vector(C_block_size-1 downto 0) := (others => '0');

    -- Montgomery start/pulse
    signal mont_request       : std_logic := '0';  -- combinational request from comb_proc
    signal mont_enable_pulse  : std_logic := '0';  -- one-cycle pulse generated in seq proc
    signal mont_running       : std_logic := '0';  -- indicates core is running

    -- CLNW signals
    signal init_window_done : std_logic := '0';
    signal init_window_done_next : std_logic := '0';
    signal MSB_index   : integer range 0 to C_block_size-1       := 0;
    signal MSB_index_next : integer range 0 to C_block_size-1  := 0;
    signal exp_counter : integer range 0 to C_block_size-1       := 0;
    signal NW          : integer range 0 to (2**window_size - 1) := 0;
    signal NW_next     : integer range 0 to (2**window_size - 1) := 0;
    signal window_type : integer := 0;  -- 0: zero window, 1: non-zero window
    signal window_type_next : integer := 0;

    -- MSB scan (run concurrently with PRECOMPUTE)
    -- Separate scan pointer (owned by scan process) and scan result
    signal msb_scan_ptr   : integer range 0 to C_block_size-1 := C_block_size-1;
    signal msb_found      : std_logic := '0';
    signal msb_scan_active: std_logic := '0';
    signal msb_scan_request: std_logic := '0';
    signal wait_mem_ctr    : integer range 0 to 1 := 0;

    -- Exponentiation done signal
    signal exp_done : std_logic := '0';
    signal exp_done_next : std_logic := '0';

    -- CLNW scanner interface signals (moved to separate component)
    signal CLNW_scan_request : std_logic := '0';
    signal CLNW_scan_request_next : std_logic := '0';
    signal CLNW_found        : std_logic := '0';
    signal window_LSB        : integer := 0;
    signal window_MSB        : integer := 0;
    signal zero_window_count : integer := 0;
    -- CLNW scanner window type (single-driver from clnw_scanner)
    signal clnw_window_type  : integer := 0;

    -- Handshake internal
    signal data_accept : std_logic := '0'; -- asserted when start AND ready_in

    -- Square counter used when performing repeated squarings
    signal square_count : integer range 0 to C_block_size-1 := 0;
    signal square_count_next : integer range 0 to C_block_size-1 := 0;
    -- Indicate we've written Mont(base) into BRAM (address 1)
    signal precomp_base1_written : std_logic := '0';
    signal precomp_base1_written_next : std_logic := '0';
    -- Registered output for valid/done handshake
    signal done_reg : std_logic := '0';
    signal done_reg_next : std_logic := '0';
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
        square_count <= 0;
        -- Montgomery control flags
        mont_enable_pulse <= '0';
        mont_running <= '0';
        -- Memory wait counter
        wait_mem_ctr <= 0;
        exp_done <= '0';
        init_window_done <= '0';
        -- Ensure these control flags/registers have async reset to avoid inferred flops
        precomp_base1_written <= '0';
        precomp_first_done <= '0';
        window_type <= 0;
        done_reg <= '0';
    CLNW_scan_request <= '0';
    elsif rising_edge(clk) then
        state <= next_state;

        -- Update registered MSB index from next-state value
        MSB_index <= MSB_index_next;
        -- Update NW registered value
        NW <= NW_next;
        -- Update registered CLNW request pulse from combinational driver
        CLNW_scan_request <= CLNW_scan_request_next;
        -- Update registered window type captured from CLNW scanner
        window_type <= window_type_next;
        -- Update other registered values from their next-state drivers
        precomp_index <= precomp_index_next;
        precomp_first_done <= precomp_first_done_next;
        precomp_base1_written <= precomp_base1_written_next;
        square_count <= square_count_next;
        exp_done <= exp_done_next;
        -- Update init_window_done from its next-state driver
        init_window_done <= init_window_done_next;

    -- Register the done/valid handshake output
    done_reg <= done_reg_next;

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

        -- CLNW_scan_request is driven as a registered pulse from comb_proc via
        -- CLNW_scan_request_next (avoids multiple drivers and creates a
        -- single-cycle pulse when requested).

        -- Update C or base_sq after Montgomery multiplication completes during PRECOMPUTE
        if montgomery_done = '1' and state = PRECOMPUTE then
            if precomp_first_done = '0' then
                -- first result is base^2; and mark done via comb_proc
                P_reg <= montgomery_S;
                precomp_first_done <= '1';
            else
                -- subsequent results are odd powers; keep in C_reg as last_odd
                C_reg <= montgomery_S;
            end if;
        end if;

        -- Update P after Montgomery multiplication completes during WINDOW_SQUARE_START or WINDOW_MULT_START
        if montgomery_done = '1' and (state = WINDOW_SQUARE_START or state = WINDOW_MULT_START) then
            P_reg <= montgomery_S;
        end if;

        -- Sample BRAM read data into P_reg when in WINDOW_WAIT_MEM
        if state = WINDOW_WAIT_MEM then
            -- BRAM index 0 contains Mont(base), other indices contain odd powers
            C_reg <= precomp_dout;
            if init_window_done = '0' then
                -- First window: load into C_reg
                P_reg <= precomp_dout;
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

        -- done_reg is registered from comb_proc via done_reg_next
    end if;
end process;

-- MSB scan process: runs when msb_scan_active = '1', searches key from MSB down
msb_scan_proc: process(clk, reset_n)
begin
    if reset_n = '0' then
        msb_scan_ptr <= C_block_size - 1;
        msb_found <= '0';
        msb_scan_active <= '0';
    elsif rising_edge(clk) then
        -- Make msb_found a one-clock pulse: clear it each cycle then assert when found
        msb_found <= '0';

        -- Initialize MSB scan when requested by comb_proc
        if msb_scan_request = '1' then
            msb_scan_ptr <= C_block_size - 1;
            msb_scan_active <= '1';
        elsif msb_scan_active = '1' and msb_found = '0' then
            -- Walk down the key bits until we find a '1' or reach bit 0
            if key(msb_scan_ptr) = '1' then
                -- Pulse msb_found for a single clock and stop the scan
                msb_found <= '1';
                msb_scan_active <= '0';
            else
                if msb_scan_ptr > 0 then
                    msb_scan_ptr <= msb_scan_ptr - 1;
                else
                    -- Reached bit 0: pulse msb_found and stop the scan
                    msb_found <= '1';
                    msb_scan_active <= '0';
                end if;
            end if;
        end if;
    end if;
end process msb_scan_proc;

-- Instantiate CLNW scanner component (moved to clnw_scanner.vhd)
clnw_inst : entity work.clnw_scanner
    generic map (
        C_block_size => C_block_size,
        window_size  => window_size
    )
    port map (
        clk => clk,
        reset_n => reset_n,
        key => key,
        curr_pos => MSB_index,
        CLNW_scan_request => CLNW_scan_request,
        CLNW_found        => CLNW_found,
        window_LSB        => window_LSB,
        window_MSB        => window_MSB,
        zero_window_count => zero_window_count,
        window_type       => clnw_window_type
    );


comb_proc : process(all)
    variable start_idx : integer;
    variable window_val : integer;
begin
    -- ========================================================================
    -- COMPREHENSIVE DEFAULTS (Prevent latches and ensure safe initial values)
    -- ========================================================================
    
    -- Initialize local variables
    start_idx := 0;
    window_val := 0;
    
    -- Default: hold current state
    next_state <= state;
    
    -- Default: maintain all registered counter/index values (no change)
    MSB_index_next <= MSB_index;
    NW_next <= NW;
    precomp_index_next <= precomp_index;
    precomp_first_done_next <= precomp_first_done;
    precomp_base1_written_next <= precomp_base1_written;
    square_count_next <= square_count;
    exp_done_next <= exp_done;
    init_window_done_next <= init_window_done;
    window_type_next <= window_type;
    
    -- Default: all control request signals deasserted
    mont_request <= '0';
    msb_scan_request <= '0';
    data_accept <= '0';

    -- Default: CLNW scanner control (registered pulse driven from _next)
    CLNW_scan_request_next <= '0';

    -- Pulse CLNW_scan_request for one cycle when msb_found pulses
    if msb_found = '1' then
        CLNW_scan_request_next <= '1';
        -- Capture the scanned MSB position into the controller index
        MSB_index_next <= msb_scan_ptr;
    end if;
    
    -- Default: handshake signals (not ready)
    ready_in <= '0';
    -- Default: hold done_reg steady unless changed by state logic
    done_reg_next <= done_reg;
    
    -- Default: Montgomery multiplier control (use pulse). Drive A/B from
    -- the registered values so they remain stable while the core is running
    -- (avoids A/B becoming zeros during WINDOW_WAIT_MONT). Specific state
    -- branches may override these when a different source is needed.
    montgomery_enable <= mont_enable_pulse;

    montgomery_N <= modulus;
    -- Default A/B drive from registered C_reg/P_reg to avoid inferred latches
    montgomery_A <= C_reg;
    montgomery_B <= P_reg;
    
    -- Default: Memory control signals (no write, address 0)
    precomp_we <= '0';
    -- Default precomp address must be driven to avoid latch inference
    precomp_addr <= (others => '0');
    precomp_din <= (others => '0');
    
    -- Default: Result output follows P_reg
    result <= montgomery_S;
    
    -- ========================================================================
    -- STATE-SPECIFIC LOGIC AND NEXT-STATE COMPUTATION
    -- ========================================================================
    case state is
        when IDLE =>
            -- ===== IDLE: Wait for start signal and advertise ready =====
            ready_in <= '1';  -- Advertise ready to accept new inputs
            
            if start = '1' then
                data_accept <= '1';
                msb_scan_request <= '1';  -- Start MSB scan for incoming key
                next_state <= CONV_2_MONT;
                precomp_index_next <= 0;
                precomp_first_done_next <= '0';
                init_window_done_next <= '0';
                precomp_base1_written_next <= '0';
                MSB_index_next <= C_block_size - 1;  -- Initialize MSB index to max
                done_reg_next <= '0';
                
            end if;
            
        when CONV_2_MONT =>
            -- ===== CONV_2_MONT: Convert message to Montgomery domain =====
            -- Operation: C_reg = R² * message (mod N)
            mont_request <= '1';
            montgomery_A <= C_reg;  -- R_squared_mod_n (loaded in seq proc)
            montgomery_B <= P_reg;  -- message (loaded in seq proc)
            montgomery_N <= modulus;
            
            if montgomery_done = '1' then
                next_state <= PRECOMPUTE;
            end if;

        when PRECOMPUTE =>
            -- ===== PRECOMPUTE: Calculate odd powers base³, base⁵, ... base^(2^w-1) =====
            -- Strategy: 1) Compute base² first (stored in base_sq_reg)
            --           2) Compute base³ = base² * base
            --           3) Compute base^(2k+1) = base^(2k-1) * base² (chain from last odd)
            
            montgomery_N <= modulus;
            -- If we haven't written base^1 into BRAM yet, do that first (address 1)
            if precomp_base1_written = '0' then
                precomp_we <= '1';
                -- Store Mont(base) at address = 1 (direct exponent addressing)
                precomp_addr <= std_logic_vector(to_unsigned(1, precomp_addr'length));
                -- Write montgomery_S (Mont(base) from CONV_2_MONT) directly to BRAM
                precomp_din <= montgomery_S;  -- write Mont(base) into index 1
                precomp_base1_written_next <= '1';
                next_state <= WAIT_MEM_WRITE;
            else
                if precomp_first_done = '0' then
                    -- First multiplication: compute base² = Mont(base) * Mont(base)
                    mont_request <= '1';
                    montgomery_A <= C_reg;  -- base in Montgomery form
                    montgomery_B <= P_reg;  -- base in Montgomery form
                else
                    if precomp_index = 1 then
                        -- Second multiplication after base^2: compute base^3 = base^2 * base
                        mont_request <= '1';
                        montgomery_A <= C_reg;
                        montgomery_B <= P_reg;
                    else
                        -- Subsequent multiplications: next_odd = last_odd * base^2
                        mont_request <= '1';
                        montgomery_A <= C_reg;        -- last odd power (from C_reg)
                        montgomery_B <= P_reg;  -- base²
                    end if;
                end if;
            end if;
            
            if montgomery_done = '1' then
                if precomp_first_done = '0' and precomp_index = 1 then
                    -- First result (base²) saved in seq proc; stay to compute base³
                    precomp_first_done_next <= '1';
                    next_state <= PRECOMPUTE;
                else
                    -- Odd power computed; proceed to write to memory
                    next_state <= WAIT_MEM_WRITE;
                end if;
            end if;
            
        
        when WAIT_MEM_WRITE =>
            -- ===== WAIT_MEM_WRITE: 2-cycle BRAM write for precomputed values =====
            -- Memory mapping: index i corresponds to exponent = 2*i + 1 (i=0 => exp=1, i=1 => exp=3,...)
            precomp_we <= '1';
            -- Write montgomery_S to BRAM at address = exponent value
            -- precomp_index maps entries 0.. -> exponents 1,3,5,...; compute exponent = 2*precomp_index + 1
            precomp_addr <= std_logic_vector(to_unsigned(2 * precomp_index + 1, precomp_addr'length));
            precomp_din <= montgomery_S;
            if wait_mem_ctr = 0 then
                -- First cycle: stay for second write cycle
                next_state <= WAIT_MEM_WRITE;
            else
                -- Second cycle: determine if more precomputation needed
                -- Current exponent = 2*precomp_index + 1
                if (2 * precomp_index + 1) >= (2**window_size - 1) then
                    -- All powers computed; proceed to exponentiation
                    next_state <= WINDOW_SCAN;
                else
                    -- More powers to compute
                    next_state <= PRECOMPUTE;
                end if;

                -- Advance index if more entries remain
                if (2 * precomp_index + 1) < (2**window_size - 1) then
                    precomp_index_next <= precomp_index + 1;
                end if;
            end if;

        when WINDOW_SCAN =>
            -- ===== WINDOW_SCAN: Determine next window type (zero/non-zero) =====
                window_type_next <= clnw_window_type;
            if(CLNW_found = '1') then
                -- Capture window type from CLNW scanner into registered next value
                if MSB_index < 0 then
                    -- Reached end of exponent; convert result to normal domain

                    next_state <= CONV_2_NORMAL;
                else
                    CLNW_scan_request_next <= '1';  -- Start CLNW scan for next window (one-cycle pulse)
                    if clnw_window_type = 0 then
                        -- Zero window: Prepare for squaring
                        next_state <= WINDOW_SQUARE_START;
                        -- Advance the MSB index (processing pointer for exponent)
                        MSB_index_next <= MSB_index - zero_window_count;
                        square_count_next <= zero_window_count;

                    else
                        -- Non-zero window: Process multi-bit window
                        NW_next <= to_integer(unsigned(key(window_MSB downto window_LSB)));
                        MSB_index_next <= window_LSB - 1;
                        next_state <= WINDOW_READ_MEM;
                        square_count_next <= window_size;
                    end if;
                end if;
            end if;

        when WINDOW_READ_MEM =>
            -- ===== WINDOW_READ_MEM: Read precomputed power from BRAM =====
            -- Memory mapping: direct exponent addressing for odd NW >= 1
            -- BRAM address 1 now holds base^1 (Mont(base)) so NW=1 maps to address 1
            -- Direct exponent addressing: NW is the exponent value (odd >= 1), so use it as address
            if NW >= 1 then
                precomp_addr <= std_logic_vector(to_unsigned(NW, precomp_addr'length));
            else
                precomp_addr <= (others => '0');
            end if;
            next_state <= WINDOW_WAIT_MEM;

        when WINDOW_WAIT_MEM =>
            -- ===== WINDOW_WAIT_MEM: Wait for BRAM read latency =====
            -- Data sampled into C_reg by sequential process

            if init_window_done = '1' then
                -- Normal window processing: proceed to squaring
                next_state <= WINDOW_SQUARE_START;
            else
                init_window_done_next <= '1';
                next_state <= WINDOW_SCAN;
            end if;
            
        when WINDOW_SQUARE_START =>
            -- ===== WINDOW_SQUARE_START: Begin squaring sequence =====
            mont_request <= '1';
            montgomery_A <= P_reg;
            montgomery_B <= P_reg;
            montgomery_N <= modulus;

            if montgomery_done = '1' then
                square_count_next <= square_count - 1;
                if square_count = 1 then
                    -- Squaring complete
                    if window_type = 1 then
                        -- Non-zero window: multiply by precomputed value
                        next_state <= WINDOW_MULT_START;
                    else
                        -- Zero window: done, scan for next window
                        next_state <= WINDOW_SCAN;
                    end if;
                end if;
            end if;

        when WINDOW_MULT_START =>
            -- ===== WINDOW_MULT_START: Multiply by precomputed window value =====
            mont_request <= '1';
            montgomery_A <= P_reg;
            montgomery_B <= C_reg;  -- Precomputed value from BRAM
            montgomery_N <= modulus;

            if montgomery_done = '1' then
                next_state <= WINDOW_SCAN;
            end if;

        when CONV_2_NORMAL =>
            -- ===== CONV_2_NORMAL: Convert from Montgomery to normal domain =====
            -- Operation: result = P_reg * 1 (mod N)
            mont_request <= '1';
            montgomery_A <= P_reg;
            montgomery_B <= std_logic_vector(to_unsigned(1, montgomery_B'length));
            montgomery_N <= modulus;
            if montgomery_done = '1' then
                next_state <= FINISHED;
            end if;

        when FINISHED =>
            -- ===== FINISHED: Assert done and return to IDLE =====
            -- Assert valid/done and hold until consumer accepts (ready_out)
            done_reg_next <= '1';
            if ready_out = '1' then
                done_reg_next <= '0';
                next_state <= IDLE;
            end if;
    end case;
end process;

-- Drive output port from registered signal to avoid multiple drivers
done <= done_reg;

end RTL;
