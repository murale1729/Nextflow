# scripts/add_watermark.py
import sys
from PIL import Image, ImageDraw, ImageFont

# Check for the correct number of arguments
if len(sys.argv) != 3:
    print("Usage: python add_watermark.py <input_image> <output_image>")
    sys.exit(1)

# Image file paths
image_path = sys.argv[1]
output_path = sys.argv[2]

try:
    # Open the image and ensure it's in RGBA mode
    image = Image.open(image_path).convert('RGBA')

    # Create a transparent overlay for the watermark
    watermark = Image.new('RGBA', image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(watermark)

    # Define the watermark text and font
    text = "Processed"
    # Set a larger font size based on the image width (adjust as necessary)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(image.width / 5))

    # Get the bounding box of the text to calculate size
    text_bbox = font.getbbox(text)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]

    # Create a separate image to hold the text and rotate it without clipping
    watermark_text = Image.new('RGBA', (text_width * 2, text_height * 2), (0, 0, 0, 0))
    draw_text = ImageDraw.Draw(watermark_text)

    # Draw the text in red and with some transparency
    draw_text.text((text_width // 2, text_height // 2), text, font=font, fill=(255, 0, 0, 220))

    # Rotate the text 45 degrees for diagonal placement
    rotated_watermark = watermark_text.rotate(45, expand=True)

    # Calculate the position to center the watermark on the image
    x = (image.width - rotated_watermark.width) // 2
    y = (image.height - rotated_watermark.height) // 2

    # Paste the rotated watermark onto the transparent overlay
    watermark.paste(rotated_watermark, (x, y), rotated_watermark)

    # Combine the watermark with the original image
    watermarked_image = Image.alpha_composite(image, watermark)

    # Convert back to RGB mode and save the image
    watermarked_image = watermarked_image.convert('RGB')
    watermarked_image.save(output_path, 'PNG')

    print(f"Added large diagonal watermark to {image_path} -> {output_path}")

except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
