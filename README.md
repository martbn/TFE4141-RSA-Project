# TFE4141 RSA Accelerator Project

A hardware implementation of RSA encryption/decryption accelerator using Montgomery multiplication, developed for the TFE4141 Digital Systems Design course.

## 🏗️ Architecture Overview

This project implements a complete RSA accelerator system with the following components:

### Core Components
- **Montgomery Datapath** (`montgomery_datapath.vhd`) - Pipelined Montgomery multiplication unit
- **Exponentiation Module** (`exponentiation.vhd`) - Modular exponentiation using Montgomery ladder
- **RSA Core** (`rsa_core.vhd`) - Top-level RSA processing unit
- **RSA Accelerator** - Complete system with AXI interfaces

### Key Features
- ✅ **Pipelined Montgomery Multiplier** - Optimized for high frequency operation
- ✅ **256-bit RSA Support** - Configurable block size via generics
- ✅ **VHDL1997 Compatible** - Synthesizable in Vivado
- ✅ **AXI4-Stream Interface** - Standard bus interface
- ✅ **Comprehensive Testbenches** - Verification infrastructure

## 📁 Project Structure

```
tfe4141_rsa_integration_kit_2025/
├── Exponentiation/           # Exponentiation module
│   ├── source/
│   │   ├── montgomery_datapath.vhd    # Montgomery multiplication datapath
│   │   └── exponentiation.vhd         # Modular exponentiation
│   └── testbench/
├── RSA_accelerator/          # Complete RSA system
│   ├── source/              # RTL source files
│   └── testbench/          # Test infrastructure
├── RSA_soc/                 # System-on-chip integration
└── Master_constraints/      # FPGA constraints
```

## 🚀 Getting Started

### Prerequisites
- Xilinx Vivado 2019.1 or later
- PYNQ-Z1 board (or compatible Zynq-7000 board)
- Git for version control

### Building the Project

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/tfe4141-rsa-accelerator.git
   cd tfe4141-rsa-accelerator
   ```

2. **Generate Vivado projects:**
   ```tcl
   # In Vivado TCL console
   source generate_IP.tcl
   source regenerate_projects.tcl
   ```

3. **Open individual projects:**
   - Exponentiation: `Exponentiation/Exponentiation/Exponentiation.xpr`
   - RSA Accelerator: `RSA_accelerator/RSA_accelerator/RSA_accelerator.xpr`

## 🔧 Montgomery Datapath Implementation

The core of this implementation is a 4-stage pipelined Montgomery multiplier:

### Pipeline Stages
1. **Stage 1**: Operand selection and first addition
2. **Stage 2**: Modulus addition based on LSB
3. **Stage 3**: Division by 2 (right shift)
4. **Stage 4**: Result registration

### Interface
```vhdl
entity montgomery_datapath is
    generic (C_block_size : integer := 256);
    port (
        clk, reset_n     : in std_logic;
        A, B, N          : in std_logic_vector(C_block_size-1 downto 0);
        load_A_reg       : in std_logic;
        load_B_reg       : in std_logic;
        load_N_reg       : in std_logic;
        load_result_reg  : in std_logic;
        result           : out std_logic_vector(C_block_size-1 downto 0)
    );
end montgomery_datapath;
```

## 📊 Performance Characteristics

- **Target Frequency**: 100+ MHz (pipelined design)
- **Latency**: 4 clock cycles per Montgomery step
- **Throughput**: One Montgomery multiplication per clock (after initial latency)
- **Resource Usage**: ~2x C_block_size LUTs + ~4x C_block_size registers

## 🧪 Testing

### Run Testbenches
```tcl
# In Vivado simulator
run_simulation -testbench montgomery_datapath_tb
run_simulation -testbench exponentiation_tb
```

### Test Vectors
Located in `RSA_accelerator/testbench/rsa_tests/`:
- Short tests: Basic functionality
- Long tests: Extended validation

## 🎯 Design Decisions

### Why Montgomery Multiplication?
- **Efficiency**: Avoids expensive division operations
- **Hardware Friendly**: Uses shifts and additions
- **Scalable**: Works with any bit width

### Why Pipelined?
- **Timing**: Breaks critical path for higher frequency
- **Throughput**: Better overall performance despite increased latency
- **Synthesis**: Better resource utilization in modern FPGAs

## 🤝 Contributing

This is an academic project. If you find issues or improvements:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description

## 📝 License

This project is released under the [UNLICENSE](UNLICENSE) - free and unencumbered software released into the public domain.

## 👥 Authors

- Course: TFE4141 Design of Digital Systems 1 (DDS1)
- Institution: Norwegian University of Science and Technology (NTNU)
- Department: Electronic Systems

## 🔗 References

- Montgomery, P.L. "Modular multiplication without trial division"
- Koç, Ç.K. "Analyzing and Comparing Montgomery Multiplication Algorithms"
- Xilinx Vivado Design Suite User Guide