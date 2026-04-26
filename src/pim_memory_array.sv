`timescale 1ns / 1ps

import genomic_pkg::*;

module pim_memory_array #(
    parameter int BASES = PIM_PARALLEL_BASES,
    parameter int DATA_W = PIM_DATA_WIDTH
)(
    input  logic              clk,
    input  logic              rst_n,      // Active-low reset
    
    // Standard Bus Interface Signals (from CPU)
    input  logic              write_en,
    input  logic [1:0]        addr,       // 00: Ref, 01: Query
    input  logic [DATA_W-1:0] write_data,
    
    // Custom PIM Control Signals (from CPU Decoder)
    input  logic              compute_req, // Trigger the calculation
    
    // Outputs back to CPU
    output logic [DATA_W-1:0]     read_data,
    output logic [$clog2(BASES):0] pim_result,
    output logic                  compute_done
);

    // 1. Internal Memory Registers (The "SRAM")
    // We treat these as a 2D array of 2-bit DNA bases
    logic [BASES-1:0][1:0] ref_reg;
    logic [BASES-1:0][1:0] query_reg;

    // 2. Internal Wires for the Compute Logic
    logic [BASES-1:0]       mismatch_vec;
    logic [$clog2(BASES):0] hamming_dist;

    // 3. Instantiate our custom logic INSIDE the memory module
    mismatch_detector #(.BASES(BASES)) u_detector (
        .ref_seq(ref_reg),
        .query_seq(query_reg),
        .mismatch_vector(mismatch_vec)
    );

    popcount_tree #(.BASES(BASES)) u_tree (
        .mismatch_vector(mismatch_vec),
        .hamming_distance(hamming_dist)
    );

    // 4. Memory Write Logic (Sequential Hardware)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ref_reg   <= '0;
            query_reg <= '0;
        end else if (write_en) begin
            case (addr)
                2'b00: ref_reg   <= write_data; // CPU writes Reference
                2'b01: query_reg <= write_data; // CPU writes Query
            endcase
        end
    end

    // 5. Memory Read Logic (For standard CPU memory fetching)
    always_comb begin
        case (addr)
            2'b00: read_data = ref_reg;
            2'b01: read_data = query_reg;
            default: read_data = '0;
        endcase
    end

    // 6. PIM Compute Pipeline Stage
    // Even though the adder tree is combinational (instant), we register 
    // the output to a flip-flop so it safely aligns with the CPU clock cycle.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pim_result <= '0;
            compute_done <= 1'b0;
        end else if (compute_req) begin
            pim_result <= hamming_dist; // Capture the final answer
            compute_done <= 1'b1;       // Signal CPU to un-stall pipeline
        end else begin
            compute_done <= 1'b0;
        end
    end

endmodule