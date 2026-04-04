# Assembling a Whole Genome with hifiasm on CHTC

## Introduction

A genome assembly workflow for Oxford Nanopore long reads using hifiasm on CHTC's high-throughput computing infrastructure.

[hifiasm](https://github.com/chhylp123/hifiasm) is a fast, haplotype-resolved de novo assembler originally designed for PacBio HiFi reads. Starting with version 0.19, hifiasm also supports **ONT-only assembly**, making it a versatile choice for long-read genome projects. In ONT-only mode, hifiasm takes raw Oxford Nanopore reads and produces haplotype-resolved assemblies with high contiguity.

This tutorial walks you through assembling the genome of the **Palla's Cat** (*Otocolobus manul*), a small wild cat native to the grasslands and montane steppes of Central Asia. The sequencing data comes from a specimen named **Tater**, sequenced using Oxford Nanopore's **Ligation Sequencing Kit**. The expected genome size is approximately **2.4 Gb**, comparable to the domestic cat (*Felis catus*).

This tutorial teaches you how to run a genome assembly on CHTC using hifiasm and scalable, high-throughput compute practices. You will learn how to:

* **Understand the genome assembly workflow on CHTC**, including how hifiasm maps to CPU and memory resources.
* **Prepare and stage large ONT sequencing datasets** for use with HTCondor jobs, using OSDF for efficient data transfer.
* **Leverage CHTC's high-memory capacity for genome assembly**, including selecting appropriate resource requests for large mammalian genomes.
* **Use containers and HTCondor data-transfer mechanisms** to build reproducible, portable assembly workflows.
* **Submit and monitor genome assembly jobs** using standard HTCondor patterns and best practices.

All steps run using the HTCondor workload manager and Apptainer containers. The tutorial uses real genomics data and emphasizes performance, reproducibility, and portability.

**Start here**
* [Introduction](#introduction)
* [Tutorial Setup](#tutorial-setup)
* [Understanding the Genome Assembly Workflow](#understanding-the-genome-assembly-workflow)
* [Running Genome Assembly on CHTC](#running-genome-assembly-on-chtc)
  + [Set Up Your Software Environment](#set-up-your-software-environment)
  + [Preparing Your ONT Reads](#preparing-your-ont-reads)
  + [Submit Your Assembly Job](#submit-your-assembly-job)
  + [Understanding hifiasm Output](#understanding-hifiasm-output)
* [Next Steps](#next-steps)
* [Reference Material](#reference-material)
  + [Overview: Assembly Executable (assembly.sh)](#overview-assembly-executable-assemblysh)
  + [Glossary](#glossary)
  + [Software](#software)
  + [Data](#data)
  + [Compute Resources](#compute-resources)
* [Getting Help](#getting-help)


<!-- TOC end -->


## Tutorial Setup

### Before You Begin

You will need the following before moving forward with the tutorial:

1. [X] A CHTC HTC account. If you do not have one, request access at the [CHTC Account Request Page](https://chtc.cs.wisc.edu/uw-research-computing/form.html).
1. [X] A CHTC "staging" folder.
2. [X] Basic familiarity with HTCondor job submission. If you are new to HTCondor, complete the CHTC ["Roadmap to getting started"](https://chtc.cs.wisc.edu/uw-research-computing/htc-roadmap/) and read the ["Practice: Submit HTC Jobs using HTCondor"](https://chtc.cs.wisc.edu/uw-research-computing/htcondor-job-submission).

This tutorial also assumes that you:

* Have basic command-line experience (e.g., navigating directories, using bash, editing text files)
* Have sufficient disk quota and file permissions in your CHTC `/home` and `/staging` directories

> [!NOTE]
> If you are new to running jobs on CHTC, complete the CHTC ["Roadmap to getting started"](https://chtc.cs.wisc.edu/uw-research-computing/htc-roadmap/) and our ["Practice: Submit HTC Jobs using HTCondor"](https://chtc.cs.wisc.edu/uw-research-computing/htcondor-job-submission) guide before starting this tutorial.

### Time Estimation

Estimated time: plan ~1-2 hours for the tutorial walkthrough. The assembly step itself typically takes 4-72 hours depending on read coverage, genome complexity, and available compute resources.

### Clone the Tutorial Repository

1. Log into your CHTC account:

    ```bash
    ssh user.name@ap####.chtc.wisc.edu
    ```

2. Clone the repository:

    ```bash
    git clone https://github.com/CHTC/tutorial-CHTC-Genome-Assembly.git
    cd tutorial-CHTC-Genome-Assembly/
    ```

3. Create a logs directory for HTCondor log files:

    ```bash
    mkdir -p logs/
    ```

#### About the Dataset

This tutorial uses Oxford Nanopore Ligation Sequencing reads from the Palla's Cat (*Otocolobus manul*). The sample was taken from **Tater**, a Palla's Cat living in Utica Zoo in New York, and sequences by the University of Minnesota's Faulk Lab. Learn more about how Tater made history as the first Palla's Cat to have their genome sequence [here](https://twin-cities.umn.edu/news-events/u-m-researchers-map-genome-worlds-grumpiest-cat). The reads have been pre-staged on the Open Science Data Federation (OSDF) for use with this tutorial:

```
osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263
```

The ONT reads are transferred directly to the execute node by HTCondor as part of the job submission process. You do not need to download the reads manually.

**SRA Accession**: [`SRR22085263`](https://www.ncbi.nlm.nih.gov/sra/SRR22085263)

If you would like to download the reads locally for inspection or other purposes, you can use the Pelican client:

```bash
pelican object get osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263 ./
```

You can also download directly from the SRA public bucket:

```bash
pelican object get osdf:///aws-opendata/us-east-1/sra-pub-run-odp/sra/SRR22085263/SRR22085263 ./
```

For more details about the dataset, see `Toy_Dataset/README.md`.

| Property | Value |
|----------|-------|
| Species | *Otocolobus manul* (Palla's Cat) |
| Specimen | Tater |
| Sequencing Platform | Oxford Nanopore Technologies |
| Library Prep | Ligation Sequencing Kit |
| Expected Genome Size | ~2.4 Gb |


## Understanding the Genome Assembly Workflow

Genome assembly is the process of reconstructing a genome from sequencing reads. Oxford Nanopore long reads (typically 10-100+ kb) provide the contiguity needed to span repetitive regions and produce chromosome-scale assemblies.

**hifiasm** performs de novo assembly by:

1. **Reading raw ONT reads** and correcting errors using all-vs-all read overlaps
2. **Building an assembly graph** that captures the relationships between reads
3. **Resolving haplotypes** to produce separate assemblies for each parental copy of the genome
4. **Outputting assembly graphs** in GFA format, which can be converted to FASTA for downstream analysis

### What the Assembly Pipeline Does

- **Inputs**: Raw ONT reads in FASTQ/FASTQ.GZ format
- **Actions**: Error correction, overlap computation, graph construction, haplotype resolution
- **Outputs**: Assembly graphs (GFA) and contigs (FASTA) for primary assembly and individual haplotypes

### Key Characteristics of the Assembly Step

- **CPU-bound and memory-intensive**: hifiasm uses multiple threads and requires significant memory for a mammalian-sized genome. For the Palla's Cat (~2.4 Gb), expect to need 64-128 GB of RAM and 16-32 CPU cores.
- **No GPU required**: The entire assembly pipeline runs on CPU only.
- **Data-intensive**: ONT read files for a mammalian genome can be 50-200+ GB. The reads are transferred from OSDF to the execute node by HTCondor.
- **Runtime**: Assembly of a mammalian genome typically takes 4-12 hours depending on read coverage, genome complexity, and available compute resources.


## Running Genome Assembly on CHTC

### Set Up Your Software Environment

CHTC provides a shared Apptainer container for hifiasm. The submit file in this tutorial references a pre-built container image distributed via OSDF:

```
container_image = osdf:///osg-public/containers/hifiasm.sif
```

This container includes hifiasm (v0.19+) with ONT-only assembly support. HTCondor automatically transfers the container to the execute node, so no manual setup is required.

<details>
<summary>Click to expand: Building Your Own hifiasm Apptainer Container (Advanced)</summary>

If you need a specific version of hifiasm or want to customize the container, you can build your own:

1. On your CHTC AP `/home/` directory, create an apptainer definition file titled `hifiasm.def`:

    ```apptainer
    Bootstrap: docker
    From: condaforge/miniforge3:latest

    %post
        mamba install hifiasm
    ```

2. Create a `build.sub` submit file in your directory:

    ```bash
    # apptainer.sub

    # Include other files that need to be transferred here.
    transfer_input_files = hifiasm.def

    +IsBuildJob = True
    
    # Make sure you request enough disk for the container image to build
    request_cpus = 8
    request_memory = 16GB
    request_disk = 30GB      

    queue
    ```

3. Submit your job as an interactive job

    ```bash
    condor_submit build.sub -i
    ```

4. On your CHTC Execution Point, build an Apptainer image:

    ```bash
    apptainer build hifiasm_08APR2026_v1.sif hifiasm.def
    ```
    
5. Move your Apptainer image `hifiasm_08APR2026_v1.sif` to your `/staging/` directory

    ```bash
    mv hifiasm_08APR2026_v1.sif /staging/<netid>/
    ```
</details>

### Preparing Your ONT Reads

The ONT reads for Tater are pre-staged on OSDF and will be automatically transferred to the execute node by HTCondor. The submit file configures this with:

```
transfer_input_files = osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263
```

> [!IMPORTANT]
> When running your own assemblies, replace this OSDF path with the path to your own reads. If your reads are stored in your CHTC `/staging/` directory, you can reference them as:
> ```
> transfer_input_files = osdf:///chtc/staging/<netid>/my_reads.fastq.gz
> ```

> [!TIP]
> If you have multiple FASTQ files from the same sequencing run, concatenate them before staging:
> ```bash
> cat run1.fastq.gz run2.fastq.gz run3.fastq.gz > all_reads.fastq.gz
> ```

### Submit Your Assembly Job

1. Change to your `tutorial-CHTC-Genome-Assembly/` directory:

    ```bash
    cd ~/tutorial-CHTC-Genome-Assembly/
    ```

2. Review the assembly executable script `scripts/assembly.sh`. The script is a simple wrapper that runs hifiasm, converts the output GFA to FASTA, and tarballs the results. For this tutorial, no changes are necessary.

3. Review the submit file `assembly.sub`:

    ```
    # Container for hifiasm genome assembler
    container_image = osdf:///osg-public/containers/hifiasm.sif

    executable = scripts/assembly.sh

    log = ./logs/assembly.log
    output = assembly_$(Cluster)_$(Process).out
    error  = assembly_$(Cluster)_$(Process).err

    # ONT reads pre-staged on OSDF
    transfer_input_files = osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263

    # Transfer assembly output back to the submit node
    transfer_output_files = assembly_output.tar.gz
    transfer_output_remaps = "assembly_output.tar.gz=Assembly_Output/assembly_output.tar.gz"

    should_transfer_files = YES
    when_to_transfer_output = ON_EXIT

    Requirements = (Target.HasCHTCStaging == true)

    # hifiasm for a ~2.4 Gb mammalian genome needs substantial resources
    request_memory = 128GB
    request_disk = 500GB
    request_cpus = 32

    arguments = Omalun-Tater

    queue 1
    ```

    This submit file:
    - Uses a pre-built hifiasm container from OSDF
    - Transfers the ONT reads from OSDF to the execute node
    - Requests 128 GB of memory, 32 CPU cores, and 500 GB of disk space
    - Returns the assembly output as a tarball to `Assembly_Output/`
    - Targets CHTC machines with staging access

4. Submit the assembly job:

    ```bash
    condor_submit assembly.sub
    ```

5. Track your job progress:

    ```bash
    condor_watch_q
    ```

> [!TIP]
> For testing, you can create a subset of reads and adjust the resource requirements. Create a subset with:
> ```bash
> zcat SRR22085263 | head -n 400000 | gzip > SRR22085263_subset.fastq.gz
> ```
> Then modify `assembly.sub` to use the subset file and reduce `request_memory` to `16GB` and `request_cpus` to `8`.

> [!TIP]
> If your assembly jobs are running out of memory, increase the `request_memory` attribute. Highly repetitive genomes or very high-coverage datasets may require 200+ GB of RAM. You can also use `retry_request_memory` for automatic retries with more memory. See the CHTC [Request variable memory](https://chtc.cs.wisc.edu/uw-research-computing/variable-memory#use-retry_request_memory) documentation.

#### Choosing Appropriate Resources

Resource requirements for hifiasm depend primarily on **genome size** and **read coverage**:

| Genome Size | Coverage | Recommended Memory | Recommended CPUs | Estimated Runtime |
|-------------|----------|--------------------|------------------|-------------------|
| < 500 Mb | 30-50x | 16-32 GB | 8-16 | 1-3 hours |
| 500 Mb - 1 Gb | 30-50x | 32-64 GB | 16-32 | 2-6 hours |
| 1 - 3 Gb | 30-50x | 64-128 GB | 32 | 4-12 hours |
| > 3 Gb | 30-50x | 128-256 GB | 32+ | 8-24+ hours |

The Palla's Cat genome (~2.4 Gb) falls in the 1-3 Gb range, so this tutorial requests 128 GB of memory and 32 CPUs.

> [!NOTE]
> These are guidelines. Actual requirements depend on genome complexity, repeat content, and coverage depth. Highly repetitive genomes may need significantly more memory.

### Understanding hifiasm Output

Once the assembly job completes, extract the output:

```bash
cd Assembly_Output/
tar xzf assembly_output.tar.gz
ls -lh
```

hifiasm produces several output files:

| File | Description |
|------|-------------|
| `Omalun-Tater.asm.bp.hap1.p_ctg.gfa` | Haplotype 1 primary contigs (assembly graph) |
| `Omalun-Tater.asm.bp.hap2.p_ctg.gfa` | Haplotype 2 primary contigs (assembly graph) |
| `Omalun-Tater.asm.bp.p_ctg.gfa` | Combined primary contigs (assembly graph) |
| `Omalun-Tater.asm.bp.hap1.p_ctg.fa` | Haplotype 1 primary contigs (FASTA, converted by script) |
| `Omalun-Tater.asm.bp.hap2.p_ctg.fa` | Haplotype 2 primary contigs (FASTA, converted by script) |
| `Omalun-Tater.asm.bp.p_ctg.fa` | Combined primary contigs (FASTA, converted by script) |
| `Omalun-Tater.asm.ec.bin` | Error-corrected reads (binary) |
| `Omalun-Tater.asm.ovlp.*.bin` | Overlap information (binary) |

The **GFA** (Graphical Fragment Assembly) files contain the assembly graph, which captures the full structure of the assembly including potential alternative paths. The **FASTA** files are derived from the GFA files by extracting contig sequences. The `assembly.sh` script automatically converts GFA to FASTA.

#### Haplotype-Resolved Assembly

hifiasm produces **haplotype-resolved** assemblies, meaning it separates the two parental copies of the genome into distinct assembly outputs (`hap1` and `hap2`). This is particularly valuable for:

- Studying structural variation between haplotypes
- Phasing heterozygous variants
- Generating more complete genome representations

The combined primary contigs (`Omalun-Tater.asm.bp.p_ctg.gfa`) represent a merged view and are suitable for most downstream applications.

#### Quick Assembly Statistics

To get a quick summary of the assembly, you can count contigs and compute basic statistics:

```bash
# Count the number of contigs
grep -c "^>" Omalun-Tater.asm.bp.p_ctg.fa

# View the first few contig headers
head -n 20 Omalun-Tater.asm.bp.p_ctg.fa | grep "^>"
```

For detailed quality metrics (N50, L50, total length), consider running an assembly assessment tool like QUAST in a follow-up job. See [Next Steps](#next-steps) for details.

#### Visualize the Assembly Graph

You can visualize hifiasm's GFA assembly graphs using [Bandage](https://rrwick.github.io/Bandage/), a tool for interactive visualization of assembly graphs. Download the GFA files to your local machine and open them in Bandage:

```bash
# From your local machine
scp <netID>@ap####.chtc.wisc.edu:~/tutorial-CHTC-Genome-Assembly/Assembly_Output/Omalun-Tater.asm.bp.p_ctg.gfa ./
```


## Next Steps

Now that you've successfully assembled the Palla's Cat genome on CHTC, here are recommended next steps:

**Assess Assembly Quality**
* Run QUAST to compute contiguity metrics (N50, total length, number of contigs)
* Run BUSCO against the `mammalia_odb10` lineage database to assess gene completeness
* Compare your assembly metrics against published Felidae genomes

**Scaffold and Polish**
* Use Hi-C data (if available) to scaffold contigs into chromosome-level assemblies with tools like YaHS or SALSA2
* Polish the assembly with additional sequencing data to reduce residual errors

**Annotate the Genome**
* Run repeat masking (RepeatMasker/RepeatModeler)
* Perform gene prediction and annotation (BRAKER, Augustus, or similar)
* Annotate functional elements

**Scale to Multiple Samples**
* Adapt the workflow for multiple specimens using HTCondor's `queue ... from` syntax
* Create a manifest file listing sample names and read paths, similar to the AF3 tutorial's approach
* Use DAGMan to chain assembly steps (QC, assembly, assessment) into automated pipelines

**Get Help or Collaborate**
* Reach out to [chtc@cs.wisc.edu](mailto:chtc@cs.wisc.edu) for one-on-one help with scaling your research.
* Attend office hours or training sessions -- see the [CHTC Help Page](https://chtc.cs.wisc.edu/uw-research-computing/get-help.html) for details.


## Reference Material

### Overview: Assembly Executable (assembly.sh)

This script, `assembly.sh`, is a simple wrapper that runs hifiasm in ONT-only mode, converts the output GFA assembly graphs to FASTA, and packages the results into a tarball. It is designed for execution inside an HTCondor container job on CHTC.

The script does three things:

1. **Runs hifiasm** in ONT-only mode:

    ```bash
    hifiasm -t${PYTHON_CPU_COUNT} --ont -o ${OUTPUT_PREFIX}.asm SRR22085263
    ```

    The output prefix is passed as the first argument from the submit file (e.g., `Omalun-Tater`). `PYTHON_CPU_COUNT` is automatically set by HTCondor to match `request_cpus` in the submit file.

2. **Converts GFA to FASTA** for each primary contig assembly graph:

    ```bash
    awk '/^S/{print ">"$2; print $3}' *.p_ctg.gfa > *.p_ctg.fa
    ```

3. **Packages all outputs** into a tarball for transfer back to the submit host:

    ```bash
    tar czf assembly_output.tar.gz ${OUTPUT_PREFIX}.asm*
    ```

### Glossary

| Term | Definition |
|------|------------|
| ONT (Oxford Nanopore Technologies) | Long-read sequencing platform producing reads typically 10-100+ kb in length. |
| Ligation Sequencing | ONT library preparation method that ligates motor proteins to DNA fragments for sequencing. |
| hifiasm | Fast haplotype-resolved de novo assembler supporting PacBio HiFi and Oxford Nanopore reads. |
| Contig | A contiguous assembled sequence derived from overlapping reads. |
| N50 | Minimum contig length such that 50% of the total assembly is in contigs of this length or longer. A common assembly quality metric. |
| GFA (Graphical Fragment Assembly) | Standard format for representing assembly graphs, including contigs and their relationships. |
| FASTA | Standard text format for nucleotide or protein sequences. |
| FASTQ | Sequence format that includes per-base quality scores alongside the sequence. |
| Haplotype | One of two copies of each chromosome in a diploid organism. hifiasm can resolve both haplotypes separately. |
| Coverage / Depth | Average number of sequencing reads covering each position in the genome. Typically 30-50x for de novo assembly. |
| QUAST | Quality Assessment Tool for genome assemblies -- computes metrics like N50, total length, and number of contigs. |
| BUSCO | Benchmarking Universal Single-Copy Orthologs -- assesses genome completeness using conserved gene sets. |
| NanoPlot | Plotting and statistics tool for quality assessment of long-read sequencing data. |
| HTCondor submit file (`.sub`) | Job description file used by HTCondor to submit tasks to the HTC system. |
| Apptainer | Container runtime (formerly Singularity) commonly used on HPC/HTC systems to run reproducible environments. |
| OSDF (Open Science Data Federation) | Federated data delivery infrastructure used for staging and retrieving large files across compute sites. |
| Pelican | Client tool for transferring data to and from OSDF origins and caches. |
| Staging (`/staging/`) | CHTC shared filesystem for large file storage, accessible from execute nodes with `HasCHTCStaging`. |

### Software

In this tutorial, we use an Apptainer container containing hifiasm for genome assembly. The container is distributed via OSDF and transferred to execute nodes automatically by HTCondor.

Our recommendation for most users is to use Apptainer containers for deploying their software.
For instructions on how to build an Apptainer container, see our guide [Using Apptainer/Singularity Containers](https://chtc.cs.wisc.edu/uw-research-computing/apptainer-htc#main).
If you are familiar with Docker, or want to learn how to use Docker, see our guide [Using Docker Containers](https://chtc.cs.wisc.edu/uw-research-computing/docker-jobs#main).

This information can also be found in our guide [Using Software on CHTC](https://chtc.cs.wisc.edu/uw-research-computing/software-overview-htc#main).

### Data

Genome assembly involves large datasets, particularly for mammalian genomes. Understanding how data moves through the HTC system is essential for scaling assembly workflows.

#### Key data components:

* **ONT reads** (50-200+ GB per sample)
  * Stored on OSDF or in your CHTC `/staging/` directory
  * Transferred to execute nodes via HTCondor's file transfer mechanism
  * Use OSDF paths (`osdf:///...`) in `transfer_input_files` for efficient delivery
* **Assembly outputs** (~1-10 GB per assembly)
  * GFA assembly graphs and FASTA contig sequences
  * Packaged as `assembly_output.tar.gz` and transferred back to the submit host
* **Intermediate files** (variable, can be large)
  * Error correction and overlap files are generated during assembly
  * Cleaned up automatically by the script after packaging results

For guides on how data movement works on the HTC system, see our [Data Staging and Transfer to Jobs](https://chtc.cs.wisc.edu/uw-research-computing/htc-job-file-transfer) guides.

> [!IMPORTANT]
> ONT read files are often too large for the CHTC home directory (which has limited quota). Always store large sequencing files in `/staging/` and reference them via OSDF paths in your submit files.

### Compute Resources

Genome assembly with hifiasm is CPU- and memory-intensive but does not require GPUs. CHTC provides high-memory nodes suitable for genome assembly.

#### Resource guidelines by genome size:

| Genome Size | Coverage | Memory | CPUs | Disk | Estimated Runtime |
|-------------|----------|--------|------|------|-------------------|
| < 500 Mb | 30-50x | 16-32 GB | 8-16 | 100 GB | 1-3 hours |
| 500 Mb - 1 Gb | 30-50x | 32-64 GB | 16-32 | 250 GB | 2-6 hours |
| 1 - 3 Gb | 30-50x | 64-128 GB | 32 | 500 GB | 4-12 hours |
| > 3 Gb | 30-50x | 128-256 GB | 32+ | 1 TB | 8-24+ hours |

#### Key considerations:

* **Memory is the primary constraint**: hifiasm loads all read overlap information into memory. Insufficient memory is the most common cause of assembly job failure.
* **Thread scaling**: hifiasm scales well with multiple threads. Request as many CPUs as you need threads (up to 32-64 for large genomes).
* **Disk space**: Budget for raw reads (input) + intermediate files + output. Assembly intermediate files can be several times larger than the raw reads.
* **No GPU needed**: Unlike workflows such as AlphaFold3, genome assembly is entirely CPU-bound.

If you would like to learn more about CHTC compute resources, please visit the [CHTC Documentation Portal](https://chtc.cs.wisc.edu/uw-research-computing/).


## Getting Help

The CHTC Research Computing Facilitators are here to help researchers using the CHTC resources for their research. We provide a broad swath of research facilitation services, including:

* **Web guides**: [CHTC Guides](https://chtc.cs.wisc.edu/uw-research-computing/htc/guides.html) - instructions and how-tos for using the CHTC cluster.
* **Email support**: get help within 1-2 business days by emailing [chtc@cs.wisc.edu](mailto:chtc@cs.wisc.edu).
* **Virtual office hours**: live discussions with facilitators - see the [Email, Office Hours, and 1-1 Meetings](https://chtc.cs.wisc.edu/uw-research-computing/get-help.html) page for current schedule.
* **One-on-one meetings**: dedicated meetings to help new users, groups get started on the system; email [chtc@cs.wisc.edu](mailto:chtc@cs.wisc.edu) to request a meeting.

This information, and more, is provided in our [Get Help](https://chtc.cs.wisc.edu/uw-research-computing/get-help.html) page.
