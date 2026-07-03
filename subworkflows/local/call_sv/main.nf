// Run sniffles SV calling
include { SNIFFLES                                   } from '../../../modules/nf-core/sniffles/main.nf'
include { GUNZIP as GUNZIP_SNIFFLES_PLOT             } from '../../../modules/nf-core/gunzip/main.nf'
include { SNIFFLES_GENERATE_PLOTS                    } from '../../../modules/local/sniffles/generate_plots/main.nf'
// Run svim SV calling
include { SVIM_ALIGNMENT                      } from '../../../modules/nf-core/svim/alignment/main.nf'
include { BCFTOOLS_SORT as BCFTOOLS_SORT_SVIM } from '../../../modules/nf-core/bcftools/sort/main.nf'
include { BCFTOOLS_FILTER as BCFTOOLS_FILTER_SVIM } from '../../../modules/nf-core/bcftools/filter/main.nf'
// Run cutesv SV calling
include { CUTESV                                } from '../../../modules/nf-core/cutesv/main.nf'
include { RE2SUPPORT                            } from '../../../modules/local/fix_header_sv/cutesv/main.nf'
include { BCFTOOLS_SORT as BCFTOOLS_SORT_CUTESV } from '../../../modules/nf-core/bcftools/sort/main.nf'
include { TABIX_TABIX as TABIX_CUTESV           } from '../../../modules/nf-core/tabix/tabix/main.nf'
// Run dysgu SV calling
include { DYSGU_RUN                             } from '../../../modules/nf-core/dysgu/run/main.nf'
// Run severus SV calling
include { SEVERUS                               } from '../../../modules/nf-core/severus/main.nf'
include { TABIX_BGZIPTABIX as TABIX_SEVERUS     } from '../../../modules/nf-core/tabix/bgziptabix/main.nf'
// Run delly SV calling
include { DELLY_CALL                            } from '../../../modules/nf-core/delly/call/main.nf'
// Run kled SV calling
include { KLED                                  } from '../../../modules/nf-core/kled/main.nf'
include { TABIX_BGZIPTABIX as TABIX_KLED        } from '../../../modules/nf-core/tabix/bgziptabix/main.nf'

workflow CALL_SV {

    take:
    input                    // tuple(val(meta), path(bam), path(bai))
    fasta                    // tuple(val(meta), path(fasta))
    tandem_file              // tuple(val(meta), path(bed))
    vcf_output               // val(true)
    snf_output               // val(true)
    merge_sv                 // val(boolean) - whether to prepare for merging (i.e. run all callers regardless of run_svim/run_cutesv)
    run_svim

    main:
    ch_versions = channel.empty()

    // Initialize empty channels for conditional callers
    ch_svim_vcf = channel.empty()
    ch_svim_tbi = channel.empty()
    ch_cutesv_vcf = channel.empty()
    ch_cutesv_tbi = channel.empty()

    // ========================================
    // SNIFFLES - ALWAYS RUNS
    // ========================================
    SNIFFLES(input, fasta, tandem_file, vcf_output, snf_output)
    ch_versions = ch_versions.mix(SNIFFLES.out.versions)

    // ========================================
    // SNIFFLES PLOTS
    // ========================================
    GUNZIP_SNIFFLES_PLOT(SNIFFLES.out.vcf)
    SNIFFLES_GENERATE_PLOTS(GUNZIP_SNIFFLES_PLOT.out.gunzip)
    ch_sniffles_plots = SNIFFLES_GENERATE_PLOTS.out.plot_dir

    // ========================================
    // DYSGU
    // ========================================

    DYSGU_RUN(
        input,
        fasta,
        [[id: 'fai'], []],
        [[id: 'sites'], []],
        [[id: 'bed'], []],
        [[id: 'search_bed'], []],
        [[id: 'exclude_bed'], []]
    )

    // ========================================
    // SEVERUS
    // ========================================

    input
        .map { meta, bam, bai -> [meta, bam, bai, [], [], []]}
        .set { severus_in }
    SEVERUS(
        severus_in,
        tandem_file,
    )
    TABIX_SEVERUS(SEVERUS.out.all_vcf)

    // ========================================
    // DELLY
    // ========================================

    input
        .map { meta, bam, bai -> [meta, bam, bai, [], [], []] }
        .set { delly_in }
    DELLY_CALL(
        delly_in,
        fasta,
        [[id: 'fai'], []],
        'vcf'
    )

    // ========================================
    // KLED
    // ========================================

    KLED(
        input,
        fasta
    )
    TABIX_KLED(KLED.out.vcf)

    if (merge_sv || run_svim) {

    // ========================================
    // SVIM - CONDITIONAL
    // ========================================

        SVIM_ALIGNMENT(input, fasta)
        // 'SUPPORT>=2' defined in conf
        BCFTOOLS_FILTER_SVIM (SVIM_ALIGNMENT.out.vcf.map{ meta, vcf -> [ meta, vcf, [] ]})
        BCFTOOLS_SORT_SVIM(BCFTOOLS_FILTER_SVIM.out.vcf)

        ch_svim_vcf = BCFTOOLS_SORT_SVIM.out.vcf
        ch_svim_tbi = BCFTOOLS_SORT_SVIM.out.tbi
        }


    // ========================================
    // CUTESV
    // ========================================
        if (merge_sv) {
            CUTESV(input, fasta)
            RE2SUPPORT(CUTESV.out.vcf)
            BCFTOOLS_SORT_CUTESV(RE2SUPPORT.out.vcf)
            TABIX_CUTESV(BCFTOOLS_SORT_CUTESV.out.vcf)
            ch_cutesv_vcf = BCFTOOLS_SORT_CUTESV.out.vcf
            ch_cutesv_tbi = TABIX_CUTESV.out.tbi
            ch_versions = ch_versions.mix(CUTESV.out.versions)

            }

    // ========================================
    // COMBINE VCF AND TBI CHANNELS
    // ========================================

    ch_sniffles_vcf_tbi = SNIFFLES.out.vcf.join(SNIFFLES.out.tbi, by: 0)

    ch_svim_vcf_tbi = ch_svim_vcf.join(ch_svim_tbi, by: 0, remainder: true)
        .filter { meta, vcf, tbi -> vcf != null }

    ch_cutesv_vcf_tbi = ch_cutesv_vcf.join(ch_cutesv_tbi, by: 0, remainder: true)
        .filter { meta, vcf, tbi -> vcf != null }


    emit:
    sniffles_vcf_tbi = ch_sniffles_vcf_tbi   // channel: [ meta, vcf.gz, vcf.gz.tbi ]
    sniffles_snf     = SNIFFLES.out.snf      // channel: [ meta, snf ]
    sniffles_vcf     = SNIFFLES.out.vcf      // channel: [ meta, vcf.gz ]
    sniffles_unzipped_vcf = GUNZIP_SNIFFLES_PLOT.out.gunzip
    svim_vcf_tbi     = ch_svim_vcf_tbi       // channel: [ meta, vcf.gz, vcf.gz.tbi ]
    svim_vcf         = ch_svim_vcf           // channel: [ meta, vcf.gz ]
    dysgu_vcf        = DYSGU_RUN.out.vcf     // channel: [ meta, vcf.gz ]
    severus_vcf      = TABIX_SEVERUS.out.gz_tbi.map { meta, gz, tbi -> [meta, gz] }   // channel: [ meta, vcf.gz ]
    delly_vcf        = DELLY_CALL.out.bcf    // channel: [ meta, vcf.gz ]
    kled_vcf         = TABIX_KLED.out.gz_tbi.map { meta, gz, tbi -> [meta, gz] }   // channel: [ meta, vcf.gz ]
    cutesv_vcf_tbi   = ch_cutesv_vcf_tbi     // channel: [ meta, vcf.gz, vcf.gz.tbi ]
    cutesv_vcf       = ch_cutesv_vcf         // channel: [ meta, vcf.gz ]
    sniffles_plots   = ch_sniffles_plots     // channel: [ meta, plot_dir ]
    versions         = ch_versions           // channel: [ versions ]
}
