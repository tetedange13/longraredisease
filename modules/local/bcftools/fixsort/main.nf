process BCFTOOLS_FIXSORT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/47/474a5ea8dc03366b04df884d89aeacc4f8e6d1ad92266888e7a8e7958d07cde8/data':
        'community.wave.seqera.io/library/bcftools_htslib:0a3fa2654b52006f' }"

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("*.{vcf,vcf.gz,bcf,bcf.gz}"), emit: vcf
    tuple val(meta), path("*.tbi")                    , emit: tbi, optional: true
    tuple val(meta), path("*.csi")                    , emit: csi, optional: true
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '--output-type z'
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension = args.contains("--output-type b") || args.contains("-Ob") ? "bcf.gz" :
                    args.contains("--output-type u") || args.contains("-Ou") ? "bcf" :
                    args.contains("--output-type z") || args.contains("-Oz") ? "vcf.gz" :
                    args.contains("--output-type v") || args.contains("-Ov") ? "vcf" :
                    "vcf"

    """
    # First tried to REMOVE missing tags, but 'INFO/CONTIG{A,B}' could not be removed ???
    # MEMO: Have to 'force' annotate, otherwise stop cuz not declared in header:
    #bcftools annotate --force -x \$(cat to_remove.txt | tr '\\n' ',' | sed 's/,\$//') -Ob -o fixed.bcf

    # FIXME: If some 'POS<0', bellow crash and error goes to 'to_fix.txt'
    bcftools view $vcf > /dev/null 2> to_fix.txt

    if [ -s to_fix.txt ]; then
        # Build INFO header for missing tags:
        if grep -q  "W::vcf_parse_info" to_fix.txt; then
            grep "W::vcf_parse_info" to_fix.txt |
                grep "is not defined in the header" |
                sed 's/assuming //' |
                tr -d "'" |
                awk '{print "##INFO=<ID="\$3",Number=1,"\$NF",Description=\\"Added because not defined in header\\">"}' > to_add.txt
        fi
        # Build FILTER header for missing tags:
        if grep -q "W::vcf_parse_filter" to_fix.txt; then
            grep "W::vcf_parse_filter" to_fix.txt |
                grep "is not defined in the header" |
                tr -d "'" |
                awk '{print "##FILTER=<ID="\$3",Description=\\"Added because not defined in header\\">"}' >> to_add.txt
        fi

        # Add lines to header with 'bcftools annotate':
        bcftools annotate --header-lines to_add.txt -o fixed.bcf $vcf

        bcftools \\
            sort \\
            --output ${prefix}.${extension} \\
            --temp-dir . \\
            $args \\
            fixed.bcf

        # Have to delete intermediate 'fixed.bcf' (otherwise present in output):
        rm fixed.bcf

    else  # If nothing to fix -> simple 'bcftools sort'
        bcftools \\
            sort \\
            --output ${prefix}.${extension} \\
            --temp-dir . \\
            $args \\
            $vcf
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: '--output-type z'
    def prefix = task.ext.prefix ?: "${meta.id}"

    def extension = args.contains("--output-type b") || args.contains("-Ob") ? "bcf.gz" :
                    args.contains("--output-type u") || args.contains("-Ou") ? "bcf" :
                    args.contains("--output-type z") || args.contains("-Oz") ? "vcf.gz" :
                    args.contains("--output-type v") || args.contains("-Ov") ? "vcf" :
                    "vcf"
    def index = args.contains("--write-index=tbi") || args.contains("-W=tbi") ? "tbi" :
                args.contains("--write-index=csi") || args.contains("-W=csi") ? "csi" :
                args.contains("--write-index") || args.contains("-W") ? "csi" :
                ""
    def create_cmd = extension.endsWith(".gz") ? "echo '' | gzip >" : "touch"
    def create_index = extension.endsWith(".gz") && index.matches("csi|tbi") ? "touch ${prefix}.${extension}.${index}" : ""

    """
    ${create_cmd} ${prefix}.${extension}
    ${create_index}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
