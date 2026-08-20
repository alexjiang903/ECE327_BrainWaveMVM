/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* Matrix Vector Multiplication (MVM) Module       */
/***************************************************/
module mvm #(
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 180
)(
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH*NUM_OLANES-1:0] o_result,
    output o_valid
);

/******* Your code starts here *******/
localparam DOT8_LATENCY = 5;
localparam MEM_OUTPUT_LATENCY = 1;
localparam ACCUM_CTRL_DEPTH = DOT8_LATENCY + MEM_OUTPUT_LATENCY;

localparam NUM_VEC_PIPE_COPIES = (NUM_OLANES < 8) ? NUM_OLANES : 8;
localparam LANES_PER_COPY = NUM_OLANES / NUM_VEC_PIPE_COPIES;

logic [VEC_ADDRW - 1: 0] vec_raddr; // read address signal being provided by memory controller
logic [MEM_DATAW - 1: 0] vec_rdata; // ouput read data output on the vector memory module
(* keep = "true" *) logic [MEM_DATAW - 1: 0] vec_rdata_pipe [NUM_VEC_PIPE_COPIES]; // replicated copies, registered one cycle before feeding dot8


logic [MAT_ADDRW - 1: 0] ctrl_mat_raddr;

logic ctrl_out_valid; // signal to indicate if controller has asserted ovalid
(* keep = "true" *) logic ctrl_out_valid_pipe [NUM_VEC_PIPE_COPIES]; 
logic ctrl_accum_first;
logic ctrl_accum_last; 
logic ctrl_busy;


logic [MEM_DATAW - 1: 0] mat_rdata [NUM_OLANES]; // output read data for each matrix block in the MVM engine
logic [MEM_DATAW - 1: 0] mat_rdata_pipe [NUM_OLANES];


logic [OWIDTH - 1: 0] dot_results [NUM_OLANES]; // holds output of each dot product value 
logic dot_output_valid [NUM_OLANES]; // hold validity of each dot product value

logic [OWIDTH - 1: 0] accum_result [NUM_OLANES];
logic accum_output_valid [NUM_OLANES];

logic [ACCUM_CTRL_DEPTH - 1:0] accum_first_pipeline; // delay accum_first signal to arrive only once dot8 finishes
logic [ACCUM_CTRL_DEPTH - 1:0] accum_last_pipeline; // delay accum_last signal


// instantiate the vector memory 
mem #(
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH)
) vector_mem (
    .clk (clk),
    .wdata(i_vec_wdata),
    .waddr(i_vec_waddr),
    .wen(i_vec_wen),
    .raddr(vec_raddr),
    .rdata(vec_rdata)
);


ctrl # (
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW),
    .VEC_SIZEW(VEC_ADDRW + 1),
    .MAT_SIZEW(MAT_ADDRW + 1)
    
) controller (
    .clk(clk),
    .rst(rst),
    .start(i_start),
    .vec_start_addr(i_vec_start_addr), // first vector word is stored at this address (top of memory)
    .vec_num_words(i_vec_num_words),
    .mat_start_addr(i_mat_start_addr),
    .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .vec_raddr(vec_raddr),
    .mat_raddr(ctrl_mat_raddr),
    .accum_first(ctrl_accum_first),
    .accum_last(ctrl_accum_last),
    .ovalid(ctrl_out_valid),
    .busy(ctrl_busy)
);


always_ff @(posedge clk) begin
    if (rst) begin
        accum_first_pipeline <= '0;
        accum_last_pipeline <= '0;    
    end else begin
        accum_first_pipeline[0] <= ctrl_accum_first;
        for (int i = 1; i < ACCUM_CTRL_DEPTH; i++) begin
            accum_first_pipeline[i] <= accum_first_pipeline[i - 1];
        end 
        
        accum_last_pipeline[0] <= ctrl_accum_last;
        for (int i = 1; i < ACCUM_CTRL_DEPTH; i++) begin
            accum_last_pipeline[i] <= accum_last_pipeline[i - 1];
        end 
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int c = 0; c < NUM_VEC_PIPE_COPIES; c++) begin
            vec_rdata_pipe[c] <= '0;
            ctrl_out_valid_pipe[c] <= 1'b0;
        end
    end else begin
        for (int c = 0; c < NUM_VEC_PIPE_COPIES; c++) begin
            vec_rdata_pipe[c] <= vec_rdata;
            ctrl_out_valid_pipe[c] <= ctrl_out_valid;
        end
    end
end


// generate NUM_OLANES dot modules and accumulator modules in for loop

genvar lane;
generate 
    for (lane = 0; lane < NUM_OLANES; lane++) begin 
        // instantiate matrix memory, dot product module, and accumlator for NUM_OLANES lanes
        
        // matrix memory for the lane
         mem #(
            .DATAW(MEM_DATAW),
            .DEPTH(MAT_MEM_DEPTH)
         ) matrix_mem_inst (
            .clk (clk),
            .wdata(i_mat_wdata),
            .waddr(i_mat_waddr),
            .wen(i_mat_wen[lane]),
            .raddr(ctrl_mat_raddr),
            .rdata(mat_rdata[lane])
         ); 
         
         always_ff @(posedge clk) begin
            if (rst) mat_rdata_pipe[lane] <= '0;
            else mat_rdata_pipe[lane] <= mat_rdata[lane];
         end
          
         // dot8 module for the lane
         dot8 # (
            .IWIDTH(IWIDTH),
            .OWIDTH(OWIDTH)
         ) dot8_lane_inst (
            .clk(clk),
            .rst(rst),
            .vec0(mat_rdata_pipe[lane]),
            .vec1(vec_rdata_pipe[lane / LANES_PER_COPY]),
            .ivalid(ctrl_out_valid_pipe[lane / LANES_PER_COPY]),
            .result(dot_results[lane]),
            .ovalid(dot_output_valid[lane])
         );
         
         
         // accumulator for the lane
         accum # (
            .DATAW(OWIDTH),
            .ACCUMW(OWIDTH)
         ) accum_lane_inst (
            .clk(clk),
            .rst(rst),
            .data(dot_results[lane]),
            .ivalid(dot_output_valid[lane]),
            .first(accum_first_pipeline[ACCUM_CTRL_DEPTH - 1]),
            .last(accum_last_pipeline[ACCUM_CTRL_DEPTH - 1]),
            .result(accum_result[lane]),
            .ovalid(accum_output_valid[lane])
         );
         
         
         assign o_result[lane*OWIDTH +: OWIDTH] = accum_result[lane]; 
    end
endgenerate


assign o_valid = accum_output_valid[0];
assign o_busy = ctrl_busy; 

/******* Your code ends here ********/

endmodule