#!/usr/bin/env nextflow

// Define input and output directories using S3
params.image_dir = "s3://nextflow-bala/images"         // S3 input directory
params.output_dir = "s3://nextflow-bala/output_images" // S3 output directory

// Extract bucket and prefix from params.image_dir
def s3url = params.image_dir.replace('s3://', '')
def parts = s3url.split('/', 2)
def bucket = parts[0]
def prefix = parts.size() > 1 ? parts[1] : ''
params.bucket = bucket
params.prefix = prefix ? prefix : ''

process loadImages {
    output:
    path 'image_paths.txt', emit: image_paths

    script:
    """
    # List .jpg files in the S3 bucket and store them in image_paths.txt
    aws s3api list-objects \
        --bucket ${params.bucket} \
        --prefix ${params.prefix} \
        --query "Contents[?ends_with(Key, '.jpg')].Key" \
        --output text > image_keys.txt

    # Construct full S3 paths
    awk '{print "s3://${params.bucket}/"\$1}' image_keys.txt > image_paths.txt
    """
}

process resizeImages {
    input:
    val image_path

    output:
    path "resized_*", emit: resized_images

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
    # Download image from S3
    aws s3 cp ${image_path} .

    # Extract the file name from the S3 path
    image_file=\$(basename ${image_path})

    # Resize the image
    output_file="resized_\${image_file}"
    python3 ${projectDir}/scripts/resize_image.py \${image_file} \${output_file}
    """
}

process convertToGrayscale {
    input:
    path resized_image

    output:
    path "gray_*", emit: gray_images

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
    # Extract file name
    image_file=\$(basename ${resized_image})

    # Convert the image to grayscale
    output_file="gray_\${image_file}"
    python3 ${projectDir}/scripts/process_image.py \${resized_image} \${output_file}
    """
}

process addWatermark {
    input:
    path gray_image

    output:
    path "watermarked_*", emit: watermarked_images

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
    # Extract file name
    image_file=\$(basename ${gray_image})

    # Add watermark
    output_file="watermarked_\${image_file}"
    python3 ${projectDir}/scripts/add_watermark.py \${gray_image} \${output_file}
    """
}

process convertToPNG {
    input:
    path watermarked_image

    output:
    path "*.png", emit: png_images

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
    # Extract file name and convert to PNG
    output_file=\$(basename ${watermarked_image} .jpg).png
    python3 ${projectDir}/scripts/convert_to_png.py ${watermarked_image} \${output_file}
    """
}

workflow {
    // Run the loadImages process
    loadImages()

    // Read image paths from the output file and emit each line as an item in the channel
    image_paths_channel = loadImages.out.image_paths.flatMap { file -> file.readLines() }

    // Run the resizeImages process using the image paths channel
    resizeImages(image_paths_channel)

    // Chain subsequent processes using the outputs of previous ones
    convertToGrayscale(resizeImages.out.resized_images)
    addWatermark(convertToGrayscale.out.gray_images)
    convertToPNG(addWatermark.out.watermarked_images)

    // Display the paths of the final PNG images
    convertToPNG.out.png_images.view()
}
