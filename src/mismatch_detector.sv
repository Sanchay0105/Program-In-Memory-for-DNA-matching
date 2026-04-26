`timescale 1ns / 1ps

// Import the package we just created so we know what "PIM_PARALLEL_BASES" is
import genomic_pkg::*;

module mismatch_detector #(
    // We use the parameter from the package, but allow it to be overridden if needed
    parameter int BASES = PIM_PARALLEL_BASES
)(
    // Inputs: We use a 2D packed array. 
    // This creates 'BASES' number of elements, where each element is 2 bits wide.
    input  logic [BASES-1:0][1:0] ref_seq,   
    input  logic [BASES-1:0][1:0] query_seq, 
    
    // Output: A 1D array. 1 bit per base. (1 = Mismatch, 0 = Match)
    output logic [BASES-1:0]      mismatch_vector
);

    // always_comb tells the synthesis tool (Vivado) to build pure hardware gates, 
    // not memory flip-flops.
    always_comb begin
        // In hardware, this 'for' loop does NOT execute over time. 
        // Vivado will "unroll" this loop and physically stamp out 'BASES' number of comparator circuits side-by-side.
        for (int i = 0; i < BASES; i++) begin
            
            // Compare the 2-bit base from the Reference to the Query
            if (ref_seq[i] != query_seq[i]) begin
                mismatch_vector[i] = 1'b1; // Mismatch detected!
            end else begin
                mismatch_vector[i] = 1'b0; // Perfect match
            end
            
        end
    end

endmodule