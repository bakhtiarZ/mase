import random
from copy import copy

from cocotb.triggers import RisingEdge, ReadOnly, Timer
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