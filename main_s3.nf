#!/usr/bin/env nextflow

// Define input and output directories using S3 for the input and final output
params.image_dir = "s3://nextflow-bala/images"  // S3 input directory
params.output_dir = "s3://nextflow-bala/output_images"  // S3 output directory

process loadImages {
    output:
    path 'image_paths.txt', emit: image_paths

    script:
    """
    # Correctly build the path without duplicating the 'images/' folder
    aws s3 ls ${params.image_dir} --recursive | grep .jpg | grep -v Zone.Identifier | awk '{print "s3://${params.image_dir}" substr(\$4, length("${params.image_dir}") - length("/images"))}' > image_paths.txt
    """
}

process resizeImages {
    input:
    val image_path

    output:
    path "resized_*", emit: resized_images

    script:
    """
    # Download the image from S3
    aws s3 cp ${image_path} .

    # Extract the file name from the S3 path
    image_file=\$(basename ${image_path})

    # Resize the image
    output_file="resized_\${image_file}"
    python3 ${projectDir}/scripts/resize_image.py \${image_file} \${output_file}

    # Upload resized image back to S3
    aws s3 cp \${output_file} ${params.output_dir}/resized_\${image_file}
    """
}

process convertToGrayscale {
    input:
    path resized_image

    output:
    path "gray_*", emit: gray_images

    script:
    """
    # Convert the resized image to grayscale
    output_file=\$(basename ${resized_image})
    gray_output="gray_\${output_file}"
    python3 ${projectDir}/scripts/process_image.py \${resized_image} \${gray_output}
    """
}

process addWatermark {
    input:
    path gray_image

    output:
    path "watermarked_*", emit: watermarked_images

    script:
    """
    # Add a watermark to the grayscale image
    output_file=\$(basename ${gray_image})
    watermarked_output="watermarked_\${output_file}"
    python3 ${projectDir}/scripts/add_watermark.py \${gray_image} \${watermarked_output}
    """
}

process convertToPNG {
    input:
    path watermarked_image

    output:
    path "*.png", emit: png_images

    script:
    """
    # Convert the watermarked image to PNG
    output_file=\$(basename ${watermarked_image} .jpg).png
    python3 ${projectDir}/scripts/convert_to_png.py ${watermarked_image} \${output_file}
    """
}

process uploadToS3 {
    input:
    path png_image

    script:
    """
    # Upload the final PNG image to the S3 bucket
    aws s3 cp ${png_image} ${params.output_dir}/\$(basename ${png_image})
    """
}

workflow {
    // Run the loadImages process to get the image paths from S3
    loadImages()

    // Read image paths from the output file and emit each line as an item in the channel
    image_paths_channel = loadImages.out.image_paths.flatMap { file -> file.readLines() }

    // Resize the images
    resizeImages(image_paths_channel)

    // Convert resized images to grayscale
    convertToGrayscale(resizeImages.out.resized_images)

    // Add a watermark to the grayscale images
    addWatermark(convertToGrayscale.out.gray_images)

    // Convert watermarked images to PNG format
    convertTo
