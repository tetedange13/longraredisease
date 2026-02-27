include { ANNOTSV_ANNOTSV } from '../../../modules/nf-core/annotsv/annotsv/main.nf'
include { KNOTANNOTSV     } from '../../../modules/local/knotannotsv/main.nf'

workflow VCF_ANNOTATE_ANNOTSV {

    take:
    input                    // tuple val(meta), path(sv_vcf), path(sv_vcf_index), path(candidate_small_variants)
    annotations              // path(annotations)
    candidate_genes          // tuple val(meta3), path(candidate_genes)
    false_positive_snv       // tuple val(meta4), path(false_positive_snv)
    gene_transcripts         // tuple val(meta5), path(gene_transcripts)

    main:
    ANNOTSV_ANNOTSV(
        input,
        tuple([:], annotations),
        candidate_genes,
        false_positive_snv,
        gene_transcripts
    )
    ch_annotsv_tsv = ANNOTSV_ANNOTSV.out.tsv

    KNOTANNOTSV(ch_annotsv_tsv)

    emit:
    annotsv_tsv = ch_annotsv_tsv        // channel: [ pair_meta, tsv ]
    knot_html = KNOTANNOTSV.out.html    // channel: [ pair_meta, html ]
}
