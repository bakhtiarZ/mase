import generate_memory as gm
fs = ['silu', 'elu', 'sigmoid', 'logsigmoid', 'softshrink']

d_width = 8
f_width = 4

for f in fs:
    gm.generate_mem(f, d_width, f_width)
    gm.generate_sv_lut(f, d_width, f_width)