# scripts/process_image.py
import sys
from PIL import Image

# Image file path
image_path = sys.argv[1]

# Open the image
image = Image.open(image_path)

# Convert image to grayscale
gray_image = image.convert("L")

# Save the grayscale image
output_path = sys.argv[2]
gray_image.save(output_path)

print(f"Processed {image_path} -> {output_path}")
