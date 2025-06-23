#!/usr/bin/env python3

import os
import shutil
from datetime import datetime
from pathlib import Path
import sys
sys.stderr = sys.stdout

import os, logging
import pdb
import cocotb
import traceback
from functools import partial
from cocotb.triggers import *
# from chop.passes.graph.transforms.quantize.quantizers  *
from mase_cocotb.testbench import Testbench
from mase_cocotb.interfaces.streaming import (
    StreamDriver,
    StreamArrayDriver,
    StreamMonitor,
    StreamArrayMonitor,
    StreamMonitorFloat,
)
from mase_cocotb.z_qlayers import quantize_to_int
from mase_cocotb.runner import mase_runner
from mase_cocotb.utils import bit_driver, sign_extend_t
from math import ceil
import warnings
warnings.simplefilter("error")  # turn all warnings into exceptions


import torch
from pathlib import Path

logger = logging.getLogger("testbench")
logger.setLevel(logging.INFO)

class carousel_template_tb(Testbench):
    def __init__(self, dut, dut_params) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        print(f'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!{repr(self.dut.data_out_valid_arr)}\n!!!!')
        # self.width = dut_params["WIDTH"]
        self.buffer_size = dut_params["BUFFER_SIZE"]

        self.data_in_0_driver = StreamArrayDriver(
            dut.clk, dut.data_in_0, dut.data_in_valid_arr, dut.data_in_ready_arr, index=0
        )

        self.data_in_1_driver = StreamArrayDriver(
            dut.clk, dut.data_in_1, dut.data_in_valid_arr, dut.data_in_ready_arr, index=1
        )

        self.data_in_2_driver = StreamArrayDriver(
            dut.clk, dut.data_in_2, dut.data_in_valid_arr, dut.data_in_ready_arr, index=2
        )

        self.data_out_0_monitor = StreamArrayMonitor(
            dut.clk, dut.data_out_0, dut.data_out_valid_arr, dut.data_out_ready_arr, index=0, check=False
        )

        self.data_out_1_monitor = StreamArrayMonitor(
            dut.clk, dut.data_out_1, dut.data_out_valid_arr, dut.data_out_ready_arr, index=1, check=False
        )

        self.data_out_2_monitor = StreamArrayMonitor(
            dut.clk, dut.data_out_2, dut.data_out_valid_arr, dut.data_out_ready_arr, index=2, check=False
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
        try:
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
                self.data_in_0_driver.load_driver(inputs[0])
                self.data_in_1_driver.load_driver(inputs[1])
                self.data_in_2_driver.load_driver(inputs[2])
                self.data_out_0_monitor.load_monitor(exp_out[1])
                self.data_out_1_monitor.load_monitor(exp_out[2])
                self.data_out_2_monitor.load_monitor(exp_out[0])
                
            await Timer(1000, units="us")
            assert self.data_out_0_monitor.exp_queue.empty()
            assert self.data_out_1_monitor.exp_queue.empty()
            assert self.data_out_2_monitor.exp_queue.empty()
        except Exception:
            logger.exception("Exception in run_test")
            raise
                

@cocotb.test()
async def test(dut):
    # import pdb;
    # pdb.set_trace()
    try:
        tb = carousel_template_tb(dut, dut_params)
    except Exception:
        logger.exception("Exception in run_test")
        raise

    await tb.run_test()


dut_params = {
    "WIDTH_0": 8,
    "WIDTH_1": 8,
    "WIDTH_2": 8,
    "BUFFER_SIZE": 3,
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
