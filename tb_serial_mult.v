`timescale 1ns / 1ps

module tb_serial_mult();

    parameter WIDTH = 8;

    reg                clk = 0;
    reg                rst, start;
    reg  [WIDTH-1:0]   A, B;
    wire [2*WIDTH-1:0] product;
    wire               done;

    serial_mult #(.WIDTH(WIDTH)) DUT (
        .clk(clk), .rst(rst), .start(start),
        .A(A), .B(B), .product(product), .done(done)
    );

    always #5 clk = ~clk;  // 100 MHz

    integer pass_count = 0;
    integer fail_count = 0;
    integer total_cycles;

    // ---------------------------------------------------------
    // Task: apply operands, start, wait for done, check result
    // ---------------------------------------------------------
    task test_multiply(input [WIDTH-1:0] op_a, op_b);
        begin
            @(negedge clk);
            A = op_a; B = op_b; start = 1;
            @(negedge clk);
            start = 0;

            total_cycles = 0;
            while (!done) begin
                @(posedge clk);
                total_cycles = total_cycles + 1;
                if (total_cycles > 100) begin
                    $display("TIMEOUT: %0d x %0d", op_a, op_b);
                    fail_count = fail_count + 1;
                    disable test_multiply;
                end
            end

            if (product === op_a * op_b) begin
                $display("PASS: %0d x %0d = %0d  (%0d cycles)",
                         op_a, op_b, product, total_cycles);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0d x %0d = %0d (expected %0d)",
                         op_a, op_b, product, op_a * op_b);
                fail_count = fail_count + 1;
            end

            // Reset for next test
            @(negedge clk); rst = 1;
            @(negedge clk); rst = 0;
            @(negedge clk);
        end
    endtask

    // ---------------------------------------------------------
    // TODO: Write the test sequence.
    //   1. Assert reset for a few cycles, then deassert.
    //   2. Call test_multiply with at least 10 test cases.
    //      Include: typical values, edge cases (0, 1, 255),
    //      both operands being the maximum value (255*255).
    //   3. Print a summary: total passed, total failed.
    //   4. Call $finish.
    // ---------------------------------------------------------
    initial begin
    // =========================
    // 1. Reset hệ thống
    // =========================
    rst = 1;
    start = 0;
    A = 0;
    B = 0;

    repeat (3) @(negedge clk);
    rst = 0;

    // =========================
    // 2. Test cases
    // =========================

    // Basic tests
    test_multiply(7, 6);
    test_multiply(3, 5);
    test_multiply(10, 12);

    // Zero cases
    test_multiply(255, 3);
    test_multiply(255, 255);
    test_multiply(255, 1);
    test_multiply(9, 0);

    // One cases
    test_multiply(1, 25);
    test_multiply(13, 1);

    // Edge cases
    
    test_multiply(3, 255);
    

    // Random-like values
    test_multiply(23, 17);
    test_multiply(100, 3);

    // =========================
    // 3. Summary
    // =========================
    $display("=================================");
    $display("TEST SUMMARY:");
    $display("PASSED: %0d", pass_count);
    $display("FAILED: %0d", fail_count);
    $display("=================================");

    // =========================
    // 4. Finish simulation
    // =========================
    $finish;
    end

endmodule