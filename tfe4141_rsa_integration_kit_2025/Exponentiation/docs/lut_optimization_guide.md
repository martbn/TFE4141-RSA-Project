# LUT Optimization Guide for FPGA Designs

## 🎯 **Top LUT Reduction Strategies**

### **1. Use Block RAM Instead of Distributed RAM**
```vhdl
-- BAD: Uses many LUTs for storage
signal large_array : std_logic_vector(1023 downto 0);

-- GOOD: Uses dedicated BRAM
type ram_t is array (0 to 31) of std_logic_vector(31 downto 0);
signal operand_ram : ram_t;
```

### **2. Optimize State Machine Encoding**
```vhdl
-- BAD: Default one-hot encoding (uses many LUTs)
type state_type is (IDLE, LOAD, INIT, COMPUTE, SUB, DONE);

-- GOOD: Binary encoding with explicit attribute
type state_type is (IDLE, COMPUTE, DONE);
attribute ENUM_ENCODING : string;
attribute ENUM_ENCODING of state_type : type is "00 01 10";
```

### **3. Reduce Multiplexer Complexity**
```vhdl
-- BAD: Complex 4-input mux uses many LUTs
result <= A + B + N when sel = "11" else
          A + B     when sel = "10" else  
          A + N     when sel = "01" else
          A;

-- GOOD: Sequential additions
temp1 <= A + B when add_b = '1' else A;
result <= temp1 + N when add_n = '1' else temp1;
```

### **4. Use DSP48 Blocks for Arithmetic**
```vhdl
-- Add synthesis attributes to encourage DSP usage
signal adder_result : unsigned(47 downto 0);
attribute USE_DSP : string;
attribute USE_DSP of adder_result : signal is "yes";
```

### **5. Pack Related Signals**
```vhdl
-- BAD: Separate control signals
signal enable_reg : std_logic;
signal done_reg : std_logic;  
signal active_reg : std_logic;

-- GOOD: Pack into single register
signal control_reg : std_logic_vector(7 downto 0);
alias enable_reg : std_logic is control_reg(0);
alias done_reg   : std_logic is control_reg(1);
alias active_reg : std_logic is control_reg(2);
```

### **6. Optimize Counter Width**
```vhdl
-- BAD: Oversized counter
signal counter : integer range 0 to 1024;  -- Uses ~10 LUTs

-- GOOD: Minimum required bits  
signal counter : unsigned(7 downto 0);     -- Uses ~8 LUTs
```

### **7. Simplify Reset Logic**
```vhdl
-- BAD: Async reset for many signals
if reset = '1' then
    reg1 <= '0'; reg2 <= '0'; reg3 <= '0'; -- Each uses LUTs

-- GOOD: Sync reset or reset only critical signals
if rising_edge(clk) then
    if reset = '1' then
        critical_reg <= '0';
    end if;
end if;
```

## 🔧 **Vivado-Specific Optimizations**

### **Synthesis Directives:**
```vhdl
-- Force BRAM usage
attribute RAM_STYLE : string;
attribute RAM_STYLE of large_memory : signal is "block";

-- Force register usage (not LUT-based)
attribute SHREG_EXTRACT : string;
attribute SHREG_EXTRACT of shift_reg : signal is "no";

-- Optimize for area vs speed
attribute OPTIMIZATION : string;
attribute OPTIMIZATION of my_signal : signal is "AREA";
```

### **TCL Commands for Synthesis:**
```tcl
# Set global optimization strategy
set_property STRATEGY Area_Explore [get_runs synth_1]

# Force specific resource usage
set_property -dict {RAM_STYLE block} [get_cells -filter {REF_NAME == ram_component}]

# Report resource usage after synthesis
report_utilization -hierarchical -file lut_usage.rpt
```

## 📊 **Before/After Comparison**

### **Original Design Estimates:**
- **LUTs**: ~1500 (large muxes, distributed RAM)
- **FFs**: ~800 
- **BRAM**: 0
- **DSP**: 0

### **Optimized Design Targets:**
- **LUTs**: ~600-800 (60% reduction)
- **FFs**: ~600
- **BRAM**: 2-4 blocks  
- **DSP**: 4-8 blocks

## 🎯 **Montgomery-Specific Optimizations**

### **1. Serial Addition Instead of Parallel**
```vhdl
-- Instead of: result = A + B + N (wide logic)
-- Use: temp = A + B, then result = temp + N (narrower)
```

### **2. Bit-Serial Processing**
```vhdl
-- Process one bit at a time instead of full-width operations
signal current_bit : std_logic;
current_bit <= A_reg(counter);
```

### **3. Shared Resources**
```vhdl
-- Use same adder for different operations
shared_adder <= operand1 + operand2;  -- Reused for A+B and result+N
```

## 🔍 **How to Check LUT Usage**

### **In Vivado:**
1. After synthesis: **Reports → Utilization → Utilization Report**
2. Look for "CLB LUTs" usage
3. Check hierarchical breakdown to find high-usage modules

### **Target Goals:**
- **Small design**: <500 LUTs
- **Medium design**: 500-1500 LUTs  
- **Large design**: 1500+ LUTs
- **Your Montgomery**: Aim for <1000 LUTs

The optimized version should reduce your LUT usage by 40-60% compared to the original!