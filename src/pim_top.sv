`timescale 1ns / 1ps

import genomic_pkg::*;

module pim_top #(
    parameter int BASES = PIM_PARALLEL_BASES,
    parameter int DATA_W = PIM_DATA_WIDTH
)(
    input  logic              clk,
    input  logic              rst_n,

    // The External System Bus (Connecting to the RISC-V CPU)
    input  logic              bus_valid,
    input  logic              bus_we,
    input  logic [31:0]       bus_addr,
    input  logic [DATA_W-1:0] bus_wdata,
    
    output logic [DATA_W-1:0] bus_rdata,
    output logic              bus_ready
);

    // =========================================================================
    // INTERNAL WIRES (The traces soldered on our virtual circuit board)
    // =========================================================================
    
    // Wires going FROM Controller TO Memory Array
    logic              int_pim_we;
    logic [1:0]        int_pim_addr;
    logic [DATA_W-1:0] int_pim_wdata;
    logic              int_pim_compute_req;
    
    // Wires going FROM Memory Array TO Controller
    logic [DATA_W-1:0] int_pim_rdata;
    logic [$clog2(BASES):0] int_pim_result;
    logic              int_pim_done;


    // =========================================================================
    // MODULE INSTANTIATIONS (Plugging in the chips)
    // =========================================================================

    // 1. Instantiate the FSM Translator
    pim_controller #(
        .DATA_W(DATA_W)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        
        // Connect the external pins to the outside world
        .bus_valid(bus_valid),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        
        // Connect the internal pins to our internal wires
        .pim_we(int_pim_we),
        .pim_addr(int_pim_addr),
        .pim_wdata(int_pim_wdata),
        .pim_compute_req(int_pim_compute_req),
        .pim_rdata(int_pim_rdata),
        .pim_result(int_pim_result),
        .pim_done(int_pim_done)
    );

    // 2. Instantiate the Smart Memory
    pim_memory_array #(
        .BASES(BASES),
        .DATA_W(DATA_W)
    ) u_memory (
        .clk(clk),
        .rst_n(rst_n),
        
        // Connect its inputs to the wires coming from the controller
        .write_en(int_pim_we),
        .addr(int_pim_addr),
        .write_data(int_pim_wdata),
        .compute_req(int_pim_compute_req),
        
        // Connect its outputs to the wires going to the controller
        .read_data(int_pim_rdata),
        .pim_result(int_pim_result),
        .compute_done(int_pim_done)
    );

endmodule