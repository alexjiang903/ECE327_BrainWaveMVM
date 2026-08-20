/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* MVM Control FSM                                 */
/***************************************************/

module ctrl # (
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
    
)(
    input  clk,
    input  rst,
    input  start,
    input  [VEC_ADDRW-1:0] vec_start_addr, // first vector word is stored at this address (top of memory)
    input  [VEC_SIZEW-1:0] vec_num_words,
    input  [MAT_ADDRW-1:0] mat_start_addr,
    input  [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output [VEC_ADDRW-1:0] vec_raddr,
    output [MAT_ADDRW-1:0] mat_raddr,
    output accum_first,
    output accum_last,
    output ovalid,
    output busy
);

/******* Your code starts here *******/
localparam MEM_LATENCY = 1;
localparam MEM_OUTPUT_LATENCY = 1;
localparam DOT8_LATENCY = 5;
localparam ACCUM_LATENCY = 2;

localparam DRAIN_CYCLES = MEM_LATENCY + MEM_OUTPUT_LATENCY + DOT8_LATENCY + ACCUM_LATENCY;
localparam CONTROL_DELAY = MEM_LATENCY; // the dot8 latency is accounted for in mvm.sv

localparam DRAIN_COUNT_W = (DRAIN_CYCLES <= 1) ? 1 : $clog2(DRAIN_CYCLES);


typedef enum logic {
    IDLE,
    COMPUTE
} state_t;


state_t state;
state_t next_state;

logic [VEC_ADDRW - 1:0] vec_start_addr_reg;
logic [VEC_SIZEW - 1:0] vec_num_words_reg;
logic [MAT_ADDRW - 1:0] mat_start_addr_reg;
logic [MAT_SIZEW - 1:0] mat_rows_reg; 


logic [VEC_SIZEW - 1:0] word_count; // identifies the curent 8-element word currently processing
logic [MAT_SIZEW - 1:0] result_count; // current number of full results produced (up to mat_num_rows_per_olane)
logic [MAT_ADDRW - 1:0] curr_matrix_addr_reg; // current address identifying word to process in a given row


logic controller_busy; 

logic [DRAIN_COUNT_W - 1:0] drain_counter; 
logic finished_issuing_addrs; 
logic finished_computations;

logic on_last_word;
logic on_last_row;

logic pipeline_draining; // flag to indicate if the dot8 + accum pipeline is no longer accepting new input addresses
// can still be processing past inputs due to added pipeline register latency

logic addr_issue_valid;
logic mem_output_valid; // valid flag of the memory module (latency 1 cycle)

logic first_issue_addr; // flag if this address if the first issued address
logic last_issue_addr; // flag if this addressis the last issued address

// pipeline the control signals
logic [CONTROL_DELAY - 1: 0] first_pipe;
logic [CONTROL_DELAY - 1: 0] last_pipe;

always_comb begin
    on_last_word = (word_count == vec_num_words_reg - 1);
    on_last_row = (result_count == mat_rows_reg - 1);

    finished_issuing_addrs = (
        (state == COMPUTE) && 
        on_last_word &&
        on_last_row
    );
end


always_comb begin
    addr_issue_valid = (state == COMPUTE) && (!pipeline_draining);
    first_issue_addr = (addr_issue_valid && (word_count == 0));
    last_issue_addr = (addr_issue_valid && (word_count == vec_num_words_reg - 1));
end


always_ff @(posedge clk) begin
    if (rst) begin
        first_pipe <= '0;
        last_pipe <= '0;    
    end else begin
        first_pipe[0] <= first_issue_addr;
        for (int i = 1; i < CONTROL_DELAY; i++) begin
            first_pipe[i] <= first_pipe[i - 1];
        end 
        
        last_pipe[0] <= last_issue_addr;
        for (int i = 1; i < CONTROL_DELAY; i++) begin
            last_pipe[i] <= last_pipe[i - 1];
        end 
    end
end


always_ff @(posedge clk) begin
    if (rst) begin
        mem_output_valid <= 1'b0; 
    end else begin
        mem_output_valid <= addr_issue_valid;
    end
end

always_ff @(posedge clk) begin 
    if (rst) begin
        drain_counter <= '0;
    end else if (!pipeline_draining) begin 
        drain_counter <= '0;
    end else begin
        drain_counter <= drain_counter + 1;
    end
end

always_comb begin
    finished_computations = (pipeline_draining && (drain_counter == DRAIN_CYCLES - 1));
end


// sequential logic to do stuff in state
always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        
        vec_start_addr_reg <= '0;
        vec_num_words_reg <= '0;
        mat_start_addr_reg <= '0;
        mat_rows_reg <= '0;

        word_count <= '0;
        result_count <= '0;
        curr_matrix_addr_reg <= '0;
        pipeline_draining <= '0;

    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                // register inputs to FSM
                vec_start_addr_reg <= vec_start_addr;
                vec_num_words_reg <= vec_num_words; 
                mat_start_addr_reg <= mat_start_addr;
                mat_rows_reg <= mat_num_rows_per_olane;
                word_count <= '0;
                result_count <= '0;
                curr_matrix_addr_reg <= mat_start_addr;
            end
            
            COMPUTE: begin
                if (!pipeline_draining) begin
                    curr_matrix_addr_reg <= curr_matrix_addr_reg + 1;
           
                    if (word_count == vec_num_words_reg - 1) begin
                        // all words of current row have dot product computed for one iteration
                        word_count <= '0;        
                        if (result_count == mat_rows_reg - 1) begin 
                            // all work is finished (all iterations complete)
                            pipeline_draining <= 1'b1;
                        end else begin
                            result_count <= result_count + 1;
                        end   
                    end else begin
                            word_count <= word_count + 1;     
                        end
                
                end else begin
                    // no new memory addresses are issued
                    // capture and hold counters/addresses until memory + dot8 + accum pipeline finishes
                    word_count <= word_count;
                    result_count <= result_count;
                    curr_matrix_addr_reg <= curr_matrix_addr_reg;
                    
                    if (finished_computations) begin
                        pipeline_draining <= 1'b0;
                    end
                end
            end
        endcase    
    end
end


// combinational logic to decide next state based on current state 
always_comb begin
    next_state = state;
    controller_busy = 1'b0;
    
    case (state) 
        IDLE: begin
            controller_busy = 1'b0;
            if (start) begin
                next_state = COMPUTE;
            end
        end
        
        COMPUTE: begin
            controller_busy = 1'b1;
            if (finished_computations) begin
                next_state = IDLE;
            end
        end
    endcase
end

assign busy = controller_busy;
assign ovalid = mem_output_valid;
assign mat_raddr = curr_matrix_addr_reg;
assign vec_raddr = vec_start_addr_reg + word_count;
assign accum_first = first_pipe[CONTROL_DELAY -1];
assign accum_last = last_pipe[CONTROL_DELAY - 1];


/******* Your code ends here ********/
endmodule