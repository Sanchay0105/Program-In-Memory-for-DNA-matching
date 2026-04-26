`timescale 1ns / 1ps

module alu_core(
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_ctrl,
    
    output logic [31:0] alu_result,
    output logic        zero_flag
);

    // =========================================================================
    // Control Codes (Must match alu_decoder.sv)
    // =========================================================================
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;
    localparam ALU_PIM  = 4'b1111; // Custom PIM Activation Code

// =========================================================================
    // CUSTOM PIM COPROCESSOR LOGIC (Hardware grafted into the ALU)
    // =========================================================================
    logic [3:0]  pim_out;      // Changed to 4 bits (Max Hamming distance of 8)
    logic [7:0]  match_vector; 
    
    mismatch_detector #(.BASES(8)) u_detector (
        .ref_seq(operand_a[15:0]),   // <--- Slice the bottom 16 bits!
        .query_seq(operand_b[15:0]), // <--- Slice the bottom 16 bits!
        .mismatch_vector(match_vector) 
    );
    
    popcount_tree #(.BASES(8)) u_popcount (
        .mismatch_vector(match_vector),
        .hamming_distance(pim_out) 
    );

    // =========================================================================
    // The Main Execution Block
    // =========================================================================
    always_comb begin
        case(alu_ctrl)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_SUB:  alu_result = operand_a - operand_b;
            ALU_SLL:  alu_result = operand_a << operand_b[4:0];
            ALU_SLT:  alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_SRL:  alu_result = operand_a >> operand_b[4:0];
            ALU_SRA:  alu_result = $signed(operand_a) >>> operand_b[4:0];
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_AND:  alu_result = operand_a & operand_b;
            
            // OUR CUSTOM INSTRUCTION EXECUTION:
            ALU_PIM:  alu_result = {28'd0, pim_out}; // pad with 28 zeros
            
            default:  alu_result = 32'd0;
        endcase
    end

    // Branching uses the zero flag to decide if two numbers are equal
    assign zero_flag = (alu_result == 32'd0) ? 1'b1 : 1'b0;

endmodule