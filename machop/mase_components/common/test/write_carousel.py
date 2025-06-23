import os
from jinja2 import Environment, FileSystemLoader

# Global constants
TEMPLATE_DIR = '../rtl'
TEMPLATE_FILE = 'carousel_template.j2'
OUTPUT_FILE = 'carousel_template.sv'

# Hardcoded input data
input_data = {
    'register_widths': [2, 4, 8],
    'buffer_size': 3
}

# Load the Jinja2 template from the specified directory
env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
template = env.get_template(TEMPLATE_FILE)

# Render the template with the hardcoded dictionary
rendered_output = template.render(input_data)

# Write the rendered output to a .sv file
output_path = os.path.join(TEMPLATE_DIR, OUTPUT_FILE)
with open(output_path, 'w') as f:
    f.write(rendered_output)

print(f"Rendered output written to {output_path}")
