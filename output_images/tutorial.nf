#!/usr/bin/env nextflow

// Define input and output directories
params.input_dir = "${baseDir}/input_files"
params.output_dir = "${baseDir}/output_files"
params.scripts_dir = "${baseDir}/scripts"

// Define a channel that reads the input files from the directory
input_files_channel = Channel.fromPath("${params.input_dir}/*.txt")

process loadFiles {
    input:
    path file from input_files_channel

    output:
    path file into processed_files_channel

    script:
    """
    python3 ${params.scripts_dir}/load_files.py ${file}
    """
}

process processFiles {
    input:
    path file from processed_files_channel

    output:
    path file into output_files_channel

    script:
    """
    python3 ${params.scripts_dir}/process_files.py ${file} ${params.output_dir}
    """
}

workflow {
    // Run the processes
    loadFiles()
    processFiles()

    // View the output of processed files
    output_files_channel.view()
}
