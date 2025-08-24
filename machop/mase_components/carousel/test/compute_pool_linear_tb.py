import os
import logging
os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
os.environ["COCOTB_DEBUG"] = "1"
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
from mase_cocotb.utils import clk_and_settled, get_bit
from mase_cocotb.runner import mase_runner
from mase_cocotb.testbench import Testbench
from dataclasses import dataclass

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

@cocotb.test()
async def procedural_carousel_core_test(dut):
    clk = dut.clk
    rst = dut.rst
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
