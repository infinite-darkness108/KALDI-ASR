#!/bin/bash

lang_dir=data/lang_bigram

# STEP 1: Prepare G.txt from G.fst, and modify its weights to be equal

fstprint --isymbols=$lang_dir/words.txt --osymbols=$lang_dir/words.txt $lang_dir/G.fst > $lang_dir/G.txt

input_file=$lang_dir/"G.txt"
output_file=$lang_dir/"G_new.txt"

# Count occurrences of each unique first field
awk '{count[$1]++} END {for (key in count) print key, count[key]}' $input_file > field_counts.txt

# Process the input file and replace the last field
awk 'NR==FNR {
    freq[$1] = $2; next
} {
    # Calculate the new value for the last field
    new_value = -log(1 / freq[$1]);
    # Print the modified line
    for (i = 1; i < NF; i++) printf "%s\t", $i;
    printf "%.8f\n", new_value;
}' field_counts.txt $input_file > $output_file

# Clean up temporary file
rm field_counts.txt
mv $output_file $input_file

echo "Updated G.txt"


# STEP 2: Compile the new Grammar FST and check if it is determinizable and stochastic

fstcompile --isymbols=$lang_dir/words.txt --osymbols=$lang_dir/words.txt --keep_isymbols=false \
    --keep_osymbols=false $lang_dir/G.txt | fstarcsort --sort_type=ilabel > $lang_dir/G.fst 

# Checking that G is stochastic [note, it wouldn't be for an Arpa]
fstisstochastic $lang_dir/G.fst || echo Error: G is not stochastic

# Checking that G.fst is determinizable.
fstdeterminize $lang_dir/G.fst /dev/null || echo Error determinizing G.

# Checking that L_disambig.fst is determinizable.
fstdeterminize $lang_dir/L_disambig.fst /dev/null || echo Error determinizing L.

# Checking that disambiguated lexicon times G is determinizable
fsttablecompose $lang_dir/L_disambig.fst $lang_dir/G.fst | \
   fstdeterminize >/dev/null || echo Error

# Checking that L_disambig.G is stochastic:
fsttablecompose $lang_dir/L_disambig.fst $lang_dir/G.fst | \
   fstisstochastic || echo Error: L_disambigG is not stochastic.

echo "Succeeded preparing grammar G.fst"
