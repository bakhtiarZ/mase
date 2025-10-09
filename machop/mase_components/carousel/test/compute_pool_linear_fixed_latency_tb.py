#!/usr/bin/env python3
import os
import logging
import cocotb
from functools import partial
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
from mase_cocotb.utils import watch_register_changes, RegChangeMonitor, get_bit, pack_array, fmt_packed_vec
from mase_cocotb.runner import mase_runner
from mase_cocotb.testbench import Testbench
from dataclasses import dataclass
import numpy as np
import torch

os.environ["COCOTB_LOG_LEVEL"] = "INFO"
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

    
def set_initial_conditions(dut, initial_conds):

    weight_matrix = initial_conds['WEIGHTS']
    x = initial_conds['X']
    pe_layout = initial_conds['PE_LAYOUT']
    
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
    
    def set_reg_from_array(reg, layout):
        assert len(reg) == len(layout), "Register {reg._name} does not have equal size to array provided."
        pe_array_ready_sig = 0
        for i,e in enumerate(layout):
            if e == 1:
                pe_array_ready_sig |= 1 << i
        reg.setimmediatevalue(pe_array_ready_sig)

    set_initial_weights_valid()
    set_initial_weights_values(weight_matrix)
    set_initial_x_valid()
    set_initial_x_values(x)
    set_reg_from_array(dut.pe_array_ready, pe_layout)

def attach_monitors_to_carousel(dut, carousel_inst, pe_layout):
    output_list = []
    for i, entry in enumerate(carousel_inst.entries):
        if get_bit(dut.pe_array_ready, i) == 1:
            entry_bit_width = dut.INPUT_SIZE.value * dut.DATA_WIDTH.value
            mon = RegChangeMonitor(dut, entry, logger_prefix=f"[{carousel_inst._name}]", printer=partial(fmt_packed_vec, total_width=entry_bit_width, num_packed=dut.INPUT_SIZE.value))
            mon.start()
            logger.info(f"Monitor attached to slot {i} of {carousel_inst._name} {mon}")
            output_list.append(mon)
        elif get_bit(dut.pe_array_ready, i) != pe_layout[i]:
            logger.info(f"Could not attach monitor to PE at index [{i}] for {carousel_inst._name}")
    return output_list


@cocotb.test()
async def procedural_carousel_core_test(dut):
    clk = dut.clk
    rst = dut.rst
    initial_conditions = {
        'WEIGHTS' : torch.tensor([
            [0, 0, 1, 1], # row 1 etc
            [0, 0, 2, 1],
            [0, 0, 3, 1],
            [0, 0, 4, 1],
        ]),
        'X' : torch.tensor(
            [4, 3, 2, 1],
        ),
        'PE_LAYOUT' : [1, 0, 0, 0],
    }
    set_initial_conditions(dut, initial_conditions)
    logger.info(f"Setting these initial conditions: {initial_conditions}")
    # data_in = getattr(dut, "data_in")
    # data_in_valid = getattr(dut, "data_in_valid")
    # data_in_ready = getattr(dut, "data_in_ready")
    data_out = getattr(dut, "data_out")
    data_out_valid = getattr(dut, "data_out_valid")
    # data_out_ready = getattr(dut, "data_out_ready")
    input_carousel_monitors = attach_monitors_to_carousel(dut, dut.input_carousel_inst, initial_conditions['PE_LAYOUT'])
    output_carousel_monitors = attach_monitors_to_carousel(dut, dut.output_carousel_inst, initial_conditions['PE_LAYOUT'])
    # Start clock
    cocotb.start_soon(Clock(clk, 10, units='ns').start())

    # 1. Reset behavior
    rst.value = 1
    for _ in range(2):
        await RisingEdge(clk)
    rst.value = 0
    await RisingEdge(clk)
    for i in range(60):
        # Main test 

        await RisingEdge(clk)

if __name__ == "__main__":
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
