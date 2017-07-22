#!/bin/bash
#
#	table_generator.sh
#
#	This program generates a table showing taxonomic statistics using a SAM file as input.
#	Chiu Laboratory
#	University of California, San Francisco
#	January, 2014
#
# input file: annotated sam or annotated -m 8 file with taxonomies provided in the following format at the end of the .sam and -m 8 file:
# "gi# --family --genus --species"
# Output files are tab delimited  files ending in .counttable whereby rows represent taxonomic annotations at various levels (family, genus, species, gi)
# Columns represent individual barcodes found in the dataset, and cells contain the number of reads
# Variables 3,4,5,6 allow the generation of gi, species, genus or family -centric tables respectively if set to Y.
#
# Copyright (C) 2014 Samia N Naccache - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.

scriptname=${0##*/}
# way to get the absolute path to this script that should
# work regardless of whether or not this script has been sourced
# Find original directory of bash script, resovling symlinks
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in/246128#246128
function absolute_path() {
    local SOURCE="$1"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SOURCE="$(readlink "$SOURCE")"
        else
            SOURCE="$(readlink -f "$SOURCE")"
        fi
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    echo "$SOURCE"
}
SCRIPT_PATH="$(absolute_path "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname $SCRIPT_PATH)"
source "$SCRIPT_DIR/debug.sh"
source "$SCRIPT_DIR/logging.sh"

if [ $# -lt 6 ]; then
  echo "Usage: $scriptname <annotated file> <SNAP/RAP> <gi Y/N> <species Y/N> <genus Y/N> <family Y/N> <barcodes Y/N>"
  exit
fi

###
inputfile=$1
file_type=$2
gi=$3
species=$4
genus=$5
family=$6
barcodes=$7
###

###substitute forward slash with @_ because forward slash in species name makes it ungreppable. using @_ because @ is used inside the contig barcode (ie. #@13 is barcode 13, contig generated)
"$SCRIPT_DIR/create_tab_delimited_table.pl" -f $file_type $inputfile  |  sed 's/ /_/g' | sed 's/,/_/g' | sed 's/\//@_/g' > $inputfile.tempsorted
log "done creating $inputfile.tempsorted"

shopt -s nullglob

###########GENERATE BARCODE LIST#####################
if [[ $barcodes == "Y" ]]; then
  sed 's/#/ /g'  $inputfile.tempsorted | sed 's/\// /g' | awk '{print $2}' | sed 's/^/#/g' | sed 's/[1-2]$//g' | sort | uniq > $inputfile.barcodes.int #makes a barcode list from the entire file #change $inputfile.tempsorted to $inputfile once no need for temp table
  log "created list of barcodes"

sed '/N/d' $inputfile.barcodes.int > $inputfile.barcodes
else 
  : > $inputfile.barcodes
fi

######GENERATE gi LIST ##############
if [ "$gi" != "N" ]
then
  sort -k2,2 -k2,2g $inputfile.tempsorted | sed 's/\t/,/g' | sort -u -t, -k 2,2 | sed 's/,/\t/g' | awk -F "\t" '{print$2,"\t"$3,"\t"$4,"\t"$5}' | sed '/^$/d' | sed '/^ /d' > $inputfile.gi.uniq.columntable
  awk -F "\t" '{print$1}'  $inputfile.gi.uniq.columntable | sed '/^$/d' | sed '/^ /d' > $inputfile.gi.uniq.column
  log "done creating $inputfile.gi.uniq.column"
  for f in $(cat $inputfile.barcodes)
  do
    echo "bar$f" > bar$f.$inputfile.gi.output
    log "parsing barcode $f "
    grep "$f" $inputfile.tempsorted > bar.$f.$inputfile.tempsorted
    for d in $(cat $inputfile.gi.uniq.column)
    do
      grep -F -c -w "$d" bar.$f.$inputfile.tempsorted  >> bar$f.$inputfile.gi.output
    done
  done
  echo -e "GI\tSpecies\tGenus\tFamily(@=contigbarcode)" > $inputfile.header
  cat $inputfile.header $inputfile.gi.uniq.columntable > $inputfile.gi.counttable_temp
  paste $inputfile.gi.counttable_temp bar*.$inputfile.gi.output > $inputfile.gi.counttable
  sed -i 's/@_/ /g' $inputfile.gi.counttable
  log "done generating gi counttable"
fi

######GENERATE species LIST ##############
if [ "$species" != "N" ]
then
  sort -k3,3 -k3,3g $inputfile.tempsorted | sed 's/\t/,/g' | sort -u -t, -k 3,3 | sed 's/,/\t/g' | awk -F "\t" '{print$3,"\t"$4,"\t"$5}' | sed '/^$/d' | sed '/^ /d' > $inputfile.species.uniq.columntable
  awk -F "\t" '{print$1}'  $inputfile.species.uniq.columntable | sed '/^$/d' | sed '/^ /d' > $inputfile.species.uniq.column
  log "done creating $inputfile.species.uniq.column"
  for f in $(cat $inputfile.barcodes)
  do
    echo "bar$f" > bar$f.$inputfile.species.output
    log "parsing barcode $f "
    grep "$f" $inputfile.tempsorted > bar.$f.$inputfile.tempsorted
    for d in $(cat $inputfile.species.uniq.column)
    do
      grep -F -c -w "$d" bar.$f.$inputfile.tempsorted  >> bar$f.$inputfile.species.output
    done
  done
  echo -e "Species\tGenus\tFamily(@=contigbarcode)" > $inputfile.header
  cat $inputfile.header $inputfile.species.uniq.columntable > $inputfile.species.counttable_temp
  paste $inputfile.species.counttable_temp bar*.$inputfile.species.output > $inputfile.species.counttable
  sed -i 's/@_/ /g' $inputfile.species.counttable
  log "done generating species counttable"
fi
######GENERATE genus LIST ##############
if [ "$genus" != "N" ]
then
  sort -k4,4 -k4,4g $inputfile.tempsorted | sed 's/\t/,/g' | sort -u -t, -k 4,4 | sed 's/,/\t/g' | awk -F "\t" '{print$4,"\t"$5}' | sed '/^$/d' | sed '/^ /d' > $inputfile.genus.uniq.columntable
  awk -F "\t" '{print$1}'  $inputfile.genus.uniq.columntable | sed '/^$/d' | sed '/^ /d' > $inputfile.genus.uniq.column
  log "done creating $inputfile.genus.uniq.column"
  for f in $(cat $inputfile.barcodes)
  do
    echo "bar$f" > bar$f.$inputfile.genus.output
    log "parsing barcode $f"
    grep "$f" $inputfile.tempsorted > bar.$f.$inputfile.tempsorted
    for d in $(cat $inputfile.genus.uniq.column)
    do
      grep -F -c -w "$d" bar.$f.$inputfile.tempsorted  >> bar$f.$inputfile.genus.output
    done
  done
  echo -e "Genus\tFamily(@=contigbarcode)" > $inputfile.header
  cat $inputfile.header $inputfile.genus.uniq.columntable > $inputfile.genus.counttable_temp
  paste $inputfile.genus.counttable_temp bar*.$inputfile.genus.output > $inputfile.genus.counttable
  sed -i 's/@_/ /g' $inputfile.genus.counttable
  log "done generating genus counttable"
fi
######GENERATE family LIST ##############
if [ "$family" != "N" ]
then
  sort -k5,5 -k5,5g $inputfile.tempsorted | sed 's/\t/,/g' | sort -u -t, -k 5,5 | sed 's/,/\t/g' | awk -F "\t" '{print$5}' | sed '/^$/d' | sed '/^ /d' > $inputfile.family.uniq.column
  log "done creating $inputfile.family.uniq.column"
  for f in $(cat $inputfile.barcodes)
  do
    echo "bar$f" > bar$f.$inputfile.family.output
    log "parsing barcode $f"
    grep "$f" $inputfile.tempsorted > bar.$f.$inputfile.tempsorted
    for d in $(cat $inputfile.family.uniq.column)
    do
      grep -F -c -w "$d" bar.$f.$inputfile.tempsorted  >> bar$f.$inputfile.family.output
    done
  done
  echo "Family(@=contigbarcode)" > $inputfile.header
  cat $inputfile.header $inputfile.family.uniq.column > $inputfile.family.counttable_temp
  paste $inputfile.family.counttable_temp bar*.$inputfile.family.output > $inputfile.family.counttable
  sed -i 's/@_/ /g' $inputfile.family.counttable
  log "done generating family counttable"
fi

#########CLEANUP###############
rm -f $inputfile.barcodes
rm -f $inputfile.barcodes.int
rm -f $inputfile.family.counttable_temp
rm -f $inputfile.family.uniq.column
rm -f $inputfile.genus.counttable_temp
rm -f $inputfile.genus.uniq.column
rm -f $inputfile.genus.uniq.columntable
rm -f $inputfile.gi.counttable_temp
rm -f $inputfile.gi.uniq.column
rm -f $inputfile.gi.uniq.columntable
rm -f $inputfile.header
rm -f $inputfile.species.counttable_temp
rm -f $inputfile.species.uniq.column
rm -f $inputfile.species.uniq.columntable
rm -f $inputfile.tempsorted
rm -f $inputfile.tempsorted
rm -f bar*.$inputfile.family.output
rm -f bar*.$inputfile.genus.output
rm -f bar*.$inputfile.gi.output
rm -f bar*.$inputfile.species.output
rm -f bar*.$inputfile.family.output
rm -f bar*.$inputfile.genus.output
rm -f bar*.$inputfile.gi.output
rm -f bar*.$inputfile.species.output
rm -f bar.*.$inputfile.tempsorted
