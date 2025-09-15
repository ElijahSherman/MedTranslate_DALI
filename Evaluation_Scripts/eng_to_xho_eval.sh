#!/bin/bash

# Adapted from a script written by Nick Matzopoulos (mtznic006@myuct.ac.za)


# This script evaluates all the models trained in the English to isiXhosa hyperparameter sweep

# --- Log & Result File Configuration ---
LOG_DIR="${PWD}/eval_logs"
OUTPUT_DIR_BASE="outputs/eng_to_xho_evaluation"
RESULTS_FILE="${OUTPUT_DIR_BASE}/en_to_xh_sweep_results.csv"

mkdir -p "$OUTPUT_DIR_BASE"
exec >> "${LOG_DIR}/en_to_xh_eval.o" 2>> "${LOG_DIR}/en_to_xh_eval.e"

# --- Environment Setup ---
export HF_HOME=${PWD}/nllb-200 # Path to baseline model to fine-tune


# --- Conditionally Write CSV Header ---
if [ ! -f "$RESULTS_FILE" ]; then
  echo "Creating new results file with header: ${RESULTS_FILE}"
  echo "run_name,learning_rate,effective_batch_size,epochs,warmup_ratio,weight_decay,label_smoothing,bleu,chrf,chrf_plus" > "$RESULTS_FILE"
fi


# --- HYPERPARAMETER GRID ---
LEARNING_RATES=( "1e-6" "1e-5" "2e-5" "3e-5" "5e-5" "1e-4")
EFFECTIVE_BATCH_SIZES=( 32 64 )
NUM_EPOCHS=( 3 5 )
WARMUP_RATIOS=( "0.0" "0.1" )
WEIGHT_DECAYS=( "0.0" "0.01" )
LABEL_SMOOTHINGS=( "0.0" "0.1" )
BASE_BATCH_SIZE=4

EXPERIMENTS=()
for LR in "${LEARNING_RATES[@]}"; do
  for EBS in "${EFFECTIVE_BATCH_SIZES[@]}"; do
    for EPOCHS in "${NUM_EPOCHS[@]}"; do
      for WR in "${WARMUP_RATIOS[@]}"; do
        for WD in "${WEIGHT_DECAYS[@]}"; do
          for LS in "${LABEL_SMOOTHINGS[@]}"; do
            GA=$((EBS / BASE_BATCH_SIZE))
            EXPERIMENTS+=("${LR}:${BASE_BATCH_SIZE}:${GA}:${EPOCHS}:${WR}:${WD}:${LS}")
          done
        done
      done
    done
  done
done
TOTAL_EXPERIMENTS=${#EXPERIMENTS[@]}


echo "Found ${TOTAL_EXPERIMENTS} specific experiments to evaluate."
echo "Results will be saved to: ${RESULTS_FILE}"

# --- Evaluation Loop ---
for (( i=0; i<${TOTAL_EXPERIMENTS}; i++ )); do
    CONFIG_STRING=${EXPERIMENTS[$i]}
    IFS=':' read -r LR BS GA EPOCHS WR WD LS <<< "$CONFIG_STRING"
    EBS=$((BS * GA))
    
    RUN_NAME="run${i}_lr${LR}_ebs${EBS}_epochs${EPOCHS}_wr${WR}_wd${WD}_ls${LS}"
    MODEL_PATH="finetuned_models/en_to_xh_sweep/${RUN_NAME}"

    echo ""
    echo "======================================================"
    echo "      EVALUATING MODEL ${i} / ${TOTAL_EXPERIMENTS}"
    echo "      MODEL: ${RUN_NAME}"
    echo "======================================================"

    if [ ! -d "$MODEL_PATH" ]; then
        echo "SKIPPING: Model directory not found at ${MODEL_PATH}"
        continue
    fi
    
    SOURCE_FILE="${PWD}/data-bin/dev.en"
    REFERENCE_FILE="${PWD}/data-bin/dev.xh"
    PREDICTION_FILE="${OUTPUT_DIR_BASE}/${RUN_NAME}.pred.xh"

    echo "Generating translations..."
    python "${PWD}/generate_translations.py" \
        --model_path "$MODEL_PATH" \
        --source_file "$SOURCE_FILE" \
        --output_file "$PREDICTION_FILE" \
        --source_lang "eng_Latn" \
        --target_lang "xho_Latn"

    if [ ! -f "$PREDICTION_FILE" ]; then
        echo "ERROR: Generation failed for ${RUN_NAME}. No prediction file created."
        continue
    fi

    echo "Verifying scores..."
    METRICS_OUTPUT=$(python "${PWD}/verify_scores.py" --predictions "$PREDICTION_FILE" --references "$REFERENCE_FILE")
    
    BLEU_SCORE=$(echo "$METRICS_OUTPUT" | grep "BLEU" | awk '{print $NF}')
    CHRF_SCORE=$(echo "$METRICS_OUTPUT" | grep "chrF:" | awk '{print $NF}')
    CHRF_PLUS_SCORE=$(echo "$METRICS_OUTPUT" | grep "chrF++:" | awk '{print $NF}')

    echo "RESULTS: BLEU=${BLEU_SCORE}, chrF=${CHRF_SCORE}, chrF++=${CHRF_PLUS_SCORE}"
    echo "${RUN_NAME},${LR},${EBS},${EPOCHS},${WR},${WD},${LS},${BLEU_SCORE},${CHRF_SCORE},${CHRF_PLUS_SCORE}" >> "$RESULTS_FILE"
done

echo ""
echo "=== All English to isiXhosa Translation Model Evaluations Complete ==="