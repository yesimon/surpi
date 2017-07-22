#!/bin/bash
#
#	extractHeaderFromFastq_ncores
#
# 	script to retrieve fastq entries given a list of headers, when fastq entries reside in a large parent file (fqextract fails)
# 	Chiu Laboratory
# 	University of California, San Francisco
# 	3/15/2014
#
#
# Copyright (C) 2014 Samia N Naccache, Scot Federman, and Charles Y Chiu - All Rights Reserved
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

if [ $# -lt 4 ]
then
	echo "Usage: $scriptname <#cores> <parent file fq> <query1 sam> <output fq> <query2 sam> <output2 fq>"
	exit 65
fi

###
cores="$1"
parentfile="$2"
queryfile="$3"
output="$4"
queryfile2="$5"
output2="$6"
###

log "Starting splitting $inputfile"

#deriving # of lines to split
headerid=$(head -1 $parentfile | cut -c1-4)
log "headerid = $headerid"
log "Starting grep of FASTQentries"
FASTQentries=$(grep -c "$headerid" $parentfile)
log "there are $FASTQentries FASTQ entries in $queryfile"
let "numlines = $FASTQentries * 4"
log "numlines = $numlines"
let "FASTQPerCore = $FASTQentries / $cores"
log "FASTQPerCore = $FASTQPerCore"
let "LinesPerCore = $FASTQPerCore * 4"
log "LinesPerCore = $LinesPerCore"

#splitting
log "Splitting $parentfile into $cores parts with prefix $parentfile.SplitXS"
split -l $LinesPerCore -a 3 $parentfile $parentfile.SplitXS &
awk '{print $1}' $queryfile > $queryfile.header &
log "extracting header from $queryfile"

for job in $(jobs -p)
do
	wait $job
done

log "Done splitting $parentfile into $cores parts with prefix $parentfile.SplitXS, and Done extracting $queryfile.header"

# retrieving fastqs
log "Starting retrieval of $queryfile headers from each $parentfile subsection"

let "adjusted_cores = $cores / 4"

parallel --gnu -j $adjusted_cores "cat {} | paste - - - - | sed 's/^\(@[^ ]*\)[^\t]*/\1/' | tr '\t' '\n' | fqextract $queryfile.header > $queryfile.{}" ::: $parentfile.SplitXS[a-z][a-z][a-z]

# concatenating split retrieves into output file
log "Starting concatenation of all $queryfile.$parentfile.SplitXS"
cat $queryfile.$parentfile.SplitXS[a-z][a-z][a-z] > $output
log "Done generating $output"

# need to fix this so that there's a conditional trigger of this second query file retrieval
log "processing second query file"
awk '{print $1}' $queryfile2 > $queryfile2.header

log "parallel -j $adjusted_cores -i bash -c cat {} | fqextract $queryfile2.header > $queryfile2.{} -- $parentfile.SplitXS[a-z][a-z][a-z]"
parallel --gnu -j $adjusted_cores "cat {} | paste - - - - | sed 's/^\(@[^ ]*\)[^\t]*/\1/' | tr '\t' '\n' | fqextract $queryfile2.header > $queryfile2.{}" ::: $parentfile.SplitXS[a-z][a-z][a-z]

log "Done retrieval of $queryfile2 headers from each $parentfile subsection"
log "Starting concatenation of all $queryfile2.$parentfile.SplitXS"
cat $queryfile2.$parentfile.SplitXS[a-z][a-z][a-z] > $output2
log "Done generating $output2"
rm -f $queryfile2.header
rm -f $queryfile2.$parentfile.SplitXS[a-z][a-z][a-z]

#cleanup
rm -f $queryfile.header
rm -f $queryfile.$parentfile.SplitXS[a-z][a-z][a-z]
rm -f $parentfile.SplitXS[a-z][a-z][a-z]
