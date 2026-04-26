`timescale 1ns / 1ps

// Import our DNA data types
import genomic_pkg::*;

module tb_top();

    // 1. Declare Virtual Wires to connect to our modules
    logic [PIM_PARALLEL_BASES-1:0][1:0] tb_ref_seq;
    logic [PIM_PARALLEL_BASES-1:0][1:0] tb_query_seq;
    logic [PIM_PARALLEL_BASES-1:0]      tb_mismatch_vector;
    logic [$clog2(PIM_PARALLEL_BASES):0] tb_hamming_dist;

    // 2. Instantiate the Mismatch Detector (The XOR gates)
    mismatch_detector #(
        .BASES(PIM_PARALLEL_BASES)
    ) uut_detector (
        .ref_seq(tb_ref_seq),
        .query_seq(tb_query_seq),
        .mismatch_vector(tb_mismatch_vector)
    );

    // 3. Instantiate the Popcount Tree (The Adder Tree)
    popcount_tree #(
        .BASES(PIM_PARALLEL_BASES)
    ) uut_tree (
        .mismatch_vector(tb_mismatch_vector),
        .hamming_distance(tb_hamming_dist)
    );

    // 4. Apply the Stimulus (The Test Cases)
    initial begin
        $display("\n========================================");
        $display("   STARTING GENOMIC PIM SIMULATION");
        $display("========================================");

        // --- TEST CASE 1: Perfect Match ---
        // Fill all 16 bases with 'A' (00)
        for(int i=0; i<PIM_PARALLEL_BASES; i++) begin
            tb_ref_seq[i]   = BASE_A;
            tb_query_seq[i] = BASE_A;
        end
        
        #10; // Wait 10 nanoseconds for the hardware gates to calculate
        $display("Test 1 (Perfect Match):");
        $display("Mismatch Vector : %b", tb_mismatch_vector);
        $display("Hamming Distance: %0d (Expected: 0)", tb_hamming_dist);
        $display("----------------------------------------");

        // --- TEST CASE 2: 5 Mismatches ---
        // Let's intentionally corrupt 5 bases in the query sequence
        tb_query_seq[0]  = BASE_T; // Mismatch 1
        tb_query_seq[3]  = BASE_C; // Mismatch 2
        tb_query_seq[7]  = BASE_G; // Mismatch 3
        tb_query_seq[10] = BASE_T; // Mismatch 4
        tb_query_seq[15] = BASE_C; // Mismatch 5

        #10; // Wait for logic to recalculate
        $display("Test 2 (5 Mismatches):");
        $display("Mismatch Vector : %b", tb_mismatch_vector);
        $display("Hamming Distance: %0d (Expected: 5)", tb_hamming_dist);
        $display("========================================\n");

        $finish; // Stop the simulation
    end

endmodule