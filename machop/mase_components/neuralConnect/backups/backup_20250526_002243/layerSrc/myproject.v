// ==============================================================
// RTL generated by Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2020.2 (64-bit)
// Version: 2020.2
// Copyright (C) Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// 
// ===========================================================

`timescale 1 ns / 1 ps 

(* CORE_GENERATION_INFO="myproject_myproject,hls_ip_2020_2,{HLS_INPUT_TYPE=cxx,HLS_INPUT_FLOAT=0,HLS_INPUT_FIXED=0,HLS_INPUT_PART=xcu250-figd2104-2L-e,HLS_INPUT_CLOCK=5.000000,HLS_INPUT_ARCH=pipeline,HLS_SYN_CLOCK=3.490000,HLS_SYN_LAT=14,HLS_SYN_TPT=5,HLS_SYN_MEM=2,HLS_SYN_DSP=0,HLS_SYN_FF=1611,HLS_SYN_LUT=4425,HLS_VERSION=2020_2}" *)

module myproject (
        ap_clk,
        ap_rst,
        ap_start,
        ap_done,
        ap_idle,
        ap_ready,
        dense_input_address0,
        dense_input_ce0,
        dense_input_q0,
        dense_input_address1,
        dense_input_ce1,
        dense_input_q1,
        layer5_out,
        layer5_out_ap_vld
);

parameter    ap_ST_fsm_pp0_stage0 = 5'd1;
parameter    ap_ST_fsm_pp0_stage1 = 5'd2;
parameter    ap_ST_fsm_pp0_stage2 = 5'd4;
parameter    ap_ST_fsm_pp0_stage3 = 5'd8;
parameter    ap_ST_fsm_pp0_stage4 = 5'd16;

input   ap_clk;
input   ap_rst;
input   ap_start;
output   ap_done;
output   ap_idle;
output   ap_ready;
output  [3:0] dense_input_address0;
output   dense_input_ce0;
input  [15:0] dense_input_q0;
output  [3:0] dense_input_address1;
output   dense_input_ce1;
input  [15:0] dense_input_q1;
output  [15:0] layer5_out;
output   layer5_out_ap_vld;

reg ap_done;
reg ap_idle;
reg ap_ready;
reg layer5_out_ap_vld;

(* fsm_encoding = "none" *) reg   [4:0] ap_CS_fsm;
wire    ap_CS_fsm_pp0_stage0;
reg    ap_enable_reg_pp0_iter0;
reg    ap_enable_reg_pp0_iter1;
reg    ap_enable_reg_pp0_iter2;
reg    ap_idle_pp0;
wire    ap_CS_fsm_pp0_stage4;
wire    ap_block_state5_pp0_stage4_iter0;
wire    ap_block_state10_pp0_stage4_iter1;
wire    ap_block_state15_pp0_stage4_iter2;
wire    ap_block_pp0_stage4_11001;
reg   [15:0] layer2_out_V_0_reg_173;
wire    ap_CS_fsm_pp0_stage1;
wire    ap_block_state2_pp0_stage1_iter0;
wire    ap_block_state7_pp0_stage1_iter1;
wire    ap_block_state12_pp0_stage1_iter2;
wire    ap_block_pp0_stage1_11001;
reg   [15:0] layer2_out_V_1_reg_178;
reg   [15:0] layer2_out_V_2_reg_183;
reg   [15:0] layer2_out_V_3_reg_188;
reg   [15:0] layer2_out_V_4_reg_193;
reg   [15:0] layer2_out_V_5_reg_198;
reg   [15:0] layer2_out_V_6_reg_203;
reg   [15:0] layer2_out_V_7_reg_208;
reg   [15:0] layer2_out_V_8_reg_213;
reg   [15:0] layer2_out_V_9_reg_218;
reg   [15:0] layer3_out_V_0_reg_223;
reg   [15:0] layer3_out_V_1_reg_228;
reg   [15:0] layer3_out_V_2_reg_233;
reg   [15:0] layer3_out_V_3_reg_238;
reg   [15:0] layer3_out_V_4_reg_243;
reg   [15:0] layer3_out_V_5_reg_248;
reg   [15:0] layer3_out_V_6_reg_253;
reg   [15:0] layer3_out_V_7_reg_258;
reg   [15:0] layer3_out_V_8_reg_263;
reg   [15:0] layer3_out_V_9_reg_268;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_return;
reg   [15:0] layer4_out_V_0_reg_273;
reg    ap_enable_reg_pp0_iter0_reg;
wire    ap_block_pp0_stage4_subdone;
reg    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_start;
wire    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_done;
wire    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_idle;
wire    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_ready;
wire   [3:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address0;
wire    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce0;
wire   [3:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address1;
wire    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce1;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_0;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_1;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_2;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_3;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_4;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_5;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_6;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_7;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_8;
wire   [15:0] grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_9;
wire    grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start;
wire    grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_done;
wire    grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_idle;
wire    grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_ready;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_0;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_1;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_2;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_3;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_4;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_5;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_6;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_7;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_8;
wire   [15:0] grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_9;
reg    grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_ce;
wire    ap_block_state1_pp0_stage0_iter0_ignore_call28;
wire    ap_block_state6_pp0_stage0_iter1_ignore_call28;
wire    ap_block_state11_pp0_stage0_iter2_ignore_call28;
wire    ap_block_pp0_stage0_11001_ignoreCallOp46;
wire    ap_block_state2_pp0_stage1_iter0_ignore_call28;
wire    ap_block_state7_pp0_stage1_iter1_ignore_call28;
wire    ap_block_state12_pp0_stage1_iter2_ignore_call28;
wire    ap_block_pp0_stage1_11001_ignoreCallOp47;
wire    grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start;
wire    grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_done;
wire    grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_idle;
wire    grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_ready;
wire   [9:0] grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_return;
wire    ap_block_pp0_stage0;
wire    ap_block_pp0_stage1;
wire    ap_CS_fsm_pp0_stage2;
wire    ap_block_pp0_stage2;
wire    ap_CS_fsm_pp0_stage3;
wire    ap_block_pp0_stage3;
wire    ap_block_pp0_stage4;
reg    grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg;
reg    grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg;
wire    ap_block_pp0_stage4_01001;
reg   [4:0] ap_NS_fsm;
wire    ap_block_state1_pp0_stage0_iter0;
wire    ap_block_state6_pp0_stage0_iter1;
wire    ap_block_state11_pp0_stage0_iter2;
wire    ap_block_pp0_stage0_subdone;
reg    ap_idle_pp0_1to2;
wire    ap_block_pp0_stage0_11001;
wire    ap_block_pp0_stage1_subdone;
wire    ap_block_state3_pp0_stage2_iter0;
wire    ap_block_state8_pp0_stage2_iter1;
wire    ap_block_state13_pp0_stage2_iter2;
wire    ap_block_pp0_stage2_subdone;
wire    ap_block_pp0_stage2_11001;
wire    ap_block_state4_pp0_stage3_iter0;
wire    ap_block_state9_pp0_stage3_iter1;
wire    ap_block_state14_pp0_stage3_iter2;
wire    ap_block_pp0_stage3_subdone;
wire    ap_block_pp0_stage3_11001;
reg    ap_idle_pp0_0to1;
reg    ap_reset_idle_pp0;
wire    ap_enable_pp0;
wire    ap_ce_reg;

// power-on initialization
initial begin
#0 ap_CS_fsm = 5'd1;
#0 ap_enable_reg_pp0_iter1 = 1'b0;
#0 ap_enable_reg_pp0_iter2 = 1'b0;
#0 ap_enable_reg_pp0_iter0_reg = 1'b0;
#0 grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg = 1'b0;
#0 grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg = 1'b0;
end

myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .ap_start(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_start),
    .ap_done(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_done),
    .ap_idle(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_idle),
    .ap_ready(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_ready),
    .dense_input_address0(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address0),
    .dense_input_ce0(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce0),
    .dense_input_q0(dense_input_q0),
    .dense_input_address1(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address1),
    .dense_input_ce1(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce1),
    .dense_input_q1(dense_input_q1),
    .ap_return_0(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_0),
    .ap_return_1(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_1),
    .ap_return_2(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_2),
    .ap_return_3(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_3),
    .ap_return_4(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_4),
    .ap_return_5(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_5),
    .ap_return_6(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_6),
    .ap_return_7(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_7),
    .ap_return_8(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_8),
    .ap_return_9(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_9)
);

myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .ap_start(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start),
    .ap_done(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_done),
    .ap_idle(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_idle),
    .ap_ready(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_ready),
    .p_read(layer2_out_V_0_reg_173),
    .p_read1(layer2_out_V_1_reg_178),
    .p_read2(layer2_out_V_2_reg_183),
    .p_read3(layer2_out_V_3_reg_188),
    .p_read4(layer2_out_V_4_reg_193),
    .p_read5(layer2_out_V_5_reg_198),
    .p_read6(layer2_out_V_6_reg_203),
    .p_read7(layer2_out_V_7_reg_208),
    .p_read8(layer2_out_V_8_reg_213),
    .p_read9(layer2_out_V_9_reg_218),
    .ap_return_0(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_0),
    .ap_return_1(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_1),
    .ap_return_2(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_2),
    .ap_return_3(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_3),
    .ap_return_4(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_4),
    .ap_return_5(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_5),
    .ap_return_6(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_6),
    .ap_return_7(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_7),
    .ap_return_8(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_8),
    .ap_return_9(grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_9)
);

myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .p_read(layer3_out_V_0_reg_223),
    .p_read1(layer3_out_V_1_reg_228),
    .p_read2(layer3_out_V_2_reg_233),
    .p_read3(layer3_out_V_3_reg_238),
    .p_read4(layer3_out_V_4_reg_243),
    .p_read5(layer3_out_V_5_reg_248),
    .p_read6(layer3_out_V_6_reg_253),
    .p_read7(layer3_out_V_7_reg_258),
    .p_read8(layer3_out_V_8_reg_263),
    .p_read9(layer3_out_V_9_reg_268),
    .ap_return(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_return),
    .ap_ce(grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_ce)
);

myproject_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .ap_start(grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start),
    .ap_done(grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_done),
    .ap_idle(grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_idle),
    .ap_ready(grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_ready),
    .p_read(layer4_out_V_0_reg_273),
    .ap_return(grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_return)
);

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_CS_fsm <= ap_ST_fsm_pp0_stage0;
    end else begin
        ap_CS_fsm <= ap_NS_fsm;
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_enable_reg_pp0_iter0_reg <= 1'b0;
    end else begin
        if ((1'b1 == ap_CS_fsm_pp0_stage0)) begin
            ap_enable_reg_pp0_iter0_reg <= ap_start;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_enable_reg_pp0_iter1 <= 1'b0;
    end else begin
        if (((1'b0 == ap_block_pp0_stage4_subdone) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
            ap_enable_reg_pp0_iter1 <= ap_enable_reg_pp0_iter0;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_enable_reg_pp0_iter2 <= 1'b0;
    end else begin
        if (((1'b0 == ap_block_pp0_stage4_subdone) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
            ap_enable_reg_pp0_iter2 <= ap_enable_reg_pp0_iter1;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg <= 1'b0;
    end else begin
        if (((1'b0 == ap_block_pp0_stage1_11001) & (ap_enable_reg_pp0_iter2 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage1))) begin
            grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg <= 1'b1;
        end else if ((grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_ready == 1'b1)) begin
            grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg <= 1'b0;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg <= 1'b0;
    end else begin
        if (((1'b0 == ap_block_pp0_stage1_11001) & (ap_enable_reg_pp0_iter1 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage1))) begin
            grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg <= 1'b1;
        end else if ((grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_ready == 1'b1)) begin
            grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg <= 1'b0;
        end
    end
end

always @ (posedge ap_clk) begin
    if (((1'b0 == ap_block_pp0_stage1_11001) & (1'b1 == ap_CS_fsm_pp0_stage1))) begin
        layer2_out_V_0_reg_173 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_0;
        layer2_out_V_1_reg_178 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_1;
        layer2_out_V_2_reg_183 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_2;
        layer2_out_V_3_reg_188 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_3;
        layer2_out_V_4_reg_193 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_4;
        layer2_out_V_5_reg_198 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_5;
        layer2_out_V_6_reg_203 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_6;
        layer2_out_V_7_reg_208 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_7;
        layer2_out_V_8_reg_213 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_8;
        layer2_out_V_9_reg_218 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_return_9;
        layer4_out_V_0_reg_273 <= grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_return;
    end
end

always @ (posedge ap_clk) begin
    if (((1'b0 == ap_block_pp0_stage4_11001) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
        layer3_out_V_0_reg_223 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_0;
        layer3_out_V_1_reg_228 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_1;
        layer3_out_V_2_reg_233 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_2;
        layer3_out_V_3_reg_238 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_3;
        layer3_out_V_4_reg_243 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_4;
        layer3_out_V_5_reg_248 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_5;
        layer3_out_V_6_reg_253 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_6;
        layer3_out_V_7_reg_258 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_7;
        layer3_out_V_8_reg_263 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_8;
        layer3_out_V_9_reg_268 <= grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_return_9;
    end
end

always @ (*) begin
    if (((1'b0 == ap_block_pp0_stage4_11001) & (ap_enable_reg_pp0_iter2 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
        ap_done = 1'b1;
    end else begin
        ap_done = 1'b0;
    end
end

always @ (*) begin
    if ((1'b1 == ap_CS_fsm_pp0_stage0)) begin
        ap_enable_reg_pp0_iter0 = ap_start;
    end else begin
        ap_enable_reg_pp0_iter0 = ap_enable_reg_pp0_iter0_reg;
    end
end

always @ (*) begin
    if (((ap_idle_pp0 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage0) & (ap_start == 1'b0))) begin
        ap_idle = 1'b1;
    end else begin
        ap_idle = 1'b0;
    end
end

always @ (*) begin
    if (((ap_enable_reg_pp0_iter2 == 1'b0) & (ap_enable_reg_pp0_iter1 == 1'b0) & (ap_enable_reg_pp0_iter0 == 1'b0))) begin
        ap_idle_pp0 = 1'b1;
    end else begin
        ap_idle_pp0 = 1'b0;
    end
end

always @ (*) begin
    if (((ap_enable_reg_pp0_iter1 == 1'b0) & (ap_enable_reg_pp0_iter0 == 1'b0))) begin
        ap_idle_pp0_0to1 = 1'b1;
    end else begin
        ap_idle_pp0_0to1 = 1'b0;
    end
end

always @ (*) begin
    if (((ap_enable_reg_pp0_iter2 == 1'b0) & (ap_enable_reg_pp0_iter1 == 1'b0))) begin
        ap_idle_pp0_1to2 = 1'b1;
    end else begin
        ap_idle_pp0_1to2 = 1'b0;
    end
end

always @ (*) begin
    if (((1'b0 == ap_block_pp0_stage4_11001) & (ap_enable_reg_pp0_iter0 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
        ap_ready = 1'b1;
    end else begin
        ap_ready = 1'b0;
    end
end

always @ (*) begin
    if (((ap_idle_pp0_0to1 == 1'b1) & (ap_start == 1'b0))) begin
        ap_reset_idle_pp0 = 1'b1;
    end else begin
        ap_reset_idle_pp0 = 1'b0;
    end
end

always @ (*) begin
    if (((1'b0 == ap_block_pp0_stage0) & (ap_enable_reg_pp0_iter0 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage0))) begin
        grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_start = 1'b1;
    end else begin
        grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_ap_start = 1'b0;
    end
end

always @ (*) begin
    if ((((1'b0 == ap_block_pp0_stage1_11001_ignoreCallOp47) & (1'b1 == ap_CS_fsm_pp0_stage1)) | ((1'b0 == ap_block_pp0_stage0_11001_ignoreCallOp46) & (1'b1 == ap_CS_fsm_pp0_stage0)))) begin
        grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_ce = 1'b1;
    end else begin
        grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67_ap_ce = 1'b0;
    end
end

always @ (*) begin
    if (((1'b0 == ap_block_pp0_stage4_11001) & (ap_enable_reg_pp0_iter2 == 1'b1) & (1'b1 == ap_CS_fsm_pp0_stage4))) begin
        layer5_out_ap_vld = 1'b1;
    end else begin
        layer5_out_ap_vld = 1'b0;
    end
end

always @ (*) begin
    case (ap_CS_fsm)
        ap_ST_fsm_pp0_stage0 : begin
            if ((~((ap_idle_pp0_1to2 == 1'b1) & (ap_start == 1'b0)) & (1'b0 == ap_block_pp0_stage0_subdone))) begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage1;
            end else begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage0;
            end
        end
        ap_ST_fsm_pp0_stage1 : begin
            if ((1'b0 == ap_block_pp0_stage1_subdone)) begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage2;
            end else begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage1;
            end
        end
        ap_ST_fsm_pp0_stage2 : begin
            if ((1'b0 == ap_block_pp0_stage2_subdone)) begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage3;
            end else begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage2;
            end
        end
        ap_ST_fsm_pp0_stage3 : begin
            if ((1'b0 == ap_block_pp0_stage3_subdone)) begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage4;
            end else begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage3;
            end
        end
        ap_ST_fsm_pp0_stage4 : begin
            if ((((ap_reset_idle_pp0 == 1'b0) & (1'b0 == ap_block_pp0_stage4_subdone)) | ((ap_reset_idle_pp0 == 1'b1) & (1'b0 == ap_block_pp0_stage4_subdone)))) begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage0;
            end else begin
                ap_NS_fsm = ap_ST_fsm_pp0_stage4;
            end
        end
        default : begin
            ap_NS_fsm = 'bx;
        end
    endcase
end

assign ap_CS_fsm_pp0_stage0 = ap_CS_fsm[32'd0];

assign ap_CS_fsm_pp0_stage1 = ap_CS_fsm[32'd1];

assign ap_CS_fsm_pp0_stage2 = ap_CS_fsm[32'd2];

assign ap_CS_fsm_pp0_stage3 = ap_CS_fsm[32'd3];

assign ap_CS_fsm_pp0_stage4 = ap_CS_fsm[32'd4];

assign ap_block_pp0_stage0 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage0_11001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage0_11001_ignoreCallOp46 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage0_subdone = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage1 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage1_11001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage1_11001_ignoreCallOp47 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage1_subdone = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage2 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage2_11001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage2_subdone = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage3 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage3_11001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage3_subdone = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage4 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage4_01001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage4_11001 = ~(1'b1 == 1'b1);

assign ap_block_pp0_stage4_subdone = ~(1'b1 == 1'b1);

assign ap_block_state10_pp0_stage4_iter1 = ~(1'b1 == 1'b1);

assign ap_block_state11_pp0_stage0_iter2 = ~(1'b1 == 1'b1);

assign ap_block_state11_pp0_stage0_iter2_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state12_pp0_stage1_iter2 = ~(1'b1 == 1'b1);

assign ap_block_state12_pp0_stage1_iter2_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state13_pp0_stage2_iter2 = ~(1'b1 == 1'b1);

assign ap_block_state14_pp0_stage3_iter2 = ~(1'b1 == 1'b1);

assign ap_block_state15_pp0_stage4_iter2 = ~(1'b1 == 1'b1);

assign ap_block_state1_pp0_stage0_iter0 = ~(1'b1 == 1'b1);

assign ap_block_state1_pp0_stage0_iter0_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state2_pp0_stage1_iter0 = ~(1'b1 == 1'b1);

assign ap_block_state2_pp0_stage1_iter0_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state3_pp0_stage2_iter0 = ~(1'b1 == 1'b1);

assign ap_block_state4_pp0_stage3_iter0 = ~(1'b1 == 1'b1);

assign ap_block_state5_pp0_stage4_iter0 = ~(1'b1 == 1'b1);

assign ap_block_state6_pp0_stage0_iter1 = ~(1'b1 == 1'b1);

assign ap_block_state6_pp0_stage0_iter1_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state7_pp0_stage1_iter1 = ~(1'b1 == 1'b1);

assign ap_block_state7_pp0_stage1_iter1_ignore_call28 = ~(1'b1 == 1'b1);

assign ap_block_state8_pp0_stage2_iter1 = ~(1'b1 == 1'b1);

assign ap_block_state9_pp0_stage3_iter1 = ~(1'b1 == 1'b1);

assign ap_enable_pp0 = (ap_idle_pp0 ^ 1'b1);

assign dense_input_address0 = grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address0;

assign dense_input_address1 = grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_address1;

assign dense_input_ce0 = grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce0;

assign dense_input_ce1 = grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45_dense_input_ce1;

assign grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start = grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_start_reg;

assign grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start = grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51_ap_start_reg;

assign layer5_out = grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81_ap_return;

endmodule //myproject
