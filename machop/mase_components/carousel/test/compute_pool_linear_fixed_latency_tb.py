#!/usr/bin/env python3
import os
import logging
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
from mase_cocotb.utils import clk_and_settled, get_bit
from mase_cocotb.runner import mase_runner
from mase_cocotb.testbench import Testbench
from dataclasses import dataclass
import numpy as np
import torch

os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
os.environ["COCOTB_DEBUG"] = "1"
logger = cocotb.log

# DUT parameters
DUT_PARAMS = {
    "DATA_WIDTH": 8,
    "INPUT_SIZE": 4,
    "OUT_SIZE": 4,
}

@dataclass
class StreamInterface:
    data: any
    valid: any
    ready: any

def pack_array(tensor_row: torch.tensor, data_width: int):
    mask = (1 << data_width) - 1
    packed = 0
    for i, e_t in enumerate(reversed(tensor_row)):
        e = e_t.item()
        assert e < (2**data_width - 1) - 1, f"Element at index {i} with value {e} cannot fit into {data_width} bits."
        if e < 0:
            e = (e + (1 << data_width)) & mask
        packed |= (e & mask) << i * data_width
    return packed
    
def set_initial_conditions(dut):
    # Setting the initial weight valids to HIGH, meaning the weights can be accepted into the carousel.
    # Weight matrix
    weight_matrix = torch.tensor([
            [0, 0, 1, 1], # row 1 etc
            [0, 0, 2, 1],
            [0, 0, 3, 1],
            [0, 0, 4, 1],
    ])
    
    x = torch.tensor(
        [4, 3, 2, 1],
    )
    
    def set_initial_weights_valid():
        binVal = (1 << dut.OUT_SIZE.value) - 1
        dut.initial_weights_valid.setimmediatevalue(binVal)
        logger.debug(f"\nSET dut.initial_weights_valid value to {dut.initial_weights_valid.value}") 

    # Setting the value of the initial weights
    def set_initial_weights_values(weight_matrix : torch.tensor):
        packed_weights_width = dut.DATA_WIDTH.value * dut.INPUT_SIZE.value
        for i, w_row in enumerate(weight_matrix):
            dut.initial_weights[i].setimmediatevalue(pack_array(w_row, dut.DATA_WIDTH.value))
            hexval = f"0x{dut.initial_weights[i].value.integer:0{packed_weights_width//4}x}"
            logger.debug(f"\nSET dut.initial_weights[{i}] value to {hexval}")
    
    def set_initial_x_valid():
        dut.x_value_valid.setimmediatevalue(1)
        
    def set_initial_x_values(x : torch.tensor):
        packed_x_value_width = dut.DATA_WIDTH.value * dut.INPUT_SIZE.value
        dut.x_value.setimmediatevalue(pack_array(x, dut.DATA_WIDTH.value))
        hexval = f"0x{dut.x_value.value.integer:0{packed_x_value_width//4}x}"
        logger.debug(f"\nSET dut.x_value to {hexval}")
    
    set_initial_weights_valid()
    set_initial_weights_values(weight_matrix)
    set_initial_x_valid()
    set_initial_x_values(x)
            
@cocotb.test()
async def procedural_carousel_core_test(dut):
    clk = dut.clk
    rst = dut.rst
    set_initial_conditions(dut)
    # data_in = getattr(dut, "data_in")
    # data_in_valid = getattr(dut, "data_in_valid")
    # data_in_ready = getattr(dut, "data_in_ready")
    data_out = getattr(dut, "data_out")
    data_out_valid = getattr(dut, "data_out_valid")
    # data_out_ready = getattr(dut, "data_out_ready")

    # Start clock
    cocotb.start_soon(Clock(clk, 10, units='ns').start())

    # 1. Reset behavior
    rst.value = 1
    for _ in range(2):
        await RisingEdge(clk)
    rst.value = 0
    await RisingEdge(clk)
    for i in range(60):
        await RisingEdge(clk)

if __name__ == "__main__":
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
