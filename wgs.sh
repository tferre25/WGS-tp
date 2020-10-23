#!/bin/sh

# Affiche les logiciels installables
module av 
# Connaître l'état d'avancement (à lancer dans un autre terminal)
squeue -u tferreira

ssh tferreira@core.cluster.france-bioinformatique.fr
cd /shared/projects/uparis_m2_bi_2020/metagenomique_2

module add bowtie2/2.4.1

# Indexation des banques
bowtie2-build databases/all_genome.fasta all_genome.fasta

# On lance alignement avec bowtie -c nombre de coeurs de la machine, -p nombre de coeur utilisé par le logiciel
# -x le gène de référence, le -S output
srun -c 12 bowtie2 -p 12 -x databases/all_genome.fasta -1 fastq/EchA_R1.fastq.gz -2 fastq/EchA_R2.fastq.gz -S tferreira/bowtie_resuslts_EchA.sam

# convertir sam en bam
module add samtools
srun -c 12 samtools view -@ 12 -Sb tferreira/bowtie_resuslts_EchA.sam > tferreira/bowtie_resuslts_EchA.bam

# Check your data
srun samtools view tferreira/bowtie_resuslts_EchA.bam | head

# Trie le fichier bam
srun -c 12 samtools sort -@ 12 tferreira/bowtie_resuslts_EchA.bam -o tferreira/bowtie_resuslts_EchA.bam.sorted.bam

# Index un génome trié sorted.bam 
srun -c 12 samtools index -@ 12 tferreira/bowtie_resuslts_EchA.bam.sorted.bam

# Retrieve and print stats in the index file corresponding to the input file. 
srun -c 12 samtools idxstats -@ 12 tferreira/bowtie_resuslts_EchA.bam.sorted.bam > tferreira/EchA_stats
# traduction du fichier stats
grep ">" databases/all_genome.fasta|cut -f 2 -d ">" > tferreira/association.tsv


# MegaHit, -m mémoire, -t coeur
module add megahit --version 
srun  -c 12 megahit  -1 fastq/EchA_R1.fastq.gz -2 fastq/EchA_R2.fastq.gz  -m 0.5  -t 12  -o tferreira/megahit_result

# Prodigal, Prédire les gènes présents sur les contigs

#-d:  Write nucleotide sequences of genes to the selected file.
#-i:  Specify FASTA/Genbank input file (default reads from stdin).
#-o:  Specify output file (default writes to stdout).

module add prodigal --version
srun -c 12 prodigal -i tferreira/megahit_result/final.contigs.fa -d tferreira/genes.pred 

# sélectionne tous les gènes complets, genes.pred est le fichier fasta
sed "s:>:*\n>:g" genes.pred | sed -n "/partial=00/,/*/p"|grep -v "*" > genes_full.fna

# Annoter les gènes “complets” contre la banque resfinder (database/resfinder.fna) BLastN
module add blast/2.9.0
srun -c 12 blastn -db databases/resfinder.fna -evalue 1e-3 -perc_identity 80 -query tferreira/genes_full.fna -qcov_hsp_perc 80 -out tferreira/blast_results

