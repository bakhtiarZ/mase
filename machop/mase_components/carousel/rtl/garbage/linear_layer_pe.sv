module linear_layer_pe #(
    parameter int DATA_WIDTH = 8,           // Width of input data and weights
    parameter int INPUT_SIZE = 64,          // Number of input features
    parameter int OUTPUT_SIZE = 32,         // Number of output neurons
    parameter int CAROUSEL_BUFFER_SIZE = 4  // Buffer size for weight carousel
) (
    // Clock and reset
    input  logic clk,
    input  logic rst,
    
    // Input vector x - loaded once per computation
    input  logic [DATA_WIDTH-1:0] input_vector [INPUT_SIZE],
    input  logic                  input_valid,
    output logic                  input_ready,
    
    // Weight matrices - one per output neuron, loaded via carousel
    input  logic [DATA_WIDTH-1:0] weights_in [INPUT_SIZE],
    input  logic                  weights_valid,
    output logic                  weights_ready,
    
    // Output results - one per output neuron
    output logic [2*DATA_WIDTH-1:0] output_results [OUTPUT_SIZE],
    output logic                     output_valid,
    input  logic                     output_ready,
    
    // Control signals
    input  logic start_computation,  // Start the linear computation
    output logic computation_done     // Computation completed
);

    // Local parameters
    localparam int ACCUM_WIDTH = 2 * DATA_WIDTH + $clog2(INPUT_SIZE);
    
    // Internal signals
    logic [DATA_WIDTH-1:0] internal_input_vector [INPUT_SIZE];
    logic                  input_vector_loaded;
    logic [OUTPUT_SIZE-1:0] pe_busy;
    logic [OUTPUT_SIZE-1:0] pe_done;
    
    // Weight storage and distribution
    logic [DATA_WIDTH-1:0] current_weights [INPUT_SIZE];
    logic                  weights_loaded;
    logic [7:0]            current_neuron;  // Current neuron being processed
    
    // Processing element array
    logic [ACCUM_WIDTH-1:0] pe_accumulators [OUTPUT_SIZE];
    logic [OUTPUT_SIZE-1:0] pe_computing;
    
    // FSM states
    typedef enum logic [2:0] {
        IDLE,           // Waiting for start
        LOAD_INPUT,     // Loading input vector
        LOAD_WEIGHTS,   // Loading weights for current neuron
        COMPUTE,        // Computing linear transformation
        OUTPUT_RESULTS  // Outputting results
    } state_t;
    
    state_t state, next_state;
    
    // ============================================================================
    // Input Vector Loading Logic
    // ============================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            input_vector_loaded <= 1'b0;
            for (int i = 0; i < INPUT_SIZE; i++) begin
                internal_input_vector[i] <= '0;
            end
        end else if (input_valid && input_ready) begin
            // Load input vector into internal storage
            for (int i = 0; i < INPUT_SIZE; i++) begin
                internal_input_vector[i] <= input_vector[i];
            end
            input_vector_loaded <= 1'b1;
        end
    end
    
    // ============================================================================
    // Weight Loading Logic
    // ============================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            weights_loaded <= 1'b0;
            for (int i = 0; i < INPUT_SIZE; i++) begin
                current_weights[i] <= '0;
            end
        end else if (weights_valid && weights_ready) begin
            // Load weights for current neuron
            for (int i = 0; i < INPUT_SIZE; i++) begin
                current_weights[i] <= weights_in[i];
            end
            weights_loaded <= 1'b1;
        end
    end
    
    // ============================================================================
    // Processing Elements (Multiply-Accumulate Units)
    // ============================================================================
    genvar pe_idx;
    generate
        for (pe_idx = 0; pe_idx < OUTPUT_SIZE; pe_idx++) begin : pe_array
            // Individual PE state machine
            logic [1:0] pe_state;
            logic [7:0] pe_element_counter;
            logic [ACCUM_WIDTH-1:0] pe_accumulator;
            
            // PE state machine
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    pe_state <= 2'b00;
                    pe_element_counter <= 8'd0;
                    pe_accumulator <= '0;
                    pe_busy[pe_idx] <= 1'b0;
                    pe_done[pe_idx] <= 1'b0;
                    pe_accumulators[pe_idx] <= '0;
                end else begin
                    case (pe_state)
                        2'b00: begin // IDLE
                            if (pe_computing[pe_idx] && weights_loaded) begin
                                pe_state <= 2'b01;
                                pe_element_counter <= 8'd0;
                                pe_accumulator <= '0;
                                pe_busy[pe_idx] <= 1'b1;
                                pe_done[pe_idx] <= 1'b0;
                            end
                        end
                        
                        2'b01: begin // COMPUTING
                            if (pe_element_counter < INPUT_SIZE) begin
                                // Multiply-accumulate operation
                                pe_accumulator <= pe_accumulator + 
                                    (internal_input_vector[pe_element_counter] * current_weights[pe_element_counter]);
                                pe_element_counter <= pe_element_counter + 1;
                            end else begin
                                // Computation complete
                                pe_state <= 2'b10;
                                pe_accumulators[pe_idx] <= pe_accumulator;
                                pe_busy[pe_idx] <= 1'b0;
                                pe_done[pe_idx] <= 1'b1;
                            end
                        end
                        
                        2'b10: begin // DONE
                            if (!pe_computing[pe_idx]) begin
                                pe_state <= 2'b00;
                                pe_done[pe_idx] <= 1'b0;
                            end
                        end
                    endcase
                end
            end
        end
    endgenerate
    
    // ============================================================================
    // Main Control FSM
    // ============================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            current_neuron <= 8'd0;
            pe_computing <= '0;
            computation_done <= 1'b0;
            output_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start_computation && input_vector_loaded) begin
                        current_neuron <= 8'd0;
                        pe_computing <= '0;
                        computation_done <= 1'b0;
                        output_valid <= 1'b0;
                    end
                end
                
                LOAD_INPUT: begin
                    // Input loading handled in separate always block
                end
                
                LOAD_WEIGHTS: begin
                    if (weights_valid && weights_ready) begin
                        // Weights loaded for current neuron
                    end
                end
                
                COMPUTE: begin
                    if (current_neuron < OUTPUT_SIZE) begin
                        // Start computation for current neuron
                        pe_computing[current_neuron] <= 1'b1;
                        
                        // Wait for computation to complete
                        if (pe_done[current_neuron]) begin
                            pe_computing[current_neuron] <= 1'b0;
                            current_neuron <= current_neuron + 1;
                        end
                    end
                end
                
                OUTPUT_RESULTS: begin
                    if (output_ready) begin
                        output_valid <= 1'b1;
                        computation_done <= 1'b1;
                    end else begin
                        output_valid <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start_computation && input_vector_loaded) begin
                    next_state = LOAD_WEIGHTS;
                end
            end
            
            LOAD_WEIGHTS: begin
                if (weights_valid && weights_ready) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (current_neuron >= OUTPUT_SIZE) begin
                    next_state = OUTPUT_RESULTS;
                end
            end
            
            OUTPUT_RESULTS: begin
                if (output_ready) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    // ============================================================================
    // Output Assignment
    // ============================================================================
    always_comb begin
        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            output_results[i] = pe_accumulators[i];
        end
    end
    
    // ============================================================================
    // Handshake Logic
    // ============================================================================
    assign input_ready = (state == IDLE) && !input_vector_loaded;
    assign weights_ready = (state == LOAD_WEIGHTS) && !weights_loaded;

endmodule
