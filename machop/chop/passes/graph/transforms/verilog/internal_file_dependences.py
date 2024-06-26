INTERNAL_RTL_DEPENDENCIES = {
    "linear": [
        "cast/rtl/fixed_cast.sv",
        "linear/rtl/fixed_linear.sv",
        "fixed_arithmetic/rtl/fixed_dot_product.sv",
        "fixed_arithmetic/rtl/fixed_accumulator.sv",
        "fixed_arithmetic/rtl/fixed_vector_mult.sv",
        "fixed_arithmetic/rtl/fixed_adder_tree.sv",
        "fixed_arithmetic/rtl/fixed_adder_tree_layer.sv",
        "fixed_arithmetic/rtl/fixed_mult.sv",
        "common/rtl/register_slice.sv",
        "common/rtl/skid_buffer.sv",
        "common/rtl/join2.sv",
        "cast/rtl/fixed_rounding.sv",
    ],
    "relu": ["activations/fixed_relu.sv"],
    "hardshrink": ["activations/fixed_hardshrink.sv"],
    "silu": ["activations/fixed_silu.sv"],
    "elu": ["activations/fixed_elu.sv"],
    "sigmoid": ["activations/fixed_sigmoid.sv"],
    "softshrink": ["activations/fixed_softshrink.sv"],
    "logsigmoid": ["activations/fixed_logsigmoid.sv"],
    "softmax": ["activations/fixed_softmax.sv"],
}
