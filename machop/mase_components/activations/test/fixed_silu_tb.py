#!/usr/bin/env python3

# This script tests the fixed point linear
import os, logging
import pdb
from bitstring import BitArray
import cocotb
from functools import partial
from cocotb.triggers import *
from chop.passes.graph.transforms.quantize.quantizers import *
from mase_cocotb.testbench import Testbench 
from mase_cocotb.interfaces.streaming import StreamDriver, StreamMonitor
from mase_cocotb.z_qlayers import quantize_to_int
from mase_cocotb.runner import mase_runner
from mase_cocotb.utils import bit_driver, sign_extend_t

# from chop.passes.graph.transforms.quantize.quantized_modules import LinearInteger

import torch

logger = logging.getLogger("testbench")
logger.setLevel(logging.INFO)


class fixed_silu_tb(Testbench):
    def __init__(self, dut) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        self.assign_self_params(
            [
                "DATA_IN_0_PRECISION_0",
                "DATA_IN_0_PRECISION_1",
                "DATA_IN_0_TENSOR_SIZE_DIM_0",
                "DATA_IN_0_TENSOR_SIZE_DIM_1",
                "DATA_IN_0_PARALLELISM_DIM_0",
                "DATA_IN_0_PARALLELISM_DIM_1",

                "DATA_OUT_0_PRECISION_0",
                "DATA_OUT_0_PRECISION_1",
                "DATA_OUT_0_TENSOR_SIZE_DIM_0",
                "DATA_OUT_0_TENSOR_SIZE_DIM_1",
                "DATA_OUT_0_PARALLELISM_DIM_0",
                "DATA_OUT_0_PARALLELISM_DIM_1",
            ]
        )
        self.width = 8
        self.fracw = 4

        self.outputwidth = 8
        self.outputfracw = 4

        self.samples = 10

        self.data_in_0_driver = StreamDriver(
            dut.clk, dut.data_in_0, dut.data_in_0_valid, dut.data_in_0_ready
        )
        self.data_out_0_monitor = StreamMonitor(
            dut.clk, dut.data_out_0, dut.data_out_0_valid, dut.data_out_0_ready
        )
        self.thresh = 0.5

    def exp(self, inputs):
        # Run the model with the provided inputs and return the outputs
        # cond = torch.logical_not(torch.logical_and(inputs <= self.thresh*2**self.fracw, inputs >= -1 * self.thresh *2**self.fracw))
        # out = torch.where(cond, inputs, torch.tensor(0))
        # unsignedout = torch.where(out < 0, torch.tensor(out % (2**self.width)), out)
        m = torch.nn.SiLU()(inputs.to(torch.float))
        m = self.dquantizer(m)
        # mout = m.clamp(min=-1*2**(self.outputwidth-1), max = 2**(self.outputwidth-1)-1)
        m2 = (m * 2 ** self.fracw).to(torch.int64)
        m2 = torch.where(m2 < 0, torch.tensor(m2 % (2**self.outputwidth)), m2)
        logger.info(f"out of silu and quantizer: {m}, int version {m2}")
        return m2.tolist()
        

    def generate_inputs(self,w,fracw):
        self.dquantizer = partial(
            integer_quantizer, width=self.width, frac_width=self.fracw
        )
        # realinp = torch.tensor([3,3,3,3,3,3,3,3,3,3])
        realinp = torch.randn(self.samples)
        inputs = self.dquantizer(realinp)
        intinp = (inputs * 2**self.fracw).to(torch.int64)
        return intinp, inputs

    def doubletofx(self, num, data_width, f_width, type = "bin"):
        assert type == "bin" or type == "hex", "type can only be: 'hex' or 'bin'"
        intnum = int(num * 2**(f_width))
        intbits = BitArray(int=intnum, length=data_width)
        return str(intbits.bin) if type == 'bin' else str(intbits)

@cocotb.test()
async def test(dut):
    tb = fixed_silu_tb(dut)
    await tb.reset()
    logger.info(f"Reset finished")
    tb.data_out_0_monitor.ready.value = 1

    inputs, real_inp = tb.generate_inputs(tb.width,tb.fracw)
    bin_inputs = [tb.doubletofx(num=x, data_width=tb.width, f_width=tb.fracw) for x in real_inp]
    logger.info(f"int inputs: {inputs}, bin inputs: {bin_inputs}, real_inputs: {real_inp}")
    exp_out = tb.exp(real_inp)

    tb.data_in_0_driver.append(inputs.tolist())
    # To do: replace with tb.load_monitors(exp_out)
    tb.data_out_0_monitor.expect(exp_out)
    # To do: replace with tb.run()
    await Timer(10, units="us")
    # To do: replace with tb.monitors_done() --> for monitor, call monitor_done()
    assert tb.data_out_0_monitor.exp_queue.empty()


if __name__ == "__main__":
    mase_runner(
        module_param_list=[
            {
                "DATA_IN_0_TENSOR_SIZE_DIM_0": 10,
                "DATA_IN_0_TENSOR_SIZE_DIM_1": 1,
                "DATA_IN_0_PARALLELISM_DIM_0": 10,
                "DATA_IN_0_PARALLELISM_DIM_1": 1,
                "DATA_IN_0_PRECISION_0": 8,
                "DATA_IN_0_PRECISION_1": 4,

                "DATA_OUT_0_PRECISION_0": 8,
                "DATA_OUT_0_PRECISION_1": 4,
                "DATA_OUT_0_TENSOR_SIZE_DIM_0": 10,
                "DATA_OUT_0_TENSOR_SIZE_DIM_1": 1,
                "DATA_OUT_0_PARALLELISM_DIM_0": 10,
                "DATA_OUT_0_PARALLELISM_DIM_1": 1,

            }
        ]
    )
