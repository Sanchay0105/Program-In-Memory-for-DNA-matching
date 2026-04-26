`timescale 1ns / 1ps

module top_system(
    input logic clk,
    input logic rst_n
);

    // =========================================================================
    // The Shared System Bus Wires
    // =========================================================================
    logic        dmem_valid;
    logic        dmem_we;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;

    // Wires specific to the PIM Unit
    logic [31:0] pim_rdata;
    logic        pim_ready;
    logic        pim_sel; // Chip Select for PIM

    // Wires specific to Standard RAM
    logic [31:0] ram_rdata;
    logic        ram_ready;
    logic        ram_sel; // Chip Select for RAM

    // =========================================================================
    // 1. The Address Decoder (The Traffic Cop)
    // =========================================================================
    // We look at the top 4 bits (hex digit) of the address.
    // If the address starts with 0x4 (e.g., 0x4000_0000), activate the PIM!
    assign pim_sel = (dmem_addr[31:28] == 4'h4) ? dmem_valid : 1'b0;
    
    // If the address starts with 0x0 (e.g., 0x0000_0100), activate normal RAM!
    assign ram_sel = (dmem_addr[31:28] == 4'h0) ? dmem_valid : 1'b0;

    // Multiplex the return data back to the CPU based on who was selected
    assign dmem_rdata = pim_sel ? pim_rdata : ram_rdata;
    assign dmem_ready = pim_sel ? pim_ready : ram_ready;

    // =========================================================================
    // 2. Instantiate the Brain (RISC-V CPU)
    // =========================================================================
    riscv_core_v2 u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        
        // Connect CPU to the shared bus
        .dmem_valid(dmem_valid),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready)
    );

    // =========================================================================
    // 3. Instantiate the Muscle (PIM Accelerator)
    // =========================================================================
    pim_top #(
        .BASES(16),
        .DATA_W(32)
    ) u_pim (
        .clk(clk),
        .rst_n(rst_n),
        
        // Connect PIM to the bus, but ONLY let it listen if pim_sel is high!
        .bus_valid(pim_sel), 
        .bus_we(dmem_we),
        .bus_addr(dmem_addr),
        .bus_wdata(dmem_wdata),
        .bus_rdata(pim_rdata),
        .bus_ready(pim_ready)
    );

    // =========================================================================
    // 4. Instantiate Standard Data RAM (For C variables, stack, etc.)
    // =========================================================================
    // Create 4KB of working memory
    logic [31:0] data_ram [0:1023];

    always_ff @(posedge clk) begin
        // Only write to RAM if the CPU wants to write AND the address is for RAM
        if (ram_sel && dmem_we) begin
            data_ram[dmem_addr[11:2]] <= dmem_wdata;
        end
    end

    // Read logic
    assign ram_rdata = data_ram[dmem_addr[11:2]];
    
    // RAM is instantly ready in this architecture
    assign ram_ready = ram_sel ? 1'b1 : 1'b0;

endmodule
