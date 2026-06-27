`timescale 1ns / 1ps

module serial_mult #(
    parameter WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire [WIDTH-1:0]     A,
    input  wire [WIDTH-1:0]     B,
    output reg  [2*WIDTH-1:0]   product,
    output reg                  done
);

    // 1. INTERCONNECT SIGNALS: FSM <-> DATAPATH
    
    // Control signals: FSM -> Datapath (Commands)
    reg load;
    reg do_add;
    reg do_shift;
    reg set_done;

    // Status signals: Datapath -> FSM (Feedback)
    wire b_lsb;
    wire count_done;

    // 2. FINITE STATE MACHINE (CONTROL UNIT)
    localparam IDLE    = 2'b00;
    localparam CALC    = 2'b01;
    localparam DONE_ST = 2'b10;

    reg [1:0] state_reg, state_next;

    // State register (Sequential)
    always @(posedge clk) begin
        if (rst)
            state_reg <= IDLE;
        else
            state_reg <= state_next;
    end

    // Next-state logic & Control signal generation (Combinational)
    always @(*) begin       
        state_next = state_reg;
        load       = 1'b0;
        do_add     = 1'b0;
        do_shift   = 1'b0;
        set_done   = 1'b0;

        case (state_reg)
            IDLE: begin
                if (start) begin
                    load = 1'b1; // Assert load signal to datapath
                    state_next = CALC;
                end
            end
            
            CALC: begin
                if (b_lsb) begin
                    do_add = 1'b1; // If multiplier LSB is 1, assert add command
                end
                do_shift = 1'b1;   // Always assert shift command during CALC state

                if (count_done) begin
                    state_next = DONE_ST;
                end
            end
            
            DONE_ST: begin
                set_done = 1'b1;    
                if (rst) begin
                    state_next = IDLE;
                end
                // Remain in DONE_ST until reset is asserted (per block diagram logic)
            end
            
            default: state_next = IDLE;
        endcase
    end

    // 3. DATAPATH UNIT
    reg [2*WIDTH-1:0]     acc;      
    reg [WIDTH-1:0]       a_reg;     
    reg [WIDTH-1:0]       b_reg;     
    reg [$clog2(WIDTH):0] count;   

    // Assign status signals routed back to FSM
    assign b_lsb      = b_reg[0];
    assign count_done = (count == WIDTH - 1);

    // Datapath sequential operations
    always @(posedge clk) begin
        if (rst) begin
            acc     <= 0;
            a_reg   <= 0;
            b_reg   <= 0;
            count   <= 0;
            product <= 0;
            done    <= 0;
        end else begin
            
            // Clear done flag when loading new operands
            if (load) begin
                done <= 1'b0; 
            end

            // 1. Respond to LOAD command
            if (load) begin
                a_reg <= A;
                b_reg <= B;
                acc   <= 0;
                count <= 0;
            end
            
            // 2. Respond to SHIFT and ADD commands
            else if (do_shift) begin
                if (do_add) begin
                    // Add multiplicand to upper half and shift right combined
                    acc <= ( {1'b0, acc} + {1'b0, a_reg, {WIDTH{1'b0}}} ) >> 1; // Avoid Overflow
                end else begin
                    // Shift right only
                    acc <= acc >> 1;
                end
                
                b_reg <= b_reg >> 1;
                count <= count + 1;
            end
            
            // 3. Respond to SET_DONE command
            if (set_done) begin
                product <= acc;
                done    <= 1'b1;
            end
            
        end
    end

endmodule