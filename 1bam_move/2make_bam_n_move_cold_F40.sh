#!/bin/bash

for cramfile in $(find /Volumes/Data/185/a/ -type f -maxdepth 1 -name "*.cram" -exec basename {} \;)
do
  cramfilename=${cramfile%.*}
  bamfilename=$(awk -v var="$cramfilename" '$1==var{print $2}' ~/RS/pipeline/1bam_move/cram2bam_name.txt)
  rm -r  ~/RS/data/${bamfilename}/; mkdir ~/RS/data/${bamfilename}/
done

for pool in a b c d e
do
  for cramfile in $(find /Volumes/Data/185/${pool}/ -type f -maxdepth 1 -name "*.cram" -exec basename {} \;)
  do
    cramfilename=${cramfile%.*}
    bamfilename=$(awk -v var="$cramfilename" '$1==var{print $2}' ~/RS/pipeline/1bam_move/cram2bam_name.txt)
    echo "samtools view -b -q 20 -F 0x400 -T ~/RS/reference/dsimM252v1.2+microbiome.fa -o ~/RS/data/${bamfilename}/${bamfilename}_${pool}.bam /Volumes/Data/185/${pool}/${cramfile}"
  done
done | parallel -j 8

for cramfile in $(find /Volumes/Data/185/${pool}/ -type f -maxdepth 1 -name "*.cram" -exec basename {} \;)
do
  cramfilename=${cramfile%.*}
  bamfilename=$(awk -v var="$cramfilename" '$1==var{print $2}' ~/RS/pipeline/1bam_move/cram2bam_name.txt)
  samtools merge -o ~/RS/data/${bamfilename}/${bamfilename}.bam ~/RS/data/${bamfilename}/${bamfilename}_a.bam ~/RS/data/${bamfilename}/${bamfilename}_b.bam ~/RS/data/${bamfilename}/${bamfilename}_c.bam ~/RS/data/${bamfilename}/${bamfilename}_d.bam ~/RS/data/${bamfilename}/${bamfilename}_e.bam
done
