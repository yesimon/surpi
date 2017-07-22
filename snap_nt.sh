#!/bin/bash
#
#	snap_nt.sh
#
#	This script runs SNAP against the NT database
#	Chiu Laboratory
#	University of California, San Francisco
#
#
# Copyright (C) 2014 Charles Chiu - All Rights Reserved
# SURPI has been released under a modified BSD license.
# Please see license file for details.
set -eo pipefail
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

expected_args=5
if [ $# -lt $expected_args ]
then
	echo "Usage: $scriptname <FASTQ input file> <directory containing SNAP NT indexes> <number of cores> <SNAP d-value cutoff> <SNAP binary>"
	exit 65
fi

###
inputfile=$1
SNAP_NT_index_directory=$2
cores=$3
SNAP_d_cutoff=$4
snap=$5
###

log "Starting SNAP to NT"
START1=$(date +%s)

log "Input file: $inputfile"
nopathf=${inputfile##*/} # remove the path to file
log "After removing path: $nopathf"
basef=${nopathf%.fastq} # remove FASTQextension
log "After removing FASTQ extension: $basef"

log "Mapping $basef to NT..."

cleanup() {
  rm -f $basef.prev.sam || true
  rm -f $basef.tmp.sam || true
  rm -f $basef.tmp2.sam || true
  rm -f $basef.NT.sam || true
  rm -f $basef.snapNT.log || true
  rm -f $basef.timeNT.log || true
}
cleanup
counter=0

: > $basef.snapNT.log
: > $basef.timeNT.log
for snap_index_basename in $(ls -1v "$SNAP_NT_index_directory") ; do
  snap_index="$SNAP_NT_index_directory/$snap_index_basename"
	log "Found $snap_index_basename ... processing ..."
	START2=$(date +%s)

	if [[ $counter -eq 0 ]]
	then
		#running first SNAP chunk
		log "$snap single $snap_index $basef.fastq -o $basef.$snap_index_basename.sam -t $cores -x -f -h 250 -d $SNAP_d_cutoff -n 25"
		/usr/bin/time -o $basef.time.log $snap single $snap_index $basef.fastq -o $basef.$snap_index_basename.sam -t $cores -x -f -h 250 -d $SNAP_d_cutoff -n 25 > $basef.snap.log
	    ln --symbolic --force $basef.$snap_index_basename.sam $basef.tmp.sam
# 		cp $basef.tmp.sam temp.sam
	else
		#running 2nd SNAP chunk through last SNAP chunk
		log "$snap single $snap_index $basef.tmp.fastq -o $basef.$snap_index_basename.sam -t $cores -x -f -h 250 -d $SNAP_d_cutoff -n 25"
		/usr/bin/time -o $basef.time.log $snap single $snap_index $basef.tmp.fastq -o $basef.$snap_index_basename.sam -t $cores -x -f -h 250 -d $SNAP_d_cutoff -n 25 > $basef.snap.log
	    ln --symbolic --force $basef.$snap_index_basename.sam $basef.tmp.sam
	fi

	cat $basef.snap.log >> $basef.snapNT.log
	cat $basef.time.log >> $basef.timeNT.log

	"$SCRIPT_DIR/compare_sam.py" $basef.tmp.sam $basef.prev.sam
	cat $basef.prev.sam | egrep -v "^@" | awk '{print "@"$1"\n"$10"\n""+"$1"\n"$11}' > $basef.tmp.fastq

	counter=1

	END2=$(date +%s)

	log "Done with $snap_index."
	diff=$(( $END2 - $START2 ))
	log "Mapping of $snap_index took $diff seconds."
done

# need to restore the hits
"$SCRIPT_DIR/update_sam.py" $basef.prev.sam $basef.NT.sam

rm -f $basef.tmp.sam
rm -f $basef.tmp.fastq
#rm -f $basef.prev.sam
rm -f $basef.$snap_index_basename.*

END1=$(date +%s)
log "Done with SNAP_NT"
diff=$(( $END1 - $START1 ))
log "output written to $basef.NT.sam"
log "SNAP_NT took $diff seconds"
