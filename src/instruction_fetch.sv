`timescale 1ns / 1ps

module instruction_fetch(
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals from later stages (for branches/jumps)
    input  logic        pc_sel,      // 0 = PC+4, 1 = Branch Target
    input  logic [31:0] branch_addr, // The calculated address to jump to
    
    // Outputs
    output logic [31:0] pc_current,
    output logic [31:0] instruction
);

    // =========================================================================
    // 1. The Program Counter (PC) Register
    // =========================================================================
    logic [31:0] pc_next;
    logic [31:0] pc_plus_4;

    // The +4 Adder (Combinational)
    assign pc_plus_4 = pc_current + 32'd4;

    // The Mux to choose the next PC (Combinational)
    always_comb begin
        if (pc_sel) begin
            pc_next = branch_addr; // We are jumping/branching!
        end else begin
            pc_next = pc_plus_4;   // Normal execution, go to next instruction
        end
    end

    // The actual PC Flip-Flop (Sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Standard RISC-V boot address is often 0x00000000
            pc_current <= 32'h00000000; 
        end else begin
            pc_current <= pc_next;
        end
    end

    // =========================================================================
    // 2. The Instruction Memory (IMEM / ROM)
    // =========================================================================
    // For this FPGA implementation, we will infer a Block RAM (BRAM) 
    // to hold our program code. Let's make it 1024 words (4KB).
    logic [31:0] rom_array [0:1023];

    // Read logic (Combinational for a single-cycle core)
    // Note: PC increments by 4 (bytes), but our array is accessed by Word index.
    // We shift the PC right by 2 bits (pc_current[11:2]) to convert byte address to word index.
    assign instruction = rom_array[pc_current[11:2]];

    // Initialization (Load the compiled C code into the ROM before synthesis/simulation)
    initial begin
        // Using the absolute path guarantees Vivado finds your machine code!
        $readmemh("C:/Users/satyam/Documents/FinalYearProject/genomic_pim_aligner/program.mem", rom_array);
    end

endmodule