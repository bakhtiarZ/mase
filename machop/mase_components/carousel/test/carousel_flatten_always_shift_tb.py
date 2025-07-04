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
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer
from cocotb.result import TestFailure
from mase_cocotb.utils import clk_and_settled, get_bit
from mase_cocotb.runner import mase_runner
from mase_cocotb.testbench import Testbench
from dataclasses import dataclass

logger = logging.getLogger("carousel_template_tb")
logger.setLevel(logging.DEBUG)
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

@dataclass
class Entry:
    valid: any
    data: any

def get_entry(logic: int, width: int = DUT_PARAMS['WIDTH']):
    raw_value = logic.value
    mask = (1 << width) - 1
    data = raw_value & mask
    valid = raw_value >> width & 0x1
    return Entry(valid, data)


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
        assert get_entry(core_inst.entries[i]).data == 0, f"regs[{i}] != 0 after reset"
    # holding bits: use value.integer
    for i in range(BUFFER_SIZE):
        assert get_entry(core_inst.entries[i]).valid == 0, f"entries.valid[{i}] != 0 after reset"
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
    await ReadOnly()
    assert get_entry(core_inst.entries[0]).data == A, "reg[0] did not ingest A"
    assert get_entry(core_inst.entries[0]).valid == 1, "holding[0] not set"
    assert drivers[0].ready.value == 0, "data_in_ready[0] should go low"
    assert drivers[0].valid.value == 1, "data_out_valid[0] should be high"
    await FallingEdge(clk)
    drivers[0].valid.value = 0

    # 3. Continuous shifting with backpressure
    # now allow output consume on lane 0
    assert get_entry(core_inst.entries[0]).data == A, "not holding A anymore"
    assert get_entry(core_inst.entries[0]).valid == 1, "not valid even when holding A"
    
    monitors[0].ready.value = 1
    initial = [get_entry(core_inst.entries[i]).data for i in range(BUFFER_SIZE)]
    for i in range(BUFFER_SIZE):
        if i == 1:
            await ReadOnly()
            assert get_entry(core_inst.entries[BUFFER_SIZE-1]).valid == 0, "A didn't dispense properly" 
            assert get_entry(core_inst.entries[BUFFER_SIZE-1]).data == A, "A dispensed properly, but somehow lost it's value of A" 
        await RisingEdge(clk)
    # after BUFFER_SIZE shifts, original A should return
    await ReadOnly()
    assert get_entry(core_inst.entries[0]).data == initial[0], "value did not rotate correctly"

    # 4. Mixed ingest and shift
    B = 0x55
    await FallingEdge(clk)
    monitors[0].ready.value = 0
    drivers[0].valid.value = 1
    drivers[0].data.value = B
    await RisingEdge(clk)
    await ReadOnly()
    # register 0 should take B rather than shift the value from register 1
    assert get_entry(core_inst.entries[0]).valid == 1, "B is not valid"
    assert get_entry(core_inst.entries[0]).data == B, "B was not ingested"
    assert monitors[0].valid.value == 1, f"data out valid is not high after {B} should've been ingested"
    await FallingEdge(clk)
    drivers[0].valid.value = 0
    monitors[BUFFER_SIZE-1].ready.value = 1
    await RisingEdge(clk)
    await ReadOnly()
    assert monitors[BUFFER_SIZE-1].valid.value == 1, f"data out valid is not high after {B} should've shifted"
    assert monitors[BUFFER_SIZE-1].data.value == B, f"data out is not {B} even though it should've shifted"
    await RisingEdge(clk) 
    await ReadOnly() 
    for i in range(BUFFER_SIZE):
        assert get_entry(core_inst.entries[i]).valid == 0, f"regs[{i}] valid is HIGH when it should be LOW, with data {hex(get_entry(core_inst.entries[i]).data)}" 
    # 5. Full ring test
    # Log the current simulation time and start of full ring stimulus
    logger.info(f"Current simulation time: {cocotb.utils.get_sim_time('ns')} ns")
    logger.info("Beginning full ring stimulus section")
    vals = [0x10, 0x20, 0x30]
    await FallingEdge(clk)
    # ingest into all lanes
    for i in range(BUFFER_SIZE):
        drivers[i].valid.value = 1
        drivers[i].data.value = vals[i]
        monitors[i].ready.value = 0
    await RisingEdge(clk)
    await ReadOnly()
    for i in range(BUFFER_SIZE):
        assert get_entry(core_inst.entries[i]).data == vals[i], f"regs[{i}] != {vals[i]}"
        assert get_entry(core_inst.entries[i]).valid == 1, f"regs[{i}] valid is LOW"
    # clear valids
    await FallingEdge(clk)
    for i in range(BUFFER_SIZE):
        drivers[i].valid.value = 0
    # rotate and consume at lane 0
    rotated = [vals[(j+1)%BUFFER_SIZE] for j in range(BUFFER_SIZE)]
    for iter in range(BUFFER_SIZE):
        if iter != 0:
            rotated = [rotated[(j+1)%BUFFER_SIZE] for j in range(BUFFER_SIZE)] 
        await RisingEdge(clk)
        await ReadOnly()
        for j in range(BUFFER_SIZE):
            assert hex(get_entry(core_inst.entries[j]).data) == hex(rotated[j]), f"Lane {j} rotated incorrectly, simulation time: {cocotb.utils.get_sim_time('ns')} ns"
    # expected rotated
    # rotated = [vals[(j+1)%BUFFER_SIZE] for j in range(BUFFER_SIZE)]
    # for j in range(BUFFER_SIZE):
    #     assert get_entry(core_inst.entries[j]).data == rotated[j], f"Lane {j} rotated incorrectly"

    cocotb.log.info("Procedural carousel_core test passed!")


if __name__ == "__main__":
    mase_runner(module_param_list=[DUT_PARAMS], trace=True, extra_build_args=['--timing'])
