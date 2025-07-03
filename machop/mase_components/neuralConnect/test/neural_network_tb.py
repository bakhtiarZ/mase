#!/usr/bin/env python3

import os
import shutil
from datetime import datetime
from pathlib import Path
import sys
import os, logging
import pdb
from bitstring import BitArray
import cocotb
from functools import partial
from cocotb.triggers import *
from chop.passes.graph.transforms.quantize.quantizers import *
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

# from chop.passes.graph.transforms.quantize.quantized_modules import LinearInteger

import torch
from pathlib import Path

logger = logging.getLogger("testbench")
logger.setLevel(logging.INFO)


def getRTL():
    OUTPUTS_DIR = Path("/mnt/ccnas2/bdp/bm920/compute-pool/hls4ml-helper/.scratch")
    RTL_DIR    = Path("../rtl")
    INTERMEDIATE_BUFFER = Path("/homes/bm920/workspace/compute-pool/source/intermediate_buffer.sv")
    timestamp   = datetime.now().strftime("%Y%m%d_%H%M%S")
    BACKUP_DIR  = Path("../backups") / f"backup_{timestamp}"
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    for item in RTL_DIR.iterdir():
        dest = BACKUP_DIR / item.name
    if item.is_dir():
        shutil.copytree(item, dest, dirs_exist_ok=True)
    else:
        shutil.copy2(item, dest)

    for child in RTL_DIR.iterdir():
        if child.name == "intermediate_buffer.sv":
            continue
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
    shutil.copy2(INTERMEDIATE_BUFFER, RTL_DIR / "intermediate_buffer.sv")
    try:
        latest_dir = max(
            (d for d in OUTPUTS_DIR.iterdir() if d.is_dir()),
            key=lambda p: p.stat().st_mtime,
        )
    except ValueError:
        sys.exit(f"No sub-directories found inside {OUTPUTS_DIR}")

    logger.info(f"Latest data directory detected: {latest_dir}")
    source_compute_pool = latest_dir / "computePoolGen"
    if not source_compute_pool.is_dir():
        sys.exit(f"{source_compute_pool} does not exist – cannot proceed.")

    for item in source_compute_pool.iterdir():
        dest = RTL_DIR / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest)

    logger.info(f"Backup stored in {BACKUP_DIR} and RTL updated from {source_compute_pool}")

    top_level = RTL_DIR / 'wrapper_myproject.sv'
    top_level.rename(RTL_DIR / 'neural_network.sv')

def split_and_flatten_2d_tensor(input_tensor, row_block_size, col_block_size):
    rows, cols = input_tensor.size()

    num_row_blocks = rows // row_block_size
    num_col_blocks = cols // col_block_size

    reshaped_tensor = input_tensor.view(
        num_row_blocks, row_block_size, num_col_blocks, col_block_size
    )
    reshaped_tensor = reshaped_tensor.permute(0, 2, 1, 3).contiguous()
    flattened_tensor = reshaped_tensor.view(-1, row_block_size * col_block_size)
    return flattened_tensor


class neural_network_tb(Testbench):
    def __init__(self, module, dut, dut_params, float_test=False) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        
        self.num_in_features = dut_params["NUM_DATA_INPUTS"]
        self.num_in_batches = 1

        self.num_out_features = dut_params["NUM_DATA_OUTPUTS"]
        self.num_out_batches = 1
     
        self.data_in_driver = StreamDriver(
            dut.ap_clk, dut.data_in, dut.data_in_valid, dut.ap_ready
        )

        self.data_out_monitor = StreamMonitor(
            dut.clk, dut.data_out, dut.data_out_valid, dut.ap_start, check=False
        )

        self.model = torch.nn.Identity()
        self.real_in_tensor = torch.randn(1, self.num_in_features)
        self.real_inp = self.real_in_tensor
        self.quant_in_tensor = self.in_dquantizer(self.real_in_tensor)
        self.real_out_tensor = self.model(self.quant_in_tensor)

        logger.info(f"REAL IN TENSOR: \n{self.real_in_tensor}")
        logger.info(f"REAL OUT TENSOR: \n{self.real_out_tensor}")

    def exp(self):
        # Run the model with the provided inputs and return the expected integer outputs in the format expected by the monitor
        m = split_and_flatten_2d_tensor(
            self.real_out_tensor,
            self.size_out_feature_blocks,
            self.size_out_feature_blocks,
        )  # match output
        # m = self.real_out_tensor
        logger.info(f"EXP - FLOAT OUTPUT: \n{m}")
        m = self.out_dquantizer(m)
        m2 = (m * 2**self.outputfracw).to(torch.int64)
        m2 = m2.clone().detach() % (2**self.outputwidth)

        return m2

    def generate_inputs(self):
        # Generate the integer inputs for the DUT in the format expected by the driver
        inputs = split_and_flatten_2d_tensor(
            self.real_in_tensor, self.size_in_feature_blocks, self.size_in_feature_blocks
        )
        logger.info(f"FLOAT INPUT: \n{inputs}")
        inputs = self.in_dquantizer(inputs) * 5
        intinp = (inputs * 2**self.frac_width).to(torch.int64)
        return intinp, inputs

    def doubletofx(self, num, data_width, f_width, type="bin"):
        assert type == "bin" or type == "hex", "type can only be: 'hex' or 'bin'"
        intnum = int(num * 2 ** (f_width))
        intbits = BitArray(int=intnum, length=data_width)
        return str(intbits.bin) if type == "bin" else str(intbits)

    async def run_test(self):
        await self.reset()
        logger.info(f"Reset finished")
        self.data_out_monitor.ready.value = 1
        for i in range(1):
            inputs, real_tensor = self.generate_inputs()
            exp_out = self.exp()
            logger.info(f"exp out {exp_out}")
            inputs = inputs.tolist()
            exp_out = exp_out.tolist()
            logger.info("Inputs and expected generated")
            logger.info(f"DUT IN: {inputs}")
            logger.info(f"DUT EXP OUT: {exp_out}")
            self.data_in_0_driver.load_driver(inputs)
            self.data_out_0_monitor.load_monitor(exp_out)

        await Timer(1000, units="us")
        assert self.data_out_monitor.exp_queue.empty()


@cocotb.test()
async def test(dut):
    in_data_width = dut_params["INPUT_DATA_WIDTH"]
    out_data_width = dut_params["OUTPUT_DATA_WIDTH"]
    tb = neural_network_tb(torch.nn.Identity(), dut, dut_params, float_test=False)
    await tb.run_test()


dut_params = {
    # "NUM_DATA_INPUTS": 10,
    "NUM_DATA_INPUTS": 1, # needs to be 2 to match the axi input? still figuring this one out!
    "INPUT_DATA_WIDTH": 16,
    "NUM_DATA_OUTPUTS": 2,
    "OUTPUT_DATA_WIDTH": 16,
}

torch.manual_seed(1)
if __name__ == "__main__":
    # getRTL()
    rtl_path = Path("/homes/bm920/workspace/mase/machop/mase_components/neuralConnect/rtl")
    layerSrc = rtl_path / 'layerSrc'
    to_include = [rtl_path, layerSrc]
    mase_runner(module_param_list=[dut_params],
                trace=True,
                extra_build_args = ['--timing'],
                includes=to_include
                )
