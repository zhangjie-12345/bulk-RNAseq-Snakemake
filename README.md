# RNA-seq 分析流程 (Snakemake)

**作者:** 张杰  
**简介:** 本流程基于 Snakemake 构建，适用于处理双端（paired-end）RNA-seq 数据，实现从质控、去除低质量序列、比对到基因定量的全流程自动化分析。

---

## 目录
- [流程概述](#流程概述)
- [环境要求](#环境要求)
- [输入文件](#输入文件)
- [分析步骤](#分析步骤)
- [运行方法](#运行方法)
- [输出结果](#输出结果)
- [配置文件说明](#配置文件说明)
- [许可证](#许可证)

---

## 流程概述

该流程自动化执行标准 RNA-seq 分析，包括：

1. 使用 **FastQC** 进行原始数据质控  
2. 使用 **fastp** 进行去接头和低质量序列过滤  
3. 使用 **STAR** 将 reads 比对到参考基因组  
4. 基因水平计数（可选，使用 featureCounts）

流程完全基于配置文件驱动，方便用户在不同数据或基因组上复用。

---

## 环境要求

- [Snakemake](https://snakemake.readthedocs.io/)  
- Python 包：
  - `pandas`
  - `pyyaml`
- 生物信息学工具：
  - `fastqc`
  - `fastp`
  - `STAR`
  - `featureCounts`（如需基因计数）

---

## 输入文件

1. **原始 RNA-seq 数据（FASTQ 文件）**  
   双端测序的 `.fq.gz` 文件。路径在样本表中指定。

2. **样本表 (`samples.tsv`)**  
   tab 分隔表格示例：

   | Experiment | R1                  | R2                  |
   |------------|-------------------|-------------------|
   | sample1    | /path/to/sample1_1.fq.gz | /path/to/sample1_2.fq.gz |
   | sample2    | /path/to/sample2_1.fq.gz | /path/to/sample2_2.fq.gz |

3. **参考基因组文件**  
   - `genome.fa` : 基因组 FASTA 文件  
   - `genome.gtf`: 基因注释 GTF 文件

4. **配置文件 (`config.yaml`)**  
   示例：

   ```yaml
   samples_tsv: "Ab_bulk_RNAseq_colistin.tsv"
   genome_fasta: "Ref/genome.fa"
   genome_gtf: "Ref/genome.gtf"
   star_index: "Ref/STAR_index"
   threads:
     fastp: 8
     fastqc: 4
     star: 8
