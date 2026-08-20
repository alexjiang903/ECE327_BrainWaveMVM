/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* Accumulator Module                              */
/***************************************************/

module accum # (
    parameter DATAW = 32,
    parameter ACCUMW = 32
)(
    input  clk,
    input  rst,
    input  signed [DATAW-1:0] data,
    input  ivalid,
    input  first,
    input  last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
logic signed [ACCUMW-1: 0] accumulate_reg; // register holding the accumulated value
logic ovalid_reg;

always_ff @(posedge clk) begin
    if (rst) begin
        accumulate_reg <= '0;
        ovalid_reg <= 1'b0;
    
    end else begin
        ovalid_reg <= 1'b0;
        
        if (ivalid) begin
            if (first) begin
                accumulate_reg <= data;
            end else begin
                accumulate_reg <= data + accumulate_reg;
            end
            
            if (last) begin
                ovalid_reg <= 1'b1;
            end 
        end
    
    end

end


assign ovalid = ovalid_reg;
assign result = accumulate_reg;

/******* Your code ends here ********/

endmodule