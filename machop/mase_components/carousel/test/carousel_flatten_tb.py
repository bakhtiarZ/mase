#!/usr/bin/env python3
import os
import logging
os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
os.environ["COCOTB_DEBUG"] = "1"
import sys
sys.stderr = sys.stdout

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from mase_cocotb.utils import clk_and_settled, get_bit
from dataclasses import dataclass  
from mase_cocotb.runner import mase_runner
import torch
from mase_cocotb.testbench import Testbench
from mase_cocotb.interfaces.streaming import StreamDriver, StreamMonitor

# Global DUT parameters (used for both build and test)
DUT_PARAMS = {
    "WIDTH": 8,
    "BUFFER_SIZE": 3
}


# Timeout in clock cycles after which test is declared failed
MAX_WAIT_CYCLES = 1000

# Deterministic pattern for data_out_ready: deassert on these cycles
OUTREADY_LOW_CYCLES = {5, 12, 20, 37}

@dataclass
class StreamInterface:
    data: any
    valid: any
    ready: any

logger = logging.getLogger("carousel_template_tb")
logger.setLevel(logging.DEBUG)

class carousel_template_tb(Testbench):
    def __init__(self, dut, dut_params) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        self.buffer_size = dut_params["BUFFER_SIZE"]

        # Instantiate drivers and monitors per lane
        self.drivers = []
        self.monitors = []
        for i in range(self.buffer_size):
            drv = StreamInterface(
                data=getattr(dut, f"data_in_{i}"),
                valid=getattr(dut, f"data_in_valid_{i}"),
                ready=getattr(dut, f"data_in_ready_{i}")
            )
            mnt = StreamInterface(
                data=getattr(dut, f"data_out_{i}"),
                valid=getattr(dut, f"data_out_valid_{i}"),
                ready=getattr(dut, f"data_out_ready_{i}")
            )
            self.drivers.append(drv)
            self.monitors.append(mnt)

    def _rotate_expected(self, data_list):
        expected = []
        buf = []
        for d in data_list:
            buf.append(d)
            if len(buf) == self.buffer_size:
                buf = buf[1:] + buf[:1]
                expected.extend(buf)
                buf = []
        return expected

    def check_shifted(self, regs):
        logger.info(f"Register values: {[int(r) for r in regs]}")

    def print_carousel_registers(self, dut):
        """Print values of regs (unpacked) and holding (flattened vector)"""
        try:
            buffer_size = len(dut.regs)
        except TypeError:
            raise RuntimeError("Could not determine buffer size. Check that regs is accessible.")

        # Flattened vector access: convert holding to an integer, then extract bits
        holding_val = dut.holding.value.integer

        logger.info("\n--- Carousel Register Values ---")
        for i in range(buffer_size):
            reg_val = dut.regs[i].value.integer
            logger.info(f"  regs[{i}]    = {reg_val}")
        logger.info(f"\n")
        for i in range(buffer_size):
            hold_bit = (holding_val >> i) & 1
            logger.info(f"  holding[{i}] = {hold_bit}")
        
        logger.info("--------------------------------\n")

    

    async def run_test(self):
        # Start clock
        cocotb.start_soon(Clock(self.dut.clk, 10, units='ns').start())
        # Reset
        core_inst = self.dut.core_inst
        regs = getattr(core_inst, "regs")
        dut = self.dut
        # output_ready all 0
        for i, monitor in enumerate(self.monitors):
            monitor.ready.value = 0
        dut.rst.value = 1
        for _ in range(2):
            await clk_and_settled(dut.clk)

        dut.rst.value = 0
        assert core_inst.state.value == 0, "after reset, state isnt IDLE"
        assert all(r == 0 for r in regs), "Not all registers are zero after reset"
        await clk_and_settled(dut.clk)
        BUFFER_SIZE = int(dut.BUFFER_SIZE.value)
        WIDTH = int(dut.WIDTH.value)
        for i, driver in enumerate(self.drivers):
            driver.data.value = i * 10
            driver.valid.value = 1
            assert driver.ready.value == 1, f"Driver with index {i}, has an input ready signal of {driver.ready.value} which comes from dut signal data_in_ready_{i} with value {getattr(dut, f'data_in_ready_{i}').value}"  
        
        await clk_and_settled(dut.clk)

        # check reg values
        self.print_carousel_registers(core_inst)
        assert core_inst.all_ingest.value == 1, f"1 clock after the drivers drove values, all ingest is still low"
        for i, monitor in enumerate(self.monitors):
            assert monitor.valid.value == 1, "data out valid not valid after ingesting"
        await clk_and_settled(dut.clk)
        assert core_inst.state.value == 1, f"1 clock after drivers drove values, state isn't in shift"
        await clk_and_settled(dut.clk)
        self.check_shifted(regs)
        await clk_and_settled(dut.clk)
        self.check_shifted(regs)
        for i, monitor in enumerate(self.monitors):
            assert monitor.valid.value == 1, "data out valid not valid during shifts"
        self.monitors[0].ready.value = 1 # drive one monitor ready high
        await clk_and_settled(dut.clk)
        assert get_bit(core_inst.holding, 0) == 0, "holding[0] is not 0, reg didnt dispense" # check that reg dispensed
        self.monitors[1].ready.value = 1 # drive one monitor ready high
        self.monitors[2].ready.value = 1 # drive one monitor ready high
        await clk_and_settled(dut.clk)
        assert core_inst.holding.value == 0
        await clk_and_settled(dut.clk)
        assert core_inst.state.value == 0
        print(f"Test ran with no assertions thrown")

@cocotb.test()
async def test(dut):
    tb = carousel_template_tb(dut, DUT_PARAMS)
    try:
        await tb.run_test()
    except Exception as e:
        logger.info(f"Test failed: {e}")
        raise  # Re-raise so test still fails

if __name__ == "__main__":

    torch.manual_seed(1)
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
