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
        --query "Contents[?contains(Key, '.jpg')].Key" \
        --output text | grep -v Zone.Identifier > image_keys.txt

    # Construct full S3 paths without duplicating the prefix
    awk '{print "s3://${params.bucket}/"\$1}' image_keys.txt > image_paths.txt
    """
}

// ... (Other processes remain similar, ensuring proper escaping and variable interpolation)

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
    """
}

// Continue with other processes...

