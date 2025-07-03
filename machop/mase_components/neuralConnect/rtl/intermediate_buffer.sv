/*
Create zero or more intermediate buffers for the data signals.

Can support multiple data inputs.

*/


`default_nettype wire
`timescale 1ps / 1ps


module intermediate_buffer #(

  // number of parallel data inputs
  NUM_DATA_INPUTS = 0,

  // number of buffers in the chain
  NUM_BUFFERS = 0,
  
  // should we maintain the timing of the data, i.e., if the buffer chain
  // stalls should we stall the entire chain, or allow buffered data to
  // "pool" at the end of the chain
  MAINTAIN_TIME_ORDER = "false",
  
  // data width...
  DATA_WIDTH  = 0
  
)(
  input  clk,
  
  input                   data_in_valid,
  input  [DATA_WIDTH-1:0] data_in [NUM_DATA_INPUTS-1:0],
  output                  data_in_ready,
  
  output                  data_out_valid,
  output [DATA_WIDTH-1:0] data_out [NUM_DATA_INPUTS-1:0],
  input                   data_out_ready
);

localparam MAINTAIN_TIME_ORDER_LOCAL = 1'b1 ? MAINTAIN_TIME_ORDER == "true" : 1'b0;

genvar buffer_num;
generate

  // simple passthrough
  if (NUM_BUFFERS == 0) begin
    assign data_in_ready  = data_out_ready;
    assign data_out_valid = data_in_valid;
    assign data_out       = data_in;
  end

  // 1 or more intermediate buffers
  else begin
    
    wire can_propagate_buffers;
    wire all_buffer_stages_valid;
    
    reg  [NUM_BUFFERS-1:0] valid_buffer = 0;
    reg  [DATA_WIDTH-1:0]  data_buffer  [NUM_BUFFERS-1:0] [NUM_DATA_INPUTS-1:0];
    
    initial begin
      int init_buffers, init_inputs;
      for (init_buffers = 0; init_buffers < NUM_BUFFERS; init_buffers = init_buffers + 1) begin
        for (init_inputs = 0; init_inputs < NUM_DATA_INPUTS; init_inputs = init_inputs + 1) begin
          data_buffer[init_buffers][init_inputs]  <= 0;
        end
      end
    end

    // are all the stage in the buffer currently valid
    assign all_buffer_stages_valid = valid_buffer == {NUM_BUFFERS{1'b1}};
    
    
    //#########################################################################
    // can only propagate the buffers and accept new data when:
    //#########################################################################
    
    // <when maintaining time order:>
    //  -the last stage is empty (i.e., there is space in the buffer chain) 
    //  OR
    //  -the last stage is full, but is being output now
    if (MAINTAIN_TIME_ORDER_LOCAL) begin
      assign can_propagate_buffers = ~data_out_valid | (data_out_valid & data_out_ready);
    end
    
    // <when NOT maintaining time order:>
    //  -at least 1 stage is invalid, i.e., empty
    //  OR
    //  -the last stage is full, but is being output now
    else begin
      assign can_propagate_buffers = ~all_buffer_stages_valid | (data_out_valid & data_out_ready);
    end
    
    //#########################################################################                             
    
    /*
    // propagate data and valid signals through the buffers
    for (buffer_num = 0; buffer_num < NUM_BUFFERS; buffer_num = buffer_num + 1) begin
      always @(posedge clk) begin
        
        
        
        // are we accepting new data
        if (can_propagate_buffers) begin
      
          // first buffer gets its data from the input
          if (buffer_num == 0) begin
            
            // buffer the input valid signal
            valid_buffer[buffer_num] <= data_in_valid;
            
            // buffer the input data
            if (data_in_valid) begin
              data_buffer[buffer_num]  <= data_in;
            end
            
          end
          
          
          // all other buffers get their data and valid signals from the previous buffer stage
          else begin
          
            // if we can ONLY progress the buffer when all stages can progress
            if (MAINTAIN_TIME_ORDER_LOCAL) begin
              valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
              data_buffer[buffer_num]  <= data_buffer[buffer_num-1];
            end
            
            // we can progress THIS stage of the chain if:
            //  -the previous stage is valid (i.e., new data)
            //  AND
            //  -the current stage is invalid (i.e., we don't overwrite valid data in this stage)
            else begin
              
              // last stage needs to check data_out_ready 
              if (buffer_num == NUM_BUFFERS-1) begin
                
                // if we are storing data
                if (valid_buffer[buffer_num]) begin
                  
                  // only overwrite it if our data can move through the chain
                  if (valid_buffer[buffer_num+1]
                  
                end
                
                valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
                
                if (valid_buffer[buffer_num-1] & ~data_out_ready) begin
                  valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
                  data_buffer[buffer_num]  <= data_buffer[buffer_num-1];
                end
                
              end
            
              else begin
              
                if (valid_buffer[buffer_num-1] & ~valid_buffer[buffer_num]) begin
                  valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
                  data_buffer[buffer_num]  <= data_buffer[buffer_num-1];
                end
              
              end
            
            end
            
          end // buffer_num
        end // propagate
      end
    end
    */
    
    
    
    
    
    // propagate data and valid signals through the buffers
    for (buffer_num = 0; buffer_num < NUM_BUFFERS; buffer_num = buffer_num + 1) begin
      
      
      // there is space further down the chain if:
      //  -at least 1 buffer is empty
      //  OR
      //  -the last buffer is getting out now
      wire   space_further_down_chain;
      if (buffer_num == NUM_BUFFERS-1) begin
        assign space_further_down_chain = data_out_ready;
      end
      else begin
        assign space_further_down_chain = valid_buffer[(NUM_BUFFERS-buffer_num)-1:0] != {NUM_BUFFERS-buffer_num{1'b1}}
                                        | (data_out_valid & data_out_ready);
      end
      
    
      always @(posedge clk) begin
        
        // if we can ONLY progress the buffer when all stages can progress
        if (MAINTAIN_TIME_ORDER_LOCAL) begin
        
          // are we accepting new data
          if (can_propagate_buffers) begin
        
            // first buffer gets its data from the input
            if (buffer_num == 0) begin
              
              // buffer the input valid signal
              valid_buffer[buffer_num] <= data_in_valid;
              
              // buffer the input data
              if (data_in_valid) begin
                data_buffer[buffer_num]  <= data_in;
              end
              
            end
            
            // all other buffers get their data and valid signals from the previous buffer stage
            else begin
              valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
              data_buffer[buffer_num]  <= data_buffer[buffer_num-1];
              
            end
          
          end // propagate
          
        end // MAINTAIN_TIME_ORDER_LOCAL
        
        
        // else, we can progress individual stages in the chain
        else begin
          
          // are we accepting new data
          if (can_propagate_buffers) begin
          
            // first buffer gets its data from the input
            if (buffer_num == 0) begin
              
              // buffer the input valid signal
              valid_buffer[buffer_num] <= data_in_valid;
              
              // buffer the input data
              if (data_in_valid) begin
                data_buffer[buffer_num]  <= data_in;
              end
              
            end
            
            
            // all other buffers get their data and valid signals from the previous buffer stage
            else begin
            
              // we can progress THIS stage of there is space further down the chain
              if (space_further_down_chain) begin
                valid_buffer[buffer_num] <= valid_buffer[buffer_num-1];
                data_buffer[buffer_num]  <= data_buffer[buffer_num-1];
              end
              
            end
          
          end // propagate
          
        end
      end
    end
    
    
    assign data_in_ready  = can_propagate_buffers;
    assign data_out_valid = valid_buffer[NUM_BUFFERS-1];
    assign data_out       = data_buffer[NUM_BUFFERS-1];
    
    
  end
  
endgenerate


endmodule : intermediate_buffer
