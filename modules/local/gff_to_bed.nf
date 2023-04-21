process GFF_TO_BED {
    tag "${meta.id}"
    label "process_low"

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
    'ubuntu:20.04' }"

    input:
    tuple val( meta ), path( file )

    output:
    tuple val( meta ), file( "*.bed" )  , emit: punchlist
    path "versions.yml"                 , emit: versions

    script:
    def VERSION = "9.1" // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    gff_to_bed.sh ${file} ${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gff_to_bed: \$(gff_to_bed.sh -v)
        coreutils: $VERSIONS
    END_VERSIONS
    """

    stub:
    def VERSION = "9.1"
    """
    touch ${meta.id}.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gff_to_bed: \$(gff_to_bed.sh -v)
        coreutils: $VERSIONS
    END_VERSIONS
    """
}
