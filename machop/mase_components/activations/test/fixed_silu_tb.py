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
    def __init__(self, dut, num_words) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        # self.assign_self_params(
        #     [
        #         "DATA_IN_0_PRECISION_0",
        #         "DATA_IN_0_PRECISION_1",
        #         "DATA_IN_0_TENSOR_SIZE_DIM_0",
        #         "DATA_IN_0_TENSOR_SIZE_DIM_1",
        #         "DATA_IN_0_PARALLELISM_DIM_0",
        #         "DATA_IN_0_PARALLELISM_DIM_1",

        #         "DATA_OUT_0_PRECISION_0",
        #         "DATA_OUT_0_PRECISION_1",
        #         "DATA_OUT_0_TENSOR_SIZE_DIM_0",
        #         "DATA_OUT_0_TENSOR_SIZE_DIM_1",
        #         "DATA_OUT_0_PARALLELISM_DIM_0",
        #         "DATA_OUT_0_PARALLELISM_DIM_1",
        #     ]
        # )
        self.data_width = 8
        self.frac_width = 4

        self.outputwidth = 8
        self.outputfracw = 4

        self.num_words_per_input = num_words

        self.data_in_0_driver = StreamDriver(
            dut.clk, dut.data_in_0, dut.data_in_0_valid, dut.data_in_0_ready
        )
        self.data_out_0_monitor = StreamMonitor(
            dut.clk, dut.data_out_0, dut.data_out_0_valid, dut.data_out_0_ready
        )

    def exp(self, inputs):
        # Run the model with the provided inputs and return the outputs
        # cond = torch.logical_not(torch.logical_and(inputs <= self.thresh*2**self.frac_width, inputs >= -1 * self.thresh *2**self.frac_width))
        # out = torch.where(cond, inputs, torch.tensor(0))
        # unsignedout = torch.where(out < 0, torch.tensor(out % (2**self.data_width)), out)
        m = torch.nn.SiLU()(inputs.to(torch.float))
        m = self.dquantizer(m)
        # mout = m.clamp(min=-1*2**(self.outputwidth-1), max = 2**(self.outputwidth-1)-1)
        m2 = (m * 2 ** self.frac_width).to(torch.int64)
        m2 = torch.where(m2 < 0, (m2.clone().detach() % (2**self.outputwidth)), m2)
        # logger.info(f"out of silu and quantizer: {m}, int version {m2}")
        return m2.tolist()
        

    def generate_inputs(self,w,fracw):
        self.dquantizer = partial(
            integer_quantizer, width=self.data_width, frac_width=self.frac_width
        )
        # realinp = torch.tensor([1,1,1,1,1,1,1,1,1,1])
        realinp = torch.randn(self.num_words_per_input)
        inputs = self.dquantizer(realinp)
        intinp = (inputs * 2**self.frac_width).to(torch.int64)
        return intinp, inputs

    def doubletofx(self, num, data_width, f_width, type = "bin"):
        assert type == "bin" or type == "hex", "type can only be: 'hex' or 'bin'"
        intnum = int(num * 2**(f_width))
        intbits = BitArray(int=intnum, length=data_width)
        return str(intbits.bin) if type == 'bin' else str(intbits)

@cocotb.test()
async def test(dut):
    NUM_TEST_SAMPLES = 498

    nw_per_input = dut_params["DATA_IN_0_PARALLELISM_DIM_0"] * dut_params["DATA_IN_0_PARALLELISM_DIM_1"]
    tb = fixed_silu_tb(dut, num_words=nw_per_input)
    await tb.reset()
    logger.info(f"Reset finished")
    for i in range(NUM_TEST_SAMPLES):
        inputs, real_inp = tb.generate_inputs(tb.data_width,tb.frac_width)
        bin_inputs = [tb.doubletofx(num=x, data_width=tb.data_width, f_width=tb.frac_width) for x in real_inp]
        # logger.info(f"int inputs: {inputs}, bin inputs: {bin_inputs}, real_inputs: {real_inp}")
        exp_out = tb.exp(real_inp)
        tb.data_in_0_driver.append(inputs.tolist())
        tb.data_out_0_monitor.expect(exp_out)
    tb.data_out_0_monitor._trigger()
    
    # To do: replace with tb.load_monitors(exp_out)
    logger.info(f"DRIVER QUEUE SIZE {tb.data_in_0_driver.send_queue.qsize()}")
        
    
    # To do: replace with tb.run()
    await Timer(10, units="us")
    # To do: replace with tb.monitors_done() --> for monitor, call monitor_done()
    count=0
    if(not tb.data_out_0_monitor.exp_queue.empty()):
        while(not tb.data_out_0_monitor.exp_queue.empty()):
            count+=1
            logger.error(f"Expected queue not empty: {tb.data_out_0_monitor.exp_queue.get()}")
        logger.error(f"Expected queue not empty: {count}")
        assert 0==1

dut_params = {
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
if __name__ == "__main__":
    mase_runner(
        module_param_list=[
            dut_params
        ]
    )
