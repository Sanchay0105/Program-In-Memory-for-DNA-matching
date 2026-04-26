`timescale 1ns / 1ps

module alu_decoder(
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic       funct7_bit5, // This is instruction bit [30]

    output logic [3:0] alu_ctrl
);

    // =========================================================================
    // Copy the localparams from alu_core.sv so they match perfectly
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

    always_comb begin
        // Default to ADD just in case
        alu_ctrl = ALU_ADD;

        case(opcode)
            // ----------------------------------------------------
            // LOAD (lw) and STORE (sw)
            // ----------------------------------------------------
            // To calculate a memory address, we add the base register to the immediate offset.
            7'b0000011, // Load
            7'b0100011: // Store (This triggers our PIM unit!)
                alu_ctrl = ALU_ADD;

            // ----------------------------------------------------
            // R-TYPE INSTRUCTIONS (e.g., add, sub, and, xor)
            // Both operands are registers.
            // ----------------------------------------------------
            7'b0110011: begin
                case(funct3)
                    3'b000: alu_ctrl = (funct7_bit5) ? ALU_SUB : ALU_ADD; // sub vs add
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = (funct7_bit5) ? ALU_SRA : ALU_SRL; // sra vs srl
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                endcase
            end

            // ----------------------------------------------------
            // I-TYPE INSTRUCTIONS (e.g., addi, andi, xori)
            // One register, one immediate.
            // ----------------------------------------------------
            7'b0010011: begin
                case(funct3)
                    3'b000: alu_ctrl = ALU_ADD; // addi
                    3'b001: alu_ctrl = ALU_SLL; // slli
                    3'b010: alu_ctrl = ALU_SLT; // slti
                    3'b011: alu_ctrl = ALU_SLTU; // sltiu
                    3'b100: alu_ctrl = ALU_XOR; // xori
                    3'b101: alu_ctrl = (funct7_bit5) ? ALU_SRA : ALU_SRL; // srai vs srli
                    3'b110: alu_ctrl = ALU_OR;  // ori
                    3'b111: alu_ctrl = ALU_AND; // andi
                endcase
            end
            
            // ----------------------------------------------------
            // BRANCH INSTRUCTIONS (e.g., beq, bne)
            // We subtract the registers. If the zero_flag goes high, they are equal!
            // ----------------------------------------------------
            7'b1100011: begin
                alu_ctrl = ALU_SUB; 
            end
            7'b0001011: begin // CUSTOM-0 (pim.align)
                alu_ctrl = ALU_PIM; 
            end

            default: alu_ctrl = ALU_ADD;
        endcase
    end

endmodule