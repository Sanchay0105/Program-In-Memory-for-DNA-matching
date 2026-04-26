`timescale 1ns / 1ps

module tb_soc();

    logic clk;
    logic rst_n;
    int cycle_count;

    // Instantiate the SoC
    top_system uut_soc (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // ON-THE-FLY DISASSEMBLER (For readable logging)
    // =========================================================================
    string inst_name;
    always_comb begin
        case(uut_soc.u_cpu.instruction)
            32'h00000513: inst_name = "ADDI x10, x0, 0";
            32'h55500593: inst_name = "ADDI x11, x0, 0x555";
            32'h00B5060B: inst_name = "PIM.ALIGN x12, x10, x11"; // Custom Instruction!
            32'h00000063: inst_name = "BEQ x0, x0, 0 (TRAP)";
            default:      inst_name = "UNKNOWN";
        endcase
    end

    // =========================================================================
    // PROFESSIONAL HARDWARE LOGIC ANALYZER
    // =========================================================================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Stop spamming the console once we safely hit the infinite trap loop
            if (uut_soc.u_cpu.pc_current == 12 && cycle_count > 6) begin
                // Silent execution
            end else begin
                // Print a perfectly aligned row of data
                $display(" %04d  |  %02d  | 0x%08X | %-24s || Ref(x10): 0x%08X | Query(x11): 0x%08X | Result(x12): %0d", 
                         cycle_count, 
                         uut_soc.u_cpu.pc_current, 
                         uut_soc.u_cpu.instruction, 
                         inst_name,
                         uut_soc.u_cpu.u_decode.reg_file[10], 
                         uut_soc.u_cpu.u_decode.reg_file[11], 
                         uut_soc.u_cpu.u_decode.reg_file[12]);
            end
        end
    end

    // =========================================================================
    // BOOT SEQUENCE & FORMATTING
    // =========================================================================
    initial begin
        $display("\n");
        $display("=======================================================================================================================");
        $display("                                   RISC-V GENOMIC ACCELERATOR - PIPELINE TRACE");
        $display("=======================================================================================================================");
        $display(" CYCLE |  PC  | INSTRUCTION| DISASSEMBLY              || INTERNAL REGISTER STATE");
        $display("-------+------+------------+--------------------------++-------------------------------------------------------------");

        rst_n = 0;
        #20; 
        rst_n = 1; 

        #100; // Let the CPU run for 10 clock cycles

        // Footer
        $display("=======================================================================================================================");
        $display("   [SYSTEM HALT] CPU safely entered infinite trap loop.");
        $display("-----------------------------------------------------------------------------------------------------------------------");
        $display("   FINAL COMPUTATION RESULT:");
        $display("   > Reference DNA  : 0x%08X", uut_soc.u_cpu.u_decode.reg_file[10]);
        $display("   > Query DNA      : 0x%08X", uut_soc.u_cpu.u_decode.reg_file[11]);
        $display("   > Hamming Dist   : %0d", uut_soc.u_cpu.u_decode.reg_file[12]);
        $display("=======================================================================================================================\n");
        $finish;
    end

endmodule
