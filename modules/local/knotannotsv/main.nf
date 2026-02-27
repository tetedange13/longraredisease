process KNOTANNOTSV {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/77/776546fb3850096f76abd8b63e0eac6b26807e629060e28c81e50ce056f3b8dd/data':
        'community.wave.seqera.io/library/perl-excel-writer-xlsx_perl-sort-key_perl-yaml-libyaml_git:a0a865d27eeceb13' }"

    input:
    tuple val(meta), path(annotsv_tsv)

    output:
    tuple val(meta), path("*.html"), emit: html
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "" // For knotAnnotSV, this a true prefix
    def knotVersion = 'v1.1.5' // CHANGE when UPDATE
    // TODO felix: Allow Excel output
    """
    git clone https://github.com/mobidic/knotAnnotSV.git --branch ${knotVersion} --single-branch

    perl knotAnnotSV/knotAnnotSV.pl \\
        ${args} \\
        --configFile knotAnnotSV/config_AnnotSV.yaml \\
        --outPrefix ${prefix} \\
        --annotSVfile ${annotsv_tsv}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        knotAnnotSV: \$(echo ${knotVersion})
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "" // For knotAnnotSV, this a true prefix
    def knotVersion = 'v1.1.5' // CHANGE when UPDATE
    """
    echo $args
    
    touch ${prefix}_${meta.id}.html
    touch ${prefix}_${meta.id}.xlsx

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        knotAnnotSV: \$(echo ${knotVersion})
    END_VERSIONS
    """
}
