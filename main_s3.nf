#!/usr/bin/env nextflow

// Define input and output directories using S3
params.image_dir = "s3://nextflow-bala/images"  // S3 input directory
params.output_dir = "s3://nextflow-bala/output_images"  // S3 output directory

process loadImages {
    output:
    path 'image_paths.txt', emit: image_paths

    script:
    """
    # List files in the S3 bucket and store them in image_paths.txt
    aws s3 ls ${params.image_dir} --recursive | grep .jpg | grep -v Zone.Identifier | awk '{print "s3://${params.image_dir}/" substr(\$4, index(\$4, "/") + 1)}'  > image_paths.txt
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
    python3 /home/ubuntu/Nextflow/scripts/resize_image.py \${image_file} \${output_file}

    # Upload resized image back to S3
    aws s3 cp \${output_file} ${params.output_dir}/resized_\${image_file}
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
    # Download resized image from S3
    aws s3 cp ${resized_image} .

    # Extract file name
    image_file=\$(basename ${resized_image})

    # Convert the image to grayscale
    output_file="gray_\${image_file}"
    python3 /home/ubuntu/Nextflow/scripts/process_image.py \${image_file} \${output_file}

    # Upload grayscale image back to S3
    aws s3 cp \${output_file} ${params.output_dir}/gray_\${image_file}
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
    # Download grayscale image from S3
    aws s3 cp ${gray_image} .

    # Extract file name
    image_file=\$(basename ${gray_image})

    # Add watermark
    output_file="watermarked_\${image_file}"
    python3 /home/ubuntu/Nextflow/scripts/add_watermark.py \${image_file} \${output_file}

    # Upload watermarked image back to S3
    aws s3 cp \${output_file} ${params.output_dir}/watermarked_\${image_file}
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
    # Download watermarked image from S3
    aws s3 cp ${watermarked_image} .

    # Extract file name and convert to PNG
    output_file=\$(basename ${watermarked_image} .jpg).png
    python3 /home/ubuntu/Nextflow/scripts/convert_to_png.py ${watermarked_image} \${output_file}

    # Upload PNG image back to S3
    aws s3 cp \${output_file} ${params.output_dir}/\${output_file}
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
