#!/bin/sh

for chr in 2L 2R 3L 3R 4 X
do
  samtools mpileup -B -q 20 -Q 0 -f ~/RS/reference/dsimM252v1.2+microbiome.fa \
  $(ls -R ~/RS/data/*/*_${chr}.bam) | \
  # need to figure out how to specifz the Pop and Gen instead of * all bam files.
  # maybe partition the gen? and R? so that I can put them into the code.
  java -jar ~/RS/pipeline/popoolation2/mpileup2sync.jar --input /dev/stdin \
  --output ~/RS/result/reverse_${chr}.sync --fastq-type sanger \
  --min-qual 20 --threads 12
done


#cat \
#~/RS/result/cold_F30_cmh/cold_F30_r11_2L.sync ~/RS/result/cold_F30_cmh/cold_F30_r11_2R.sync \
#~/RS/result/cold_F30_cmh/cold_F30_r11_3L.sync ~/RS/result/cold_F30_cmh/cold_F30_r11_3R.sync \
#~/RS/result/cold_F30_cmh/cold_F30_r11_4.sync ~/RS/result/cold_F30_cmh/cold_F30_r11_X.sync > \
#~/RS/result/cold_F30_cmh/cold_F30_r11_all_chr_mq20_bq20.sync
