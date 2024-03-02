import sys
import torch
import pdb
import torch.nn as nn
import torch.nn.functional as F
from chop.passes.graph.transforms.quantize.quantizers.integer import *
import pdb
from bitstring import BitArray
from functools import partial

def make_quantizer(data_width:int, f_width:int):
    return partial(
                integer_quantizer, width=data_width, frac_width=f_width
            )

FUNCTION_TABLE = {
    'silu' : nn.SiLU(),
    'elu': nn.ELU(),
    'sigmoid': nn.Sigmoid(),
    'logsigmoid': nn.LogSigmoid(),
    'softshrink': nn.Softshrink(),
}

def fxtodouble(data_width: int, f_width: int, fx_num: str):
    intstr, fracstr = fx_num[:data_width-f_width], fx_num[data_width-f_width:]
    intval = float(BitArray(bin=intstr).int)
    fracval  = float(BitArray(bin=fracstr).uint) / 2 ** (f_width)

    return intval + fracval

def doubletofx(data_width: int, f_width: int, num: float, type = "hex"):
    assert type == "bin" or type == "hex", "type can only be: 'hex' or 'bin'"
    intnum = int(num * 2**(f_width))
    intbits = BitArray(int=intnum, length=data_width)
    return str(intbits.bin) if type == 'bin' else str(intbits)

def generate_lookup(data_width: int, f_width: int, function : str, type = "hex"):
    f = FUNCTION_TABLE[function]
    lut = {'data_width': data_width,
           'f_width' : f_width,
           'func' : FUNCTION_TABLE[function]}
    # entries = 2 ** data_width
    minval = float(-2 ** (data_width-f_width-1))
    maxval = (2**(data_width-1) - 1) * 2**(-f_width)
    i = minval
    quanter = make_quantizer(data_width, f_width)
    count = 0
    iarr = []
    while i <= maxval:
        count +=1
        iarr.append(i)
        val = quanter(f(torch.tensor(i))) # entry in the lookup table
        lut[doubletofx(data_width=data_width, f_width=f_width, num=i, type=type)] = doubletofx(data_width=data_width, f_width=f_width, num=val.item(), type=type)
        i+= 2 ** -(f_width)
    return lut

def aligned_generate_lookup(data_width: int, f_width: int, function : str, type = "hex"):
    f = FUNCTION_TABLE[function]
    lut = {'data_width': data_width,
           'f_width' : f_width,
           'func' : FUNCTION_TABLE[function]}
    # entries = 2 ** data_width
    minval = float(-2 ** (data_width-f_width-1))
    maxval = (2**(data_width-1) - 1) * 2**(-f_width)
    quanter = make_quantizer(data_width, f_width)
    count = 0
    iarr = []
    pi = float(0)
    while pi <= maxval:
        count +=1
        iarr.append(pi)
        val = quanter(f(torch.tensor(pi))) # entry in the lookup table
        lut[doubletofx(data_width=data_width, f_width=f_width, num=pi, type=type)] = doubletofx(data_width=data_width, f_width=f_width, num=val.item(), type=type)
        pi += 2 ** -(f_width)
    i = minval
    while i <= -1 * 2**-(f_width):
        count +=1
        iarr.append(i)
        val = quanter(f(torch.tensor(i))) # entry in the lookup table
        lut[doubletofx(data_width=data_width, f_width=f_width, num=i, type=type)] = doubletofx(data_width=data_width, f_width=f_width, num=val.item(), type=type)
        i+= 2 ** -(f_width)
    iarr = [(x * 2 **(f_width)) for x in iarr]
    # print(iarr)
    return lut


def testlookup(lut):
    d = lut['data_width']
    f = lut['f_width']
    func = lut['func']
    quanter = make_quantizer(d,f)
    for k, v in lut.items():
        if v == d or v==f or v == func:
            continue
        inp = fxtodouble(d,f,k)
        outactual = func(torch.tensor(inp))
        outactual = quanter(outactual).item()
        outlut = fxtodouble(d,f,v)
        failed = (abs(outactual - outlut) > 0.001)
        if failed:
            print("bin val", k)
            print("to double", inp)
            print("double from nn silu", outactual)
            print(f"double from lut {outlut}, bin from lut {v}")
            print("\n")

def lookup_to_file(data_width: int, f_width: int, function: str, file_path = None):
    dicto = aligned_generate_lookup(data_width=data_width, f_width=f_width, function=function, type="bin")
    dicto = {k: v for k, v in dicto.items() if k not in ['data_width', 'f_width', 'func']}  
    with open(file_path, "w") as file:
    # Write values to the file separated by spaces
        file.write('\n'.join(str(value) for value in dicto.values()))

function_name = input("Enter the function name: ")
assert function_name in FUNCTION_TABLE, f"Function {function_name} not found in FUNCTION_TABLE"
lookup_to_file(8, 4, function_name, f'/workspace/machop/mase_components/activations/rtl/{function_name}_map.memb')
# print(generate_lookup(8,4,"silu", "bin"))
# quanter = make_quantizer(8,4)
# a = doubletofx(8,0,46,"bin")
# q = doubletofx(8,0,48,"bin")
# print(a, q)
# b = fxtodouble(8,4,a)
# c = nn.SiLU()(torch.tensor(3.0))
# d = quanter(c)
# e = doubletofx(8,4,d,"bin")
# f = d * 2**(4)
# print(a,b,c,d,e,f)


