`timescale 1ns / 1ps

module riscv_core_v2(
    input  logic        clk,
    input  logic        rst_n,

    // =========================================================================
    // The Data Memory Bus 
    // =========================================================================
    output logic        dmem_valid, 
    output logic        dmem_we,    
    output logic [31:0] dmem_addr,  
    output logic [31:0] dmem_wdata, 
    
    input  logic [31:0] dmem_rdata, 
    input  logic        dmem_ready  
);

    // Fetch Wires
    logic [31:0] pc_current;
    logic [31:0] instruction;
    logic        pc_sel;
    logic [31:0] branch_addr;

    // Decode Wires
    logic [31:0] rs1_data, rs2_data, imm_ext;
    logic        alu_src, mem_we, mem_to_reg, reg_we;

    // ALU Wires
    logic [3:0]  alu_ctrl;
    logic [31:0] alu_operand_b, alu_result;
    logic        zero_flag;

    // Writeback Wires
    logic [31:0] wb_data;
    logic [4:0]  wb_rd;

    // =========================================================================
    // Instruction Slicing (EXPLICIT WIRES - NO STATIC INIT!)
    // =========================================================================
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       funct7_bit5;

    assign opcode      = instruction[6:0];
    assign funct3      = instruction[14:12];
    assign funct7_bit5 = instruction[30];
    assign wb_rd       = instruction[11:7]; 

    // =========================================================================
    // Module Instantiations 
    // =========================================================================

    instruction_fetch u_fetch (
        .clk(clk),
        .rst_n(rst_n),
        .pc_sel(pc_sel),
        .branch_addr(branch_addr),
        .pc_current(pc_current),
        .instruction(instruction)
    );

    instruction_decode u_decode (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .wb_rd(wb_rd),
        .wb_data(wb_data),
        .wb_we(reg_we), 
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm_ext(imm_ext),
        .alu_src(alu_src),
        .mem_we(mem_we),
        .mem_to_reg(mem_to_reg),
        .reg_we(reg_we)
    );

    alu_decoder u_alu_dec (
        .opcode(opcode),
        .funct3(funct3),
        .funct7_bit5(funct7_bit5),
        .alu_ctrl(alu_ctrl)
    );

    assign alu_operand_b = alu_src ? imm_ext : rs2_data;

    alu_core u_alu (
        .operand_a(rs1_data),
        .operand_b(alu_operand_b),
        .alu_ctrl(alu_ctrl),
        .alu_result(alu_result),
        .zero_flag(zero_flag)
    );

    // =========================================================================
    // Branching Logic 
    // =========================================================================
    assign branch_addr = pc_current + imm_ext;

    always_comb begin
        pc_sel = 1'b0; // Default
        if (opcode == 7'b1100011) begin 
            case(funct3)
                3'b000: pc_sel = zero_flag;  
                3'b001: pc_sel = ~zero_flag; 
            endcase
        end
    end

    // =========================================================================
    // Memory Interface 
    // =========================================================================
    assign dmem_valid = mem_we | mem_to_reg; 
    assign dmem_we    = mem_we;              
    assign dmem_addr  = alu_result;          
    assign dmem_wdata = rs2_data;            

    // =========================================================================
    // Writeback Logic 
    // =========================================================================
    assign wb_data = mem_to_reg ? dmem_rdata : alu_result;

endmodule