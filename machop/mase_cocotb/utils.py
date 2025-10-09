import random
from copy import copy

from cocotb.triggers import RisingEdge, ReadOnly, Timer, Edge
import cocotb.log
import torch
from torch import Tensor

from mase_cocotb.z_qlayers import quantize_to_int


def binary_encode(x):
    assert x in [-1, 1]
    return 0 if x == -1 else 1


def binary_decode(x):
    assert x in [0, 1]
    return -1 if x == 0 else 1


async def bit_driver(signal, clk, prob):
    while True:
        await RisingEdge(clk)
        signal.value = 1 if random.random() < prob else 0


def sign_extend_t(value: Tensor, bits: int):
    sign_bit = 1 << (bits - 1)
    return (value.int() & (sign_bit - 1)) - (value.int() & sign_bit)


def sign_extend(value: int, bits: int):
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def signed_to_unsigned(value: Tensor, bits: int):
    mask = (1 << bits) - 1
    return value & mask


def floor_rounding(value, in_frac_width, out_frac_width):
    if in_frac_width > out_frac_width:
        return value >> (in_frac_width - out_frac_width)
    elif in_frac_width < out_frac_width:
        return value << (in_frac_width - out_frac_width)
    return value


async def clk_and_settled(clk):
    """
    Wait for a rising edge on `clk` and for all signal updates to settle.
    This ensures you observe stable post-clock values.
    """
    await RisingEdge(clk)
    await ReadOnly()
    await Timer(0)

def expect(condition, msg):
    if not condition:
        cocotb.log.error(f"[EXPECT FAILED] {msg}")
    else:
        cocotb.log.info(f"[EXPECT PASSED] {msg}")

def get_bit(signal, index):
    """Access a specific bit of a flat signal."""
    return (int(signal.value) >> index) & 1

def pack_array(tensor_row: torch.tensor, data_width: int):
    mask = (1 << data_width) - 1
    packed = 0
    for i, e_t in enumerate(reversed(tensor_row)):
        e = e_t.item()
        assert e < (2**data_width - 1) - 1, f"Element at index {i} with value {e} cannot fit into {data_width} bits."
        if e < 0:
            e = (e + (1 << data_width)) & mask
        packed |= (e & mask) << i * data_width
    return packed

async def watch_register_changes(dut, register_name):
    prev = None
    register = getattr(dut, register_name)
    assert register is not None, f"Couldn't find a register with name {register}"
    while True:
        await Edge(register)
        await ReadOnly()
        cur = register
        if prev is None or cur != prev:
            dut._log.info(f"[MONITOR] {register_name} changed -> {cur} at t={cocotb.utils.get_sim_time('ns')} ns")
            prev = cur

def fmt_packed_vec(val, name, total_width, num_packed):
    if val:
        val_masked = val.integer & ((1 << total_width) - 1) # Mask the bottom 'total_width' bits
        return f"0x{val_masked:0{total_width//4}x}"


class RegChangeMonitor:
    def __init__(self, dut, sig, logger_prefix = "", printer = None):
        self.dut, self.sig = dut, sig
        self.prev = None
        self.printer = printer
        self.logger_prefix = logger_prefix

    def start(self):
        cocotb.start_soon(self._run())
    
    def __str__(self):
        return f"{self.dut._name}::{self.sig._name}"

    def _fmt(self, val, name):
        return self.printer(val, name) if self.printer else val
    
    async def _run(self):
        while True:
            await Edge(self.sig)
            await ReadOnly()
            cur = self.sig.value
            if self.prev is None or cur != self.prev:
                cur_fmt = self._fmt(cur, "cur")
                prev_fmt = self._fmt(self.prev, "prev")
                self.dut._log.info(f"{self.logger_prefix} {self.sig._name} changed -> {cur_fmt} (prev={prev_fmt})")
                self.prev = cur

