# scripts/convert_to_png.py
import sys
from PIL import Image

# Image file path
image_path = sys.argv[1]
output_path = sys.argv[2]

# Open the image
image = Image.open(image_path)

# Convert image to PNG and save
image.save(output_path, 'PNG')

print(f"Converted {image_path} -> {output_path}")
