# Dataset: Palla's Cat (*Otocolobus manul*) "Tater" - Oxford Nanopore Ligation Sequencing

## About the Data

This tutorial uses Oxford Nanopore Ligation Sequencing (ONT) reads from the Palla's Cat (*Otocolobus manul*), a specimen named **Tater**. The Palla's Cat is a small wild cat native to the grasslands and montane steppes of Central Asia. The expected genome size is approximately **2.4 Gb**, similar to the domestic cat (*Felis catus*).

## Obtaining the Data

### Option 1: Use the Pre-Staged OSDF Copy (Recommended for Tutorial)

The ONT reads for Tater have been pre-staged on the Open Science Data Federation (OSDF) for use with HTCondor jobs. The submit files in this tutorial are already configured to use this path:

```
osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263
```

No additional download is required if you are running this tutorial on CHTC.

### Option 2: Download from OSDF Using Pelican

If you want a local copy of the data, you can download it using the Pelican client:

```bash
# Download from the tutorial's pre-staged OSDF location
pelican object get osdf:///osg-public/data/tutorial-CHTC-Genome-Assembly/input/SRR22085263 ./
```

### Option 3: Download from SRA Public Bucket Using Pelican

You can also download the data directly from the SRA public bucket on AWS via OSDF:

**SRA Accession**: [`SRR22085263`](https://www.ncbi.nlm.nih.gov/sra/SRR22085263)

```bash
pelican object get osdf:///aws-opendata/us-east-1/sra-pub-run-odp/sra/SRR22085263/SRR22085263 ./
```

## Data Specifications

| Property | Value |
|----------|-------|
| Species | *Otocolobus manul* (Palla's Cat) |
| Specimen | Tater |
| Sequencing Platform | Oxford Nanopore Technologies |
| Library Prep | Ligation Sequencing Kit |
| Expected Genome Size | ~2.4 Gb |
| SRA Accession | [`SRR22085263`](https://www.ncbi.nlm.nih.gov/sra/SRR22085263) |
| File Format | FASTQ.GZ |

## Using a Subset for Testing

For testing and debugging purposes, you can create a smaller subset of reads:

```bash
# Extract the first 100,000 reads (4 lines per read in FASTQ format)
zcat SRR22085263 | head -n 400000 | gzip > SRR22085263_subset.fastq.gz
```

This subset will run much faster and use fewer resources, allowing you to verify that your pipeline is working correctly before committing to the full assembly.
