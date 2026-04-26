`timescale 1ns / 1ps

package genomic_pkg;

    // Define the 2-bit encoding for our DNA bases
    typedef enum logic [1:0] {
        BASE_A = 2'b00,
        BASE_T = 2'b01,
        BASE_C = 2'b10,
        BASE_G = 2'b11
    } dna_base_t;

    // Parameter defining how many bases we compare in parallel.
    // Starting with 16 bases (32 bits) for our initial test.
    parameter int PIM_PARALLEL_BASES = 16;
    
    // Derived parameter for the bus width
    parameter int PIM_DATA_WIDTH = PIM_PARALLEL_BASES * 2;

endpackage