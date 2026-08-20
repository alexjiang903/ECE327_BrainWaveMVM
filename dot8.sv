/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* 8-Lane Dot Product Module                       */
/***************************************************/

module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
)(
    input clk,
    input rst,
    input signed [8*IWIDTH-1:0] vec0, // 8 IWIDTH bit numbers in vector 0
    input signed [8*IWIDTH-1:0] vec1, // 8 IWIDTH bit numbers in vector 1
    input ivalid,
    output signed [OWIDTH-1:0] result,
    output ovalid
);

/******* Your code starts here *******/

parameter S1_BITWIDTH = 16; // bit width for pipeline storage registers for stage 1 result
parameter S2_BITWIDTH = 17; // bit width for pipeline storage registers for stage 2 result
parameter S3_BITWIDTH = 18; // bit width for pipeline storage registers for stage 3 result


// input registers
logic signed [IWIDTH - 1:0] a0_r;
logic signed [IWIDTH - 1:0] a1_r;
logic signed [IWIDTH - 1:0] a2_r;
logic signed [IWIDTH - 1:0] a3_r;
logic signed [IWIDTH - 1:0] a4_r;
logic signed [IWIDTH - 1:0] a5_r;
logic signed [IWIDTH - 1:0] a6_r;
logic signed [IWIDTH - 1:0] a7_r;

logic signed [IWIDTH - 1:0] b0_r;
logic signed [IWIDTH - 1:0] b1_r;
logic signed [IWIDTH - 1:0] b2_r;
logic signed [IWIDTH - 1:0] b3_r;
logic signed [IWIDTH - 1:0] b4_r;
logic signed [IWIDTH - 1:0] b5_r;
logic signed [IWIDTH - 1:0] b6_r;
logic signed [IWIDTH - 1:0] b7_r;

// output registers
logic signed [OWIDTH - 1:0] out_r; 


// pipeline registers

// latency-insentitive ready signal pipeline
logic signed S_init_valid;
logic signed S1_valid;
logic signed S2_valid;
logic signed S3_valid;
logic signed S_out_valid;


// stage 1
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_0; // a0*b0
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_1; // a1*b1
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_2; // a2*b2
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_3; // a3*b3

(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_4; // a4*b4
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_5; // a5*b5
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_6; // a6*b6
(* use_dsp = "yes" *) logic signed [S1_BITWIDTH - 1: 0] S1_7; // a7*b7

// stage 2
logic signed [S2_BITWIDTH - 1: 0] S2_0; // a0*b0 + a1*b1
logic signed [S2_BITWIDTH - 1: 0] S2_1; // a2*b2 + a3*b3
logic signed [S2_BITWIDTH - 1: 0] S2_2; // a4*b4 + a5*b5
logic signed [S2_BITWIDTH - 1: 0] S2_3; // a6*b6 + a7*b7

// stage 3
logic signed [S3_BITWIDTH - 1: 0] S3_0; // a0*b0 + a1*b1 + a2*b2 + a3*b3
logic signed [S3_BITWIDTH - 1: 0] S3_1; // a4*b4 + a5*b5 + a6*b6 + a7*b7

// stage 4
logic signed [OWIDTH - 1: 0] S_out; // final output dot product value to drive to result (S3_0 + S3_1)


always_ff @ (posedge clk) begin
    if (rst) begin 
        a0_r <= 8'b0;
        a1_r <= 8'b0;
        a2_r <= 8'b0;
        a3_r <= 8'b0;
        a4_r <= 8'b0;
        a5_r <= 8'b0;
        a6_r <= 8'b0;
        a7_r <= 8'b0;
        
        b0_r <= 8'b0;
        b1_r <= 8'b0;
        b2_r <= 8'b0;
        b3_r <= 8'b0;
        b4_r <= 8'b0;
        b5_r <= 8'b0;
        b6_r <= 8'b0;
        b7_r <= 8'b0;
        
        S_init_valid <= 1'b0;
        S1_valid <= 1'b0;
        S2_valid <= 1'b0;
        S3_valid <= 1'b0;
        S_out_valid <= 1'b0;
        
        S1_0 <= '0;
        S1_1 <= '0;
        S1_2 <= '0;
        S1_3 <= '0;
        S1_4 <= '0;
        S1_5 <= '0;
        S1_6 <= '0;
        S1_7 <= '0;
        
        S2_0 <= '0;
        S2_1 <= '0;
        S2_2 <= '0;
        S2_3 <= '0;
        
        S3_0 <= '0;
        S3_1 <= '0;
        
        S_out <= 32'b0;
    end else begin
        S_init_valid <= ivalid;
        if (ivalid) begin
            a0_r <= vec0[0 +: IWIDTH];
            a1_r <= vec0[IWIDTH +: IWIDTH];
            a2_r <= vec0[2*IWIDTH +: IWIDTH];
            a3_r <= vec0[3*IWIDTH +: IWIDTH];
            a4_r <= vec0[4*IWIDTH +: IWIDTH];
            a5_r <= vec0[5*IWIDTH +: IWIDTH];
            a6_r <= vec0[6*IWIDTH +: IWIDTH];
            a7_r <= vec0[7*IWIDTH +: IWIDTH];

            b0_r <= vec1[0 +: IWIDTH];
            b1_r <= vec1[IWIDTH +: IWIDTH];
            b2_r <= vec1[2*IWIDTH +: IWIDTH];
            b3_r <= vec1[3*IWIDTH +: IWIDTH];
            b4_r <= vec1[4*IWIDTH +: IWIDTH];
            b5_r <= vec1[5*IWIDTH +: IWIDTH];
            b6_r <= vec1[6*IWIDTH +: IWIDTH];
            b7_r <= vec1[7*IWIDTH +: IWIDTH];
        end

        S1_valid <= S_init_valid;

        if (S_init_valid) begin
            // do stage 1 computations
            S1_0 <= a0_r * b0_r;
            S1_1 <= a1_r * b1_r;
            S1_2 <= a2_r * b2_r;
            S1_3 <= a3_r * b3_r;

            S1_4 <= a4_r * b4_r;
            S1_5 <= a5_r * b5_r;
            S1_6 <= a6_r * b6_r;
            S1_7 <= a7_r * b7_r;
        end

        S2_valid <= S1_valid;

        if (S1_valid) begin
            // do stage 2 computations
            S2_0 <= S1_0 + S1_1;
            S2_1 <= S1_2 + S1_3;
            S2_2 <= S1_4 + S1_5;
            S2_3 <= S1_6 + S1_7;
        end

        S3_valid <= S2_valid;
        if (S2_valid) begin
            // do stage 3 computations
            S3_0 <= S2_0 + S2_1;
            S3_1 <= S2_2 + S2_3;
        end

        S_out_valid <= S3_valid;
        if (S3_valid) begin
            S_out <= S3_0 + S3_1;
        end
    end
end

assign result = S_out;
assign ovalid = S_out_valid;
 

/******* Your code ends here ********/

endmodule