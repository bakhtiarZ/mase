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

logger = logging.getLogger("carousel_template_tb")
logger.setLevel(logging.INFO)

class carousel_template_tb(Testbench):
    def __init__(self, dut, dut_params) -> None:
        super().__init__(dut, dut.clk, dut.rst)
        self.buffer_size = dut_params["BUFFER_SIZE"]

        # Instantiate drivers and monitors per lane
        self.drivers = []
        self.monitors = []
        for i in range(self.buffer_size):
            drv = StreamDriver(
                clk=dut.clk,
                data=getattr(dut, f"data_in_{i}"),
                valid=getattr(dut, f"data_in_valid_{i}"),
                ready=getattr(dut, f"data_in_ready_{i}"),
                valid_prob=1.0  # always valid for deterministic test
            )
            mnt = StreamMonitor(
                clk=dut.clk,
                data=getattr(dut, f"data_out_{i}"),
                valid=getattr(dut, f"data_out_valid_{i}"),
                ready=getattr(dut, f"data_out_ready_{i}"),
                check=False  # disable automatic check for detailed test control
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

    async def run_test(self):
        # Start clock
        cocotb.start_soon(Clock(self.dut.clk, 10, units='ns').start())
        # Reset
        self.dut.rst.value = 1
        for _ in range(2):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0

        # Read parameters
        BUFFER_SIZE = int(self.dut.BUFFER_SIZE.value)
        WIDTH = int(self.dut.WIDTH.value)

        # Prepare deterministic, human-readable per-lane data
        data_points_per_lane = 5
        per_lane_data = []
        for lane in range(BUFFER_SIZE):
            lane_data = []
            for j in range(data_points_per_lane):
                # simple increasing pattern
                lane_data.append(lane + j*BUFFER_SIZE)
            per_lane_data.append(lane_data)

        # Compute expected rotated outputs per lane
        per_lane_expected = [self._rotate_expected(d) for d in per_lane_data]

        # Load drivers and monitors
        for i in range(BUFFER_SIZE):
            logger.info(f"Lane {i} data: {per_lane_data[i]}")
            logger.info(f"Lane {i} expected: {per_lane_expected[i]}")
            self.drivers[i].load_driver(per_lane_data[i])
            # preload expected queue but don't auto-check
            for exp in per_lane_expected[i]:
                self.monitors[i].expect(exp)

        # Initialize all data_out_ready signals high
        cycle_count = 0
        for mnt in self.monitors:
            mnt.ready.value = 1

        # Run until all inputs sent or timeout
        send_done = False
        while not send_done:
            await RisingEdge(self.dut.clk)
            cycle_count += 1
            # Drive deterministic ready low pattern on outputs
            for mnt in self.monitors:
                mnt.ready.value = 0 if cycle_count in OUTREADY_LOW_CYCLES else 1
            if all(drv.send_queue.empty() for drv in self.drivers):
                send_done = True
            if cycle_count >= MAX_WAIT_CYCLES:
                raise TestFailure(f"Timeout: inputs not sent after {MAX_WAIT_CYCLES} cycles")

        # Continue clocking until outputs all observed or timeout
        flush_cycles = 0
        while True:
            await RisingEdge(self.dut.clk)
            cycle_count += 1
            for mnt in self.monitors:
                mnt.ready.value = 0 if cycle_count in OUTREADY_LOW_CYCLES else 1
            # manually check observations against exp_queue
            for mnt in self.monitors:
                if not mnt.recv_queue.empty() and not mnt.exp_queue.empty():
                    got = mnt.recv_queue.get()
                    exp = mnt.exp_queue.get()
                    if got != exp:
                        raise TestFailure(f"Lane mismatch: got {got}, expected {exp}")
            done = all(mnt.exp_queue.empty() for mnt in self.monitors)
            if done:
                break
            flush_cycles += 1
            if flush_cycles >= MAX_WAIT_CYCLES:
                raise TestFailure(f"Timeout: outputs not received after flush {MAX_WAIT_CYCLES} cycles")

        logger.info("carousel_core TB passed: all lanes verified with backpressure pattern")

@cocotb.test()
async def test(dut):
    tb = carousel_template_tb(dut, DUT_PARAMS)
    await tb.run_test()

if __name__ == "__main__":
    from mase_cocotb.runner import mase_runner
    import torch
    torch.manual_seed(1)
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
