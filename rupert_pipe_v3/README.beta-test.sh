# Hello, beta tester. With the CRAM files currently (as of 2022-02-04) distributed
# by Viola, please proceed as follows to produce the VCF pileups.
#
# Be sure to use up-to-date versions of samtools and bcftools; if on a Mac, you
# will also need to install GNU awk (= gawk; the awk scripts actually use gawk)
#

## 1. Prepare the raw single-sample pileup

# adjust these variables as needed
# read length
read_length=125
# output path (I use BCF, the compressed binary version of VCF, here)
pre_bcf="/path/to/pileup_pre.bcf"
# reference genome in FASTA format
ref_fa="dsimM252v1.2+microbiome.fa"
# max. depth to consider, set to 5x expected autosomal coverage
max_cov=500
# input path (if your samples have been sequenced on multiple lanes, the CRAMs
# for a single sample need to be samtools-merged into one file instead, see below)
in_cram="/path/to/single_sample.cram"

# chromosomes of interest
chroms="2L 2R 3L 3R X"

# 1.a convert to qname-sorted SAM that only contains primary pairs (needed by remapq)
samtools view -u "$in_cram" $chroms |\
# or with multiple CRAMs for the same sample
# samtools merge -o - in1.cram in2.cram ... |\
  samtools collate -Ouf - | samtools fixmate -ru - - | samtools view -f 0x2 -h - |\
  # 1.b flag short fragments  (replace $rl with the actual read length)
  ./flag-short.awk -v READ_LENGTH=$read_length |\
  # 1.c recalculate mapping quality
  ./remapq.awk -v NORD=7.5 |\
  # 1.d resort by coordinate (maybe use -m 4G to use more memory and -T /Volumes/Temp/sortsam to use a larger temp dir)
  samtools sort -u - |\
  # 1.e make single-sample pileup
  # --incl-flags 0x2 ... include only proper pairs
  # -q 10 ... include only reads with a mapping quality that apsses the threshold
  #          (may need to be adjusted if remapq step is omitted or NORD!=7.5 is used)
  #          (if in doubt, check a histogram of the MAPQ values in $in_cram)
  # -Q 20 ... count only bases with min(base quality,BAQ) passing the threshold
  # -D    ... enable BAQ calculation for all positions (check bcftools manpage for details)
  # -a DP,AD ... annotate with additional fields (AD = allele depth for each allele is needed below!)
  bcftools mpileup -f "$ref_fa" -d $mxd --incl-flags 0x2 -q 10 -Q 20 -D -a DP,AD,QS,SCR -Ou - |\
  # 1.f remove INFO tags we do not need to reduce file size
  bcftools annotate -Ov -x INFO/IMF,INFO/VDB,INFO/RPBZ,INFO/MQBZ,INFO/MQSBZ,INFO/SCBZ,INFO/BQBZ,INFO/FS,INFO/SGB,INFO/I16,INFO/QS,INFO/MQ0F,FORMAT/PL |\
  # 1.g annotate raw single-sample pileup with more FORMAT tags (specifically, save INFO/DP to FORMAT/DP)
  ./info2fmt.awk -v tags=DP | bcftools view --no-version -Ob > "$pre_bcf"

# the steps above will be added to the central pipeline in the future
exit

## 2. Combine multiple single-sample pilups into a multi-sample pileup
#
# folder where only the annotated pileups (output of step 2) to be combined are found
# "ls $in_path/*.bcf" shows the files in the same order in which you get the columns in the mpileup
in_folder="/path/to/single_sample_pileups/"
out_bcf="/path/to/mpileup.bcf"
# 2.a merge multiple raw pileups into multi-sample mpileup
bcftools merge --no-index --merge both --threads 8 -Ov -o - "$in_folder"/*.bcf |\
  # 2.b annotate with FORMAT/AF (observed allele frequencies) and FORMAT/XF (expected allele frequencies
  # under a multinomial sampling model) tags; also add  FORMAT/SAC (sum of allele counts) tag for convenience
  # finally, change REF of positions with a reference count of 0 to ALT{1} and modify all affected tags accordingly
  # tag such positions with the INFO/RMOD flag
  ./post-merging.awk |\
  # directly pipe into the step 4.a or
  # 2.c save VCF to compressed format
  bcftools view --no-version -Ob > "$out_bcf"

## 3. Filter mpileup to keep only SNPs
#
# input file, can also be "-" if you omit 3.c
in_bcf="/path/to/mpileup.bcf"
# BED file of regions to exclude (must match the reference)
norepeats_bed="/path/to/norepeats.bed"
# filter expression removin non-SNPs and positions of dubious
# coverage depth (adjust as needed; here, ~2200x coverage was
# expected across all samples in the mpileup)
flt_expr='TYPE = "snp" & INFO/DP > 1000 & INFO/DP < 4500'
# output path (bgzipped vcf is the most widely used format)
out_vcf="/path/to/mpileup.flt.vcf.gz"

# 3.a filter SNPs close to INDELs or in repeat regions
# -g 5       ... filter out SNPs that are this close to INDELs
# -T bedfile ... only output positions described by the provided BED file
bcftools filter -g 5 -T "$norepeats_bed" -Ou "$in_bcf" |\
  # 3.b keep only SNPs and adjust coverage depth thresholds as appropriate
  # (here ~2200x was expected across all samples)
  bcftools filter -i "$flt_expr" -Ou - | \
  # 3.c make positions single-allelic for easier manipulation
  bcftools norm -m- -Oz - > "$out_vcf"

exit

# Some examples of what to do with the mpileups

# Example: extract coverages & allele frequencies as needed for CMH test, e.g., using ACER
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%SAD]\n' mpileup.flt.vcf.gz | bgzip > mpileup.flt.cov.txt.gz
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%XF]\n' mpileup.flt.vcf.gz | bgzip > mpileup.flt.alf.txt.gz

# Example: convert to SYNC (if you need a deletion count, do it before INDELs are removed ...)
bcftools norm -m- mpileup.bcf | ./vcf2sync.awk | bgzip > mpileup.sync.gz
