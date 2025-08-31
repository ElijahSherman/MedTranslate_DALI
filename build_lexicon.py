"""
This file is used to construct a lexicon by taking in the fast-align output
and translating it into the actual words that are aligned and storing the results in a file.

The train_data file should follow the format:
eng_sentence ||| xho_sentence
eng_sentence ||| xho_sentence
eng_sentence ||| xho_sentence
...
...

The aligned_file should be the file output by fast-align on the train_data file

The output file will follow the format:
xho eng
xho eng
xho eng
...
...
"""

import re
import argparse


def contains_strange_characters(text):
    # Allow standard printable ASCII characters and explicitly allow the pipe symbol `|`
    return bool(re.search(r'[^A-Za-z0-9\s!"#$%&\'()*+,\-./:;<=>?@\[\\\]^_`{|}~]', text))

def main():
    parser = argparse.ArgumentParser(description="Build lexicon from fast-align output")
    parser.add_argument('--train_data', type=str, required=True, help="Path to train data file")
    parser.add_argument('--aligned_file', type=str, required=True, help="Path to file output by fast-align")
    parser.add_argument('--output_file', type=str, required=True, help="Path to lexicon file to write to")
    args = parser.parse_args()

    train_data = open(args.train_data, "r", encoding="utf-8")
    aligned_file = open(args.aligned_file, "r", encoding="utf-8")
    lexicon_file = open(args.output_file, "w", encoding="utf-8")

    print_count = 0
    with train_data as t, aligned_file as a:
        for s_pair, alignment in zip(t,a): # For each sentence pair and alignment in the respective files
            if print_count % 10000 == 0: print(f"Completed {print_count} sentence pairs") # Used to track progress
            sentence_list = s_pair.strip().split(" ||| ") # Split the source and target sentences

            if len(sentence_list) != 2:
                print(f"Error on line {print_count}, array does not have 2 values")
                print(f"Line causing the issue: {sentence_list}")
                continue
            eng = sentence_list[0]
            xho = sentence_list[1]
            eng = eng.split(" ")
            xho = xho.split(" ")
            alignment = alignment.strip() # Get the alignment for the words in the sentences
            aligned_arr = alignment.split(" ") # e.g. ['1-3', '2-1', '4-4']

            strange_count = 0

            # This loop gets the indices of the corresponding words and writes them to the file
            for word_pair in aligned_arr:
                
                if not word_pair: continue # Skip empty lines

                indices =[int(i) for i in word_pair.split("-")] # e.g. [1, 3]

                # Get the words that correspond to each other:
                eng_word = eng[indices[0]].lower()
                xho_word = xho[indices[1]].lower()

                if contains_strange_characters(eng_word) or contains_strange_characters(xho_word):
                    strange_count += 1
                    print(f"Strange character found, English {eng_word}, isiXhosa {xho_word}")
                    continue # Do not write the strange character to the lexicon

                lexicon_file.write(f"{xho_word} {eng_word}\n")
            
            print_count += 1

    train_data.close()
    aligned_file.close()
    lexicon_file.close()

if __name__ == "__main__":
    main()
