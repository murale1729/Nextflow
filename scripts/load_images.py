
import sys
import os

# Directory containing images
image_dir = sys.argv[1]

# List image files in the directory
image_files = [f for f in os.listdir(image_dir) if f.endswith(('.png', '.jpg', '.jpeg'))]

# Print each image file path
for image_file in image_files:
    print(os.path.join(image_dir, image_file))
