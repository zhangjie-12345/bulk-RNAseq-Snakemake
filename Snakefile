# =============================
# Snakemake RNA-seq Pipeline (config-driven)
# Author: Zhangjie
# =============================

import pandas as pd

# 从 config.yaml 读取参数
SAMPLES_TSV = config["samples_tsv"]
GENOME_FA   = config["genome_fasta"]
GENOME_GTF  = config["genome_gtf"]
STAR_INDEX  = config["star_index"]

THREADS = config["threads"]

# 读取样本表
samples = pd.read_csv(SAMPLES_TSV, sep="\t")

SAMPLES = samples["Experiment"].tolist()
SAMPLE_R1 = dict(zip(samples["Experiment"], samples["R1"]))
SAMPLE_R2 = dict(zip(samples["Experiment"], samples["R2"]))

rule all:
    input:
        expand("04.featureCounts_out/all_featureCount_out",),
        expand("02.fastqc_out/{sample}_fastqc_out/{sample}_1_fastqc.html", sample=SAMPLES),
        expand("02.fastqc_out/{sample}_fastqc_out/{sample}_2_fastqc.html", sample=SAMPLES)

# ---------- 00. link rawdata ----------

# ---------- 01. fastp ----------
rule fastp:
    input:
        r1=lambda wildcards: SAMPLE_R1[wildcards.sample],
        r2=lambda wildcards: SAMPLE_R2[wildcards.sample]
    output:
        r1="01.fastp_out/{sample}_1.fq.gz",
        r2="01.fastp_out/{sample}_2.fq.gz",
        html="01.fastp_out/{sample}.html",
        json="01.fastp_out/{sample}.json"
    threads: THREADS["fastp"]
    shell:
        """
        mkdir -p 01.fastp_out
        fastp -i {input.r1} -I {input.r2} \
              -o {output.r1} -O {output.r2} \
              -h {output.html} -j {output.json} \
              -w {threads}
        """

# ---------- 02. fastqc ----------
rule fastqc:
    input:
        r1="01.fastp_out/{sample}_1.fq.gz",
        r2="01.fastp_out/{sample}_2.fq.gz"
    output:
        html1="02.fastqc_out/{sample}_fastqc_out/{sample}_1_fastqc.html",
        html2="02.fastqc_out/{sample}_fastqc_out/{sample}_2_fastqc.html"
    threads: THREADS["fastqc"]
    shell:
        """
        mkdir -p 02.fastqc_out/{wildcards.sample}_fastqc_out
        fastqc -t {threads} {input.r1} {input.r2} -o 02.fastqc_out/{wildcards.sample}_fastqc_out
        """

# ---------- 03. STAR index ----------
rule star_index:
    input:
        fa=GENOME_FA,
        gtf=GENOME_GTF
    output:
        directory(STAR_INDEX)
    threads: THREADS["star"]
    shell:
        """
        STAR --runThreadN {threads} \
             --runMode genomeGenerate \
             --genomeDir {output} \
             --genomeSAindexNbases 12 \
             --genomeFastaFiles {input.fa} \
             --sjdbGTFfile {input.gtf} \
             --sjdbOverhang 149
        """

# ---------- 03. STAR mapping ----------
rule star_align:
    input:
        index=rules.star_index.output,
        r1="01.fastp_out/{sample}_1.fq.gz",
        r2="01.fastp_out/{sample}_2.fq.gz"
    output:
        bam="03.STAR_align/{sample}_starout_Aligned.sortedByCoord.out.bam",
        transcriptome="03.STAR_align/{sample}_starout_Aligned.toTranscriptome.out.bam",
        counts="03.STAR_align/{sample}_starout_ReadsPerGene.out.tab"
    threads: THREADS["star"]
    shell:
        """
        mkdir -p 03.STAR_align
        STAR --runThreadN {threads} \
             --genomeDir {input.index} \
             --readFilesCommand zcat \
             --readFilesIn {input.r1} {input.r2} \
             --limitBAMsortRAM 2000000000 \
             --outFileNamePrefix 03.STAR_align/{wildcards.sample}_starout_ \
             --outSAMtype BAM SortedByCoordinate \
             --outBAMsortingThreadN {threads} \
             --quantMode TranscriptomeSAM GeneCounts
        """

# ---------- 04. featureCounts ----------
rule featurecounts:
    input:
        bams=expand("03.STAR_align/{sample}_starout_Aligned.sortedByCoord.out.bam", sample=SAMPLES)
    output:
        "04.featureCounts_out/all_featureCount_out"
    threads: THREADS["featurecounts"]
    shell:
        """
        mkdir -p 04.featureCounts_out
        featureCounts -T {threads} -p -B -C -t CDS \
            -a {GENOME_GTF} \
            -o {output} {input.bams}
        sed -i 's|03.STAR_align/||g' {output}
        sed -i 's/_starout_Aligned.sortedByCoord.out.bam//g' {output}
        """

