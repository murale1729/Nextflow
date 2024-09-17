#!/usr/bin/env nextflow

// Define input and output directories using S3 for the input and final output
params.image_dir = "s3://nextflow-bala/images"  // S3 input directory
params.output_dir = "s3://nextflow-bala/output_images"  // S3 output directory

// Extract bucket and prefix from params.image_dir
def s3url = params.image_dir
def (bucket, prefix) = s3url.replace('s3://','').tokenize('/', 2)
params.bucket = bucket
params.prefix = prefix ? prefix + '/' : ''

process loadImages {
    output:
    path 'image_paths.txt', emit: image_paths

    script:
    """
    # List .jpg files in the S3 bucket and prefix
    aws s3api list-objects \
        --bucket ${params.bucket} \
        --prefix ${params.prefix} \
        --query 'Contents[?contains(Key, \`.jpg\`)].Key' \
        --output text | grep -v Zone.Identifier > image_keys.txt

    # Construct full S3 paths without duplicating the prefix
    awk '{print "s3://${params.bucket}/" \$1}' image_keys.txt > image_paths.txt
    """
}

// ... (Other processes remain similar, but remove aws s3 cp commands)

process convertToPNG {
    input:
    path watermarked_image

    output:
    path "*.png", emit: png_images

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
    # Convert the watermarked image to PNG
    output_file=\$(basename ${watermarked_image} .jpg).png
    python3 ${projectDir}/scripts/convert_to_png.py ${watermarked_image} \${output_file}
    """
}

workflow {
    // Run the loadImages process to get the image paths from S3
    loadImages()

    // Read image paths from the output file and emit each line as an item in the channel
    image_paths_channel = loadImages.out.image_paths.flatMap { file -> file.readLines() }

    // Resize the images
    resizeImages(image_paths_channel)

    // Continue with the rest of your processes
    convertToGrayscale(resizeImages.out.resized_images)
    addWatermark(convertToGrayscale.out.gray_images)
    convertToPNG(addWatermark.out.watermarked_images)

    // Optionally, view the final PNG paths
    convertToPNG.out.png_images.view()
}
