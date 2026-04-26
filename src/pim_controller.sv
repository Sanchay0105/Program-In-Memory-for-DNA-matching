`timescale 1ns / 1ps

import genomic_pkg::*;

module pim_controller #(
    parameter int DATA_W = PIM_DATA_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // ----------------------------------------------------
    // 1. CPU Bus Interface (Simplified AXI-Lite / Wishbone)
    // ----------------------------------------------------
    input  logic              bus_valid,  // CPU wants to do something
    input  logic              bus_we,     // 1 = Write, 0 = Read
    input  logic [31:0]       bus_addr,   // The memory address from CPU
    input  logic [DATA_W-1:0] bus_wdata,  // Data coming from CPU
    
    output logic [DATA_W-1:0] bus_rdata,  // Data going back to CPU
    output logic              bus_ready,  // Tell CPU we are done (un-stall pipeline)

    // ----------------------------------------------------
    // 2. Interface to our PIM Memory Array
    // ----------------------------------------------------
    output logic              pim_we,
    output logic [1:0]        pim_addr,
    output logic [DATA_W-1:0] pim_wdata,
    output logic              pim_compute_req,
    
    input  logic [DATA_W-1:0] pim_rdata,
    input  logic [$clog2(PIM_PARALLEL_BASES):0] pim_result,
    input  logic              pim_done
);

    // State Machine States
    typedef enum logic [1:0] {
        ST_IDLE    = 2'b00,
        ST_COMPUTE = 2'b01,
        ST_FINISH  = 2'b10
    } state_t;

    state_t current_state, next_state;

    // Registers to hold our final answer safely
    logic [31:0] saved_result;

    // --- FSM: Sequential Block (Clocking) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_IDLE;
            saved_result  <= '0;
        end else begin
            current_state <= next_state;
            
            // If the memory array says it's done, grab the answer!
            if (pim_done) begin
                saved_result <= { {(31-$clog2(PIM_PARALLEL_BASES)){1'b0}}, pim_result }; // Pad with zeros to make it 32-bit
            end
        end
    end

    // --- FSM: Combinational Block (Logic) ---
    always_comb begin
        // Default outputs
        next_state      = current_state;
        bus_ready       = 1'b0;
        bus_rdata       = '0;
        pim_we          = 1'b0;
        pim_addr        = 2'b00;
        pim_wdata       = bus_wdata;
        pim_compute_req = 1'b0;

        case (current_state)
            ST_IDLE: begin
                if (bus_valid) begin
                    if (bus_we) begin
                        // CPU IS WRITING
                        case (bus_addr[7:0]) // Look at the lowest byte of the address
                            8'h00: begin // Write Reference
                                pim_addr = 2'b00;
                                pim_we   = 1'b1;
                                bus_ready = 1'b1;
                            end
                            8'h04: begin // Write Query
                                pim_addr = 2'b01;
                                pim_we   = 1'b1;
                                bus_ready = 1'b1;
                            end
                            8'h08: begin // CPU triggers compute!
                                pim_compute_req = 1'b1;
                                next_state = ST_COMPUTE; // Jump to compute state
                            end
                            default: bus_ready = 1'b1; // Ignore unknown addresses
                        endcase
                    end else begin
                        // CPU IS READING
                        case (bus_addr[7:0])
                            8'h0C: begin // Read Result
                                bus_rdata = saved_result;
                                bus_ready = 1'b1;
                            end
                            default: bus_ready = 1'b1; 
                        endcase
                    end
                end
            end

            ST_COMPUTE: begin
                // The CPU is currently frozen waiting for 'bus_ready'.
                // We stay in this state until the Memory Array raises 'pim_done'.
                if (pim_done) begin
                    next_state = ST_FINISH;
                end
            end

            ST_FINISH: begin
                // Computation is done! Assert bus_ready so the CPU pipeline can resume.
                bus_ready = 1'b1;
                next_state = ST_IDLE; // Go back to sleep waiting for the next command
            end

            default: next_state = ST_IDLE;
        endcase
    end

endmodule