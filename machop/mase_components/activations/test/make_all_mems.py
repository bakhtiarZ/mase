import generate_memory as gm
fs = ['elu', 'sigmoid', 'logsigmoid', 'softshrink']

d_width = 16
f_width = 0

d_widths = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
for f in fs:
    gm.generate_sv_lut(f, d_width, f_width, dir="/workspace/luts_for_test")

for f in ['silu']:
    for d in d_widths:
        gm.generate_sv_lut(f, d, f_width, dir="/workspace/luts_for_test")
