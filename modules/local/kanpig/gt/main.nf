process KANPIG_GT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kanpig:2.0.2--ha6fb395_0' :
        'quay.io/biocontainers/kanpig:2.0.2--ha6fb395_0' }"

    input:
    tuple val(meta), path(vcf, stageAs: 'input/'), path(vcf_index, stageAs: 'input/'), path(bam), path(bai), path(restrict_bed), path(ploidy_bed)
    tuple val(meta2), path(fasta), path(fasta_index)

    output:
    tuple val(meta), path("*.vcf"), emit: vcf
    tuple val("${task.process}"), val("kanpig"), eval("kanpig --version 2>&1 | sed 's/kanpig //'"), topic: versions, emit: versions_kanpig

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def restrict = restrict_bed ? "--bed ${restrict_bed}" : ""
    def ploidy = ploidy_bed ? "--ploidy-bed ${ploidy_bed}" : ""
    """
    kanpig \\
        gt \\
        --input ${vcf} \\
        --reads ${bam} \\
        --reference ${fasta} \\
        ${args} \\
        ${restrict} \\
        ${ploidy} \\
        --threads ${task.cpus} \\
        --out ${prefix}.vcf
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.vcf
    """
}
