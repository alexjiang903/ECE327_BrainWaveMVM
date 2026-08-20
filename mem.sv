module mem # (
    parameter DATAW = 8,
    parameter DEPTH = 512,
    parameter ADDRW = $clog2(DEPTH)
)(
    input  clk,
    input  [DATAW-1:0] wdata,
    input  [ADDRW-1:0] waddr,
    input  wen,
    input  [ADDRW-1:0] raddr,
    output [DATAW-1:0] rdata
);

logic [DATAW-1:0] r_rdata;

// 2D memory array storing 8 bit values as words, 512 levels deep 
logic [DATAW-1:0] mem_array [0:DEPTH-1]; 


always_ff @ (posedge clk) begin
    if (wen) begin
        // write to mem array if write enable asserted
        mem_array[waddr] <= wdata;
    end
   
    // store value at address raddr into r_rdata reg every cycle
    r_rdata <= mem_array[raddr]; 
end

// assign read data to output port
assign rdata = r_rdata;

endmodule