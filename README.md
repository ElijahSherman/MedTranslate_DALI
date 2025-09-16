# Lexicon Induction for isiXhosa Medical Translation
This honours project adapts the work done by Hu et al. in the paper [Domain Adaptation of Neural Machine Translation by Lexicon Induction](https://aclanthology.org/P19-1286/).

## Installation
To create an Anaconda environment with all the necessary dependencies run the following command:
```
conda env create -f environment.yml
```

Then activate the environment using:
```
conda activate medtranslate-dali
```

## Generating the Synthetic Data
1. Run fast-align on the large general domain parallel corpus of data following the instructions in the [fast-align repository](https://github.com/clab/fast_align).
2. Using the output from fast-align, generate the seed lexicon using `build_lexicon.py` by running a command such as the following: 
```
python build_lexicon.py \
    --train_data corpus.txt \
    --aligned_file corpus.fwd_align \
    --output_file lexicon.txt
```
3. Add the small in-domain lexicon to the seed lexicon to get the final in-domain bilingual lexicon.
4. Using the [word-for-word back-translation script](https://github.com/JunjieHu/dali/blob/master/wfw_backtranslation.py) in the DALI repository, back-translate your English in-domain corpus of data into isiXhosa.
```
python wfw_backtranslation.py \
    --lexicon_infile lexicon.txt \
    --tgt_infile monolingual_corpus.en \
    --src_outfile synthetic_corpus.xh
```

## Training 
- Choose a translation direction to train models in and run the bash script for that direction to initiate a hyperparameter sweep
- Alternatively use the training python script to train a single model at a time, for example:
```
python train_en_to_xh.py \
        --base_model_path nllb-200/ \
        --data_dir data-bin/ \
        --output_dir finetuned_models/ \
        --learning_rate 5e-6 \
        --batch_size 4 \
        --num_epochs 5 \
        --gradient_accumulation_steps 8 \
        --warmup_ratio 0.1 \
        --weight_decay 0.01 \
        --label_smoothing 0.1
```


## Evaluation
If the hyperparameter sweep was run then the script `eng_to_xho_eval.sh` / `xho_to_eng_eval.sh` can be run to evaluate all of the models. To evaluate an individual model:
1. Generate translations of the evaluation set using the model:
```
python generate_translations.py \
        --model_path finetuned_models/model1 \
        --source_file dev.en \
        --output_file model1_predictions.xh \
        --source_lang "eng_Latn" \
        --target_lang "xho_Latn"
```
2. Generate the BLEU, chrF and chrF++ scores:
```
python verify_scores.py \
		--predictions model1_predictions.xh \
		--references dev.xh
```