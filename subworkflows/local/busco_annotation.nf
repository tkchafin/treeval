#!/usr/bin/env nextflow

// This subworkflow takes an input fasta sequence and csv style list of organisms to return
// bigbed files containing alignment data between the input fasta and csv style organism names.
// Input - Assembled genomic fasta file
// Output - A BigBed file per datatype per organism entered via csv style in the yaml.

nextflow.enable.dsl=2

// MODULE IMPORT
include { BUSCO                          } from '../../modules/nf-core/busco/main'
include { SAMTOOLS_FAIDX                 } from '../../modules/nf-core/samtools/faidx/main'
include { UCSC_BEDTOBIGBED               } from '../../modules/nf-core/ucsc/bedtobigbed/main'
include { BEDTOOLS_SORT                  } from '../../modules/nf-core/bedtools/sort/main'
include { EXTRACT_BUSCOGENE              } from '../../modules/local/extract_buscogene'

include { ANCESTRAL_GENE } from './ancestral_gene'

workflow BUSCO_ANNOTATION {
    take:
    dot_genome           // channel: [val(meta), [ datafile ]]
    reference_tuple      // channel: [val(meta), [ datafile ]]
    assembly_classT      // channel: val(class)
    lineageinfo          // channel: val(lineage_db)
    lineagespath         // channel: val(/path/to/buscoDB)
    buscogene_as         // channel: val(dot_as location)
    ancestral_table      // channel: val(ancestral_table location)

    main:
    ch_versions         = Channel.empty()

    // 
    // MODULE: RUN BUSCO TO OBTAIN FULL_TABLE.CSV
    //         EMITS FULL_TABLE.CSV
    //
    BUSCO ( reference_tuple, 
            lineageinfo,
            lineagespath,
            [] )
    ch_versions = ch_versions.mix(BUSCO.out.versions.first())

    ch_grab  = GrabFiles(BUSCO.out.busco_dir)

    EXTRACT_BUSCOGENE (ch_grab)
    ch_versions = ch_versions.mix(EXTRACT_BUSCOGENE.out.versions)

    BEDTOOLS_SORT(EXTRACT_BUSCOGENE.out.genefile, [])
    ch_versions             = ch_versions.mix(BEDTOOLS_SORT.out.versions)

    UCSC_BEDTOBIGBED(BEDTOOLS_SORT.out.sorted, dot_genome.map{it[1]}, buscogene_as)
    ch_versions             = ch_versions.mix(UCSC_BEDTOBIGBED.out.versions)

    //
    // LOGIC: Aggregate data and sort by class.
    //         
    assembly_classT
        .combine( BUSCO.out.busco_dir )
        .combine( ancestral_table )
        .branch {
            lep:     it[0] == "lepidoptera"
            general: it[0] != "lepidoptera"
        }
        .set{ch_busco_data}

    //
    // LOGIC: Build Lepidoptera Input
    //     
    ch_busco_data.lep
            .multiMap { data ->
                busco_dir:    tuple(data[1], data[2])
                atable:       data[3]
            }
            .set{ch_busco_lep_data}

    //
    // SUBWORKFLOW: Run leptidoptera ancestral gene 
    //     
    ANCESTRAL_GENE (ch_busco_lep_data.busco_dir,
                    dot_genome,
                    buscogene_as,
                    ch_busco_lep_data.atable)
    ch_versions = ch_versions.mix(ANCESTRAL_GENE.out.versions)

    emit:
    ch_buscogene_bigbed        = UCSC_BEDTOBIGBED.out.bigbed
    ch_ancestral_bigbed        = ANCESTRAL_GENE.out.ch_ancestral_bigbed
    versions = ch_versions

}
process GrabFiles {

    tag "${meta.id}"
    executor 'local'

    input:
    tuple val(meta), path("in")

    output:
    tuple val(meta), path("in/*/*/full_table.tsv")

    "true"
}