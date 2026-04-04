#!/bin/bash
set -euo pipefail

OUTPUT_PREFIX=$1

# Run hifiasm ONT-only assembly
hifiasm -t${PYTHON_CPU_COUNT} --ont -o ${OUTPUT_PREFIX}.asm SRR22085263

# Convert GFA to FASTA
for gfa_file in *.p_ctg.gfa ; do
  fasta_file="${gfa_file%.gfa}.fa"
  awk '/^S/{print ">"$2; print $3}' "${gfa_file}" > "${fasta_file}"
done

# Package outputs
tar czf assembly_output.tar.gz ${OUTPUT_PREFIX}.asm*
