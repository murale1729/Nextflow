#!/usr/bin/env nextflow

// Define input and output directories
params.image_dir = "${projectDir}/images"
params.output_dir = "${projectDir}/output_images"

process loadImages {
    output:
    path 'image_paths.txt', emit: image_paths

    script:
    """
    python3 ${projectDir}/scripts/load_images.py ${params.image_dir} > image_paths.txt
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
    output_file=\$(basename ${image_path})
    output_path="resized_\${output_file}"
    python3 ${projectDir}/scripts/resize_image.py ${image_path} \${output_path}
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
    output_file=\$(basename ${resized_image})
    output_path="gray_\${output_file}"
    python3 ${projectDir}/scripts/process_image.py ${resized_image} \${output_path}
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
    output_file=\$(basename ${gray_image})
    output_path="watermarked_\${output_file}"
    python3 ${projectDir}/scripts/add_watermark.py ${gray_image} \${output_path}
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
    output_file=\$(basename ${watermarked_image} .jpg).png
    output_path="\${output_file}"
    python3 ${projectDir}/scripts/convert_to_png.py ${watermarked_image} \${output_path}
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
