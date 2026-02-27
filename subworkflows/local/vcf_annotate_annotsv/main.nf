include { ANNOTSV_INSTALLANNOTATIONS } from '../../../modules/nf-core/annotsv/installannotations/main'
include { ANNOTSV_ANNOTSV            } from '../../../modules/nf-core/annotsv/annotsv/main'
include { KNOTANNOTSV                } from '../../../modules/local/knotannotsv/main'

workflow VCF_ANNOTATE_ANNOTSV {

    take:
    input                    // tuple val(meta), path(sv_vcf), path(sv_vcf_index), path(candidate_small_variants)
    annotations              // path(annotations)
    candidate_genes          // tuple val(meta3), path(candidate_genes)
    false_positive_snv       // tuple val(meta4), path(false_positive_snv)
    gene_transcripts         // tuple val(meta5), path(gene_transcripts)
    knot_out_xl              // boolean(knot_out_xl)

    main:
    if (!annotations) {
        ANNOTSV_INSTALLANNOTATIONS()
    }

    annotsv_cache = annotations ? tuple([:], annotations) : ANNOTSV_INSTALLANNOTATIONS.out.annotations.map { annot -> [[:], annot] }

    ANNOTSV_ANNOTSV(
        input,
        annotsv_cache,
        candidate_genes,
        false_positive_snv,
        gene_transcripts
    )
    ch_annotsv_tsv = ANNOTSV_ANNOTSV.out.tsv

    KNOTANNOTSV(
        ch_annotsv_tsv,
        knot_out_xl
    )

    emit:
    annotsv_tsv = ch_annotsv_tsv        // channel: [ pair_meta, tsv ]
    knot_html = KNOTANNOTSV.out.html    // channel: [ pair_meta, html ]
    knot_xl = KNOTANNOTSV.out.xl        // channel: [ pair_meta, xlsm ]
}
