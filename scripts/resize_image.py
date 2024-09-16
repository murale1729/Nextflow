# scripts/resize_image.py
import sys
from PIL import Image

# Image file path
image_path = sys.argv[1]
output_path = sys.argv[2]

# Open the image
image = Image.open(image_path)

# Resize image to 300x300 pixels
resized_image = image.resize((300, 300))

# Save the resized image
resized_image.save(output_path)

print(f"Resized {image_path} -> {output_path}")
