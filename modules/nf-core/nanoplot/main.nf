process NANOPLOT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "/data/work/CHUUMI/felix/pipelines/singularity_img/nanoplot-rs_v0.2.0.img"

    input:
    tuple val(meta), path(ontfile)

    output:
    tuple val(meta), path("*.html")                , emit: html
    tuple val(meta), path("*.png") , optional: true, emit: png
    tuple val(meta), path("*.tsv")                 , emit: txt
    path  "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_"
    def input_file = ("$ontfile".endsWith(".fastq.gz") || "$ontfile".endsWith(".fq.gz")) ? "--fastq ${ontfile}" :
        ("$ontfile".endsWith(".txt")) ? "--summary ${ontfile}" : ''
    """
    NanoPlot \\
        $args \\
        -t $task.cpus \\
        --prefix $prefix \\
        -i $ontfile

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch LengthvsQualityScatterPlot_dot.html
    touch LengthvsQualityScatterPlot_kde.html
    touch NanoPlot-report.html
    touch NanoStats.txt
    touch Non_weightedHistogramReadlength.html
    touch Non_weightedLogTransformed_HistogramReadlength.html
    touch WeightedHistogramReadlength.html
    touch WeightedLogTransformed_HistogramReadlength.html
    touch Yield_By_Length.html


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}
