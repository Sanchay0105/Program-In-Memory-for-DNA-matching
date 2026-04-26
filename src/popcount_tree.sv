`timescale 1ns / 1ps

import genomic_pkg::*;

module popcount_tree #(
    parameter int BASES = PIM_PARALLEL_BASES,
    // $clog2 calculates the number of bits needed to store the maximum possible sum.
    // E.g., if BASES=16, the max sum is 16. We need 5 bits to store the number 16.
    parameter int OUT_WIDTH = $clog2(BASES) + 1 
)(
    input  logic [BASES-1:0]     mismatch_vector,
    output logic [OUT_WIDTH-1:0] hamming_distance
);

    // always_comb means this is pure combinational logic (no clocks)
    always_comb begin
        
        // Initialize our output to 0 before the calculation
        hamming_distance = '0; 
        
        // VIVADO MAGIC: 
        // Even though this looks like a software "for loop", Vivado's synthesis engine 
        // is smart enough to recognize this pattern. It will automatically optimize 
        // and physicaly build the parallel "Adder Tree" we described above!
        for (int i = 0; i < BASES; i++) begin
            hamming_distance = hamming_distance + mismatch_vector[i];
        end
        
    end

endmodule