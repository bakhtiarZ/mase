#!/usr/bin/env python3

import os
import shutil
from datetime import datetime
from pathlib import Path
import sys
import os, logging
import pdb
import cocotb
from functools import partial
from cocotb.triggers import *
# from chop.passes.graph.transforms.quantize.quantizers  *
from mase_cocotb.testbench import Testbench
from mase_cocotb.interfaces.streaming import (
    StreamDriver,
    StreamMonitor,
    StreamMonitorFloat,
)
from mase_cocotb.z_qlayers import quantize_to_int
from mase_cocotb.runner import mase_runner
from mase_cocotb.utils import bit_driver, sign_extend_t
from math import ceil


import torch
from pathlib import Path

logger = logging.getLogger("testbench")
logger.setLevel(logging.INFO)

class shift_register_tb(Testbench):
    def __init__(self, dut, dut_params) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        
        self.width = dut_params["WIDTH"]
        self.buffer_size = dut_params["BUFFER_SIZE"]

        self.data_in_driver = StreamDriver(
            dut.clk, dut.data_in, dut.data_in_valid, dut.data_in_ready
        )

        self.data_out_monitor = StreamMonitor(
            dut.clk, dut.data_out, dut.data_out_valid, dut.data_out_ready, check=False
        )

        self.real_in_tensor = torch.randint(
            low=0,
            high=10,
            size=(1, self.buffer_size),
            dtype=torch.int32  # or torch.int64
        )
        self.int_inp = self.real_in_tensor // 1  # Convert to integer by flooring
        logger.info(f"INT INPUT: \n{self.int_inp}")

 
    def shift(self, tensor):
        # Shift the tensor to the right in a circular manner
        shifted_tensor = torch.roll(tensor, shifts=1, dims=1)
        return shifted_tensor
        
    def exp(self):
        expout = self.shift(self.int_inp.clone().detach())  # For shift register, expected output is the same as input
        return expout 

    async def run_test(self):
        await self.reset()
        logger.info(f"Reset finished")
        self.data_out_monitor.ready.value = 1
        for i in range(1):
            inputs = self.int_inp.tolist()
            exp_out = self.exp().tolist()
            # exp_out.append([1,2,3,4])
            # exp_out.append([1,2,3,4])
            # exp_out.append([1,2,3,4])
            # exp_out.append([1,2,3,4])
            logger.info("Inputs and expected generated")
            logger.info(f"DUT IN: {inputs}")
            logger.info(f"DUT EXP OUT: {exp_out}")
            self.data_in_driver.load_driver(inputs)
            self.data_out_monitor.load_monitor(exp_out)
            
        await Timer(1000, units="us")
        assert self.data_out_monitor.exp_queue.empty()


@cocotb.test()
async def test(dut):
    tb = shift_register_tb(dut, dut_params)
    await tb.run_test()


dut_params = {
    "WIDTH": 8,
    "BUFFER_SIZE": 4,
}

torch.manual_seed(1)
if __name__ == "__main__":
    # getRTL()
    # rtl_path = Path("/homes/bm920/workspace/mase/machop/mase_components/neuralConnect/rtl")
    # layerSrc = rtl_path / 'layerSrc'
    # to_include = [rtl_path, layerSrc]
    mase_runner(module_param_list=[dut_params],
                trace=True,
                extra_build_args = ['--timing']
                                )
