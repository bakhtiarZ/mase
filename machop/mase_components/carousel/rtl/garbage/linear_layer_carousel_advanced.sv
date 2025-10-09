module linear_layer_carousel_advanced #(
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
    
    // Weight matrices - loaded sequentially for each output neuron
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
    localparam int WEIGHT_CAROUSEL_WIDTH = INPUT_SIZE * DATA_WIDTH;
    
    // Internal signals
    logic [DATA_WIDTH-1:0] internal_input_vector [INPUT_SIZE];
    logic                  input_vector_loaded;
    logic [OUTPUT_SIZE-1:0] pe_busy;
    logic [OUTPUT_SIZE-1:0] pe_done;
    logic [7:0]            current_neuron;  // Current neuron being processed
    logic                  all_pe_done;     // All PEs completed computation
    
    // Weight carousel for distributing weights to PEs
    logic [WEIGHT_CAROUSEL_WIDTH-1:0] weight_carousel_data [CAROUSEL_BUFFER_SIZE];
    logic                              weight_carousel_valid [CAROUSEL_BUFFER_SIZE];
    logic                              weight_carousel_ready [CAROUSEL_BUFFER_SIZE];
    
    // Weight unpacking signals
    logic [DATA_WIDTH-1:0] unpacked_weights [INPUT_SIZE];
    logic                  weights_available;
    
    // Processing element array
    logic [ACCUM_WIDTH-1:0] pe_accumulators [OUTPUT_SIZE];
    logic [OUTPUT_SIZE-1:0] pe_computing;
    
    // FSM states
    typedef enum logic [2:0] {
        IDLE,           // Waiting for start
        LOAD_INPUT,     // Loading input vector
        LOAD_WEIGHTS,   // Loading weights into carousel
        COMPUTE,        // Computing linear transformations
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
    // Weight Carousel Instantiation
    // ============================================================================
    // Pack individual weights into carousel format
    always_comb begin
        for (int i = 0; i < INPUT_SIZE; i++) begin
            weight_carousel_data[0][(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = weights_in[i];
        end
    end
    
    // Connect to carousel input port 0
    assign weight_carousel_valid[0] = weights_valid;
    assign weights_ready = weight_carousel_ready[0];
    
    // Weight carousel core - this will rotate weights through the buffer
    carousel_core #(
        .WIDTH(WEIGHT_CAROUSEL_WIDTH),
        .BUFFER_SIZE(CAROUSEL_BUFFER_SIZE)
    ) weight_carousel (
        .data_in       (weight_carousel_data),
        .data_in_valid (weight_carousel_valid),
        .data_in_ready (weight_carousel_ready),
        .data_out      (weight_carousel_data),
        .data_out_valid(weight_carousel_valid),
        .data_out_ready(weight_carousel_ready),
        .clk           (clk),
        .rst           (rst)
    );
    
    // ============================================================================
    // Weight Unpacking from Carousel Output
    // ============================================================================
    // Use the output from the carousel (which rotates through different slots)
    always_comb begin
        weights_available = weight_carousel_valid[0];
        for (int i = 0; i < INPUT_SIZE; i++) begin
            unpacked_weights[i] = weight_carousel_data[0][(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
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
                            if (pe_computing[pe_idx] && weights_available) begin
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
                                    (internal_input_vector[pe_element_counter] * unpacked_weights[pe_element_counter]);
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
    // Completion Detection
    // ============================================================================
    always_comb begin
        all_pe_done = &pe_done;
    end
    
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
                        // Weights loaded into carousel
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
    
    // Weight carousel ready signal - only ready when in LOAD_WEIGHTS state
    assign weight_carousel_ready[0] = (state == LOAD_WEIGHTS) && weights_valid;
    
    // Consume weights from carousel after loading
    always_ff @(posedge clk) begin
        if (state == LOAD_WEIGHTS && weights_valid && weights_ready) begin
            // Trigger carousel shift after loading
            weight_carousel_ready[0] <= 1'b0;
        end
    end

endmodule
