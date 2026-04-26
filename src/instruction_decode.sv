`timescale 1ns / 1ps

module instruction_decode(
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from Fetch Stage
    input  logic [31:0] instruction,

    // Writeback Interface (Data coming back from the end of the pipeline)
    input  logic [4:0]  wb_rd,     // Which register to write to
    input  logic [31:0] wb_data,   // The data to write
    input  logic        wb_we,     // Write Enable flag

    // Outputs to Execute Stage
    output logic [31:0] rs1_data,  // Data read from Source Register 1
    output logic [31:0] rs2_data,  // Data read from Source Register 2
    output logic [31:0] imm_ext,   // Sign-extended Immediate value

    // Control Signals routing to other stages
    output logic        alu_src,    // 0: use rs2_data, 1: use imm_ext
    output logic        mem_we,     // 1: Write to Memory (Store)
    output logic        mem_to_reg, // 1: Read from Memory (Load)
    output logic        reg_we      // 1: Write to Register File
);

// =========================================================================
    // 1. Instruction Slicing (Explicit Wiring)
    // =========================================================================
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];

    // =========================================================================
    // 2. The Register File (32 registers, 32-bits wide)
    // =========================================================================
    logic [31:0] reg_file [0:31];

    // Register Read: Hardware reads are instant (Combinational).
    // In RISC-V, Register 0 (x0) is hardwired to always be 0.
    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : reg_file[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : reg_file[rs2];

    // Register Write: Updates happen on the clock edge (Sequential).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers to 0 on reset
            for (int i = 1; i < 32; i++) reg_file[i] <= 32'd0;
        end else if (wb_we && wb_rd != 5'd0) begin
            // Never allow writing to x0
            reg_file[wb_rd] <= wb_data;
        end
    end

    // =========================================================================
    // 3. Immediate Generator
    // =========================================================================
    // Reconstructs split immediate values back into a 32-bit number
    always_comb begin
        case(opcode)
            7'b0010011: imm_ext = {{20{instruction[31]}}, instruction[31:20]}; // I-Type (ADDI)
            7'b0000011: imm_ext = {{20{instruction[31]}}, instruction[31:20]}; // I-Type (LW)
            7'b0100011: imm_ext = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // S-Type (SW)
            // Default to zero to prevent unlatched floating wires
            default:    imm_ext = 32'd0; 
        endcase
    end

// =========================================================================
    // 4. Main Control Unit
    // =========================================================================
    // Generates the traffic signals that control the multiplexers in later stages
    always_comb begin
        // Default everything to zero for safety
        alu_src    = 1'b0;
        mem_we     = 1'b0;
        mem_to_reg = 1'b0;
        reg_we     = 1'b0;

        case(opcode)
            7'b0110011,       // Standard R-Type (e.g., ADD)
            7'b0001011: begin // CUSTOM-0 (Our new pim.align instruction!)
                reg_we  = 1'b1; 
            end
            7'b0010011: begin // I-Type (e.g., ADDI)
                alu_src = 1'b1; // Tell ALU to use Immediate, not rs2
                reg_we  = 1'b1;
            end
            7'b0000011: begin // Load Word (LW)
                alu_src    = 1'b1; 
                mem_to_reg = 1'b1; // Tell Writeback to use Memory Data, not ALU
                reg_we     = 1'b1;
            end
            7'b0100011: begin // Store Word (SW) 
                alu_src = 1'b1;
                mem_we  = 1'b1; // Turn on Write Enable for Memory
            end
            default: begin
                // Do nothing if opcode is unknown
            end
        endcase
    end

endmodule