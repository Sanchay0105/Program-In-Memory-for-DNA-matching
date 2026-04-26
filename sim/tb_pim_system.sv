`timescale 1ns / 1ps

import genomic_pkg::*;

module tb_pim_system();

    // System Signals
    logic clk;
    logic rst_n;

    // CPU Bus Signals
    logic              bus_valid;
    logic              bus_we;
    logic [31:0]       bus_addr;
    logic [31:0]       bus_wdata; // Assuming DATA_W is 32 for this test
    logic [31:0]       bus_rdata;
    logic              bus_ready;

    // Instantiate the Top Level Subsystem
    pim_top #(
        .BASES(16),
        .DATA_W(32)
    ) uut_system (
        .clk(clk),
        .rst_n(rst_n),
        .bus_valid(bus_valid),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper Task: Simulate the CPU WRITING to the bus
    task cpu_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            bus_valid = 1'b1;
            bus_we    = 1'b1;
            bus_addr  = addr;
            bus_wdata = data;
            
            // Wait for the hardware to say "Ready"
            wait(bus_ready == 1'b1);
            @(posedge clk);
            
            // Drop signals
            bus_valid = 1'b0;
            bus_we    = 1'b0;
        end
    endtask

    // Helper Task: Simulate the CPU READING from the bus
    task cpu_read(input [31:0] addr);
        begin
            @(posedge clk);
            bus_valid = 1'b1;
            bus_we    = 1'b0;
            bus_addr  = addr;
            
            // Wait for the hardware to say "Ready"
            wait(bus_ready == 1'b1);
            
            // Capture the data on the bus
            $display(">> CPU Read from Address [0x%08X]: Data = %0d", addr, bus_rdata);
            
            @(posedge clk);
            bus_valid = 1'b0;
        end
    endtask

    // The Main Test Sequence
    initial begin
        $display("\n==================================================");
        $display("   STARTING PIM SYSTEM INTEGRATION TEST");
        $display("==================================================");

        // 1. Initialize and Reset
        bus_valid = 0;
        bus_we = 0;
        bus_addr = 0;
        bus_wdata = 0;
        rst_n = 0;
        #20 rst_n = 1; // Release reset
        #10;

        $display("STATUS: CPU is writing DNA sequences to Smart Memory...");
        
        // 2. CPU Writes Reference DNA (All 'A's -> 32'h0000_0000)
        // Memory Map: 0x4000_0000 is the Reference Register
        cpu_write(32'h4000_0000, 32'h0000_0000);

        // 3. CPU Writes Query DNA (Let's inject exactly 6 mismatches)
        // 32'h0000_0FFF translates to binary: ...0000 1111 1111 1111
        // Since each base is 2 bits, 12 ones = 6 'G' bases, the rest are 'A's.
        // Memory Map: 0x4000_0004 is the Query Register
        cpu_write(32'h4000_0004, 32'h0000_0FFF); 

        $display("STATUS: CPU triggering Processing-In-Memory Compute...");
        
        // 4. CPU Triggers the Compute Command
        // Memory Map: 0x4000_0008 is the Command Trigger
        cpu_write(32'h4000_0008, 32'h0000_0001);

        $display("STATUS: CPU reading back the result...");
        
        // 5. CPU Reads the Result
        // Memory Map: 0x4000_000C is the Result Register
        cpu_read(32'h4000_000C);

        $display("==================================================\n");
        $finish;
    end

endmodule