#!/bin/bash

# Input and output file paths
input_file="test_sentences_new"
output_file="trans"
out="unique_Tamizh_words"

# Ensure output file is empty before writing
> "$output_file"

# Read each line from the input file
while IFS= read -r line; do
    # Use awk to extract content within double quotes and remove '.' and '?'
    cleaned_content=$(echo "$line" | awk -F'"' '{ for (i=2; i<=NF; i+=2) gsub(/[.?,/\!'-]/, "", $i); print $2 }')
    
    # Append cleaned content to output file
    echo "$cleaned_content" >> "$output_file"
done < "$input_file"

# Ensure output file is empty before writing
> "$out"

# Read each word from the input file and store unique words in output file
awk '{ for (i=1; i<=NF; i++) words[$i]++ } END { for (word in words) print word }' "$output_file" > "$out"

