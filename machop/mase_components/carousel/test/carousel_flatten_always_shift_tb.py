# Pseudocode for procedural test of carousel_core
# ----------------------------------------------
# Test Scenario:
# 1. Reset Behavior
#    - Assert rst for 2 cycles
#    - On next cycle, all regs[] == 0, holding[] == 0, data_in_ready[]=1, data_out_valid[]=0
# 2. Single-slot ingest
#    - Drive data_in_valid[0]=1, data_in[0]=A, data_out_ready[]=0 for N cycles
#    - Expect that reg[0]=A, holding[0]=1, data_in_ready[0]=0, data_out_valid[0]=1
# 3. Continuous shifting with backpressure
#    - After ingest, release data_out_ready[0]=1
#    - On each cycle, if holding[], data_out_valid[]=1 and data moves around ring
#    - Verify after BUFFER_SIZE shifts that A returns to slot 0
# 4. Mixed ingest and shift
#    - While A is being shifted, drive data_in_valid[0]=1 with B
#    - Expect B to enter reg[0] when it becomes empty, not overwrite A prematurely
# 5. Full ring test
#    - Ingest N distinct values into each slot
#    - Run N cycles with data_out_ready low to stall
#    - Then enable data_out_ready for all lanes and verify correct rotation of all values

import os
import logging
os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
os.environ["COCOTB_DEBUG"] = "1"
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer
from cocotb.result import TestFailure
from mase_cocotb.utils import clk_and_settled, get_bit
from mase_cocotb.runner import mase_runner
from mase_cocotb.testbench import Testbench
from dataclasses import dataclass

# DUT parameters
DUT_PARAMS = {
    "WIDTH": 8,
    "BUFFER_SIZE": 3
}
BUFFER_SIZE = DUT_PARAMS["BUFFER_SIZE"]
WIDTH = DUT_PARAMS["WIDTH"]
@dataclass
class StreamInterface:
    data: any
    valid: any
    ready: any

@cocotb.test()
async def procedural_carousel_core_test(dut):
    """
    Procedural test of carousel_core per the pseudocode.
    """
    core_inst = dut.core_inst
    clk = dut.clk
    rst = dut.rst
    drivers = []
    monitors = []
    for i in range(BUFFER_SIZE):
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
        drivers.append(drv)
        monitors.append(mnt)

    # Start clock
    cocotb.start_soon(Clock(clk, 10, units='ns').start())

    # 1. Reset behavior
    rst.value = 1
    for _ in range(2):
        await RisingEdge(clk)
    rst.value = 0
    await RisingEdge(clk)
    # Check initial state
    # regs[] should be zero
    for i in range(BUFFER_SIZE):
        assert core_inst.regs[i].value.integer == 0, f"regs[{i}] != 0 after reset"
    # holding bits: use value.integer
    holding_val = core_inst.holding.value.integer
    for i in range(BUFFER_SIZE):
        assert ((holding_val >> i) & 1) == 0, f"holding[{i}] != 0 after reset"
        assert drivers[i].ready.value == 1,   f"data_in_ready[{i}] should be 1"
        assert drivers[i].valid.value == 0,  f"data_out_valid[{i}] should be 0"
        
    # 2. Single-slot ingest
    A = 0xAA
    # drive only lane 0
    drivers[0].valid.value = 1
    drivers[0].data.value = A
    # inhibit output consumption
    for i in range(BUFFER_SIZE):
        monitors[i].ready.value = 0
    await RisingEdge(clk)
    # after one cycle
    await Timer(0)
    assert core_inst.regs[0].value.integer == A, "reg[0] did not ingest A"
    holding_val = core_inst.holding.value.integer
    assert ((holding_val >> 0) & 1) == 1, "holding[0] not set"
    assert drivers[0].ready.value == 0, "data_in_ready[0] should go low"
    assert drivers[0].valid.value == 1, "data_out_valid[0] should be high"
    drivers[0].valid.value = 0

    # 3. Continuous shifting with backpressure
    # now allow output consume on lane 0
    monitors[0].ready.value = 1
    initial = [core_inst.regs[i].value.integer for i in range(BUFFER_SIZE)]
    for _ in range(BUFFER_SIZE):
        await RisingEdge(clk)
    # after BUFFER_SIZE shifts, original A should return
    await Timer(0) # wait for signals to settle
    assert core_inst.regs[0].value.integer == initial[0], "value did not rotate correctly"

    # 4. Mixed ingest and shift
    B = 0x55
    monitors[0].ready.value = 0
    drivers[0].valid.value = 1
    drivers[0].data.value = B
    await RisingEdge(clk)
    # register 0 should shift previous value, not ingest B
    assert core_inst.regs[0].value.integer != B, "B was ingested prematurely"
    drivers[0].valid.value = 0

    # 5. Full ring test
    vals = [0x10, 0x20, 0x30]
    # ingest into all lanes
    for i in range(BUFFER_SIZE):
        drivers[i].valid.value = 1
        drivers[i].data.value = vals[i]
        monitors[i].ready.value = 0
    await RisingEdge(clk)
    # clear valids
    for i in range(BUFFER_SIZE):
        drivers[i].valid.value = 0
    # rotate and consume at lane 0
    for _ in range(BUFFER_SIZE):
        monitors[0].ready.value = 1
        await RisingEdge(clk)
        await RisingEdge(clk)
    # expected rotated
    rotated = [vals[(j+1)%BUFFER_SIZE] for j in range(BUFFER_SIZE)]
    for j in range(BUFFER_SIZE):
        assert core_inst.regs[j].value.integer == rotated[j], f"Lane {j} rotated incorrectly"

    cocotb.log.info("Procedural carousel_core test passed!")


if __name__ == "__main__":
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
