#!/bin/bash

#script_dir=$(pwd)
script_dir='/home2/db/HIV-cluster'

FASTA=""
REF="${script_dir}/HIV_aligned_references.fasta"

usage="preprocessing.sh [-h] [-f] -- program to split fasta sequences by subtype and generate a phylogeny for each one\nwhere:
        -h      show this help text
        -f      input sequences in fasta format"

while getopts "hf:r:dp" opt;
do
        case $opt in
                h)
                        echo -e "$usage"
                        exit 1
                        ;;
                f)
                        echo -e "\nInput fasta: $OPTARG \n" 
                        FASTA=$OPTARG
                        ;;
                \?)
                        echo "invalid option -$OPTARG"
                        ;;
                :)
                        echo "Arguments required"
                        exit 1
                        ;;
        esac
done

# CHECK USER INPUT PARAMETERS!!
if [ -z "$FASTA" ];
then
        echo "Missing parameter - fasta file!"
        exit 0
fi

mac2unix $FASTA
wait

# use code from getSubtypeInformation.sh to perform subtype query

echo "Number of sequences: "
grep -c '>' $FASTA
echo ""


BASE=$(basename $FASTA)
FILENAME=$(basename "${BASE%.*}")
now="$(date +'%d-%m-%Y')"

JSON="$now.$FILENAME.json"
TEXTFILE="$now.$FILENAME.txt"

${script_dir}/bin/perform_query.py --fasta $FASTA --json $JSON

wait
echo "Subtype query complete. Parsing json..."


${script_dir}/bin/parse_json_write_docx.py --json $JSON --output $TEXTFILE --reports
wait

${script_dir}/bin/parse_json_store_metadata.py --json $JSON
wait

echo "Finished generating reports."

OUTPUT="$now.$FILENAME.fasta"
# Run alignment
echo "Running mafft alignment. Will save to :  $OUTPUT"

mafft --add $FASTA --reorder $REF > $OUTPUT
wait


echo "Running phylogeny using Raxml and Jukes Cantor model with bootstrap analysis..."
raxmlHPC -f a -m GTRGAMMA --JC69 -T 8 -p 12345 -x 12345  -# 100 -s $OUTPUT -n $now
TREE="RAxML_bipartitionsBranchLabels.$now"
wait

${script_dir}/bin/visualise_phylogeny.py --tree $TREE --reroot

RESULTS="results_${now}"
mkdir ${RESULTS}
mv $now* $RESULTS

RAX="${RESULTS}/RAxML"
mkdir $RAX
mv RAxML* $RAX

mv $RAX/*.pdf $RESULTS
