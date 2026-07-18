"""
Reference embedding generator for Denizen AI pipeline verification.

Generates ground-truth embedding vectors using the canonical
sentence-transformers/all-MiniLM-L6-v2 model and saves them to a JSON file
so the Dart TFLiteEmbeddingProvider can be verified against them.

## Provenance
- Model: sentence-transformers/all-MiniLM-L6-v2 (canonical HuggingFace source)
- Max sequence length: 128 (matches TFLite conversion parameters in Nihal2000 model card)

## Usage
    python test/fixtures/generate_reference_embeddings.py

## Dependencies
    pip install sentence-transformers
"""

import json
import numpy as np
from sentence_transformers import SentenceTransformer

MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"

# Strings keyed to match embedding_pipeline_verification_test.dart expectations.
TEST_STRINGS = {
    # Short, clean strings — baseline pipeline correctness
    "malaria symptoms": "malaria symptoms",
    "signs of malaria": "signs of malaria",
    "fever and chills": "fever and chills",
    "clean drinking water": "clean drinking water",

    # Long string — tests truncation at the 128-token boundary.
    # This sentence is long enough to exceed 128 WordPiece tokens.
    "long_string_near_max_length": (
        "The patient presented with a history of high-grade fever for five days, "
        "associated with rigors, chills, and profuse sweating, particularly at night. "
        "She also reported headache, myalgia, and nausea without vomiting. "
        "On examination, she was febrile at 39.8 degrees Celsius, with mild pallor "
        "and tender hepatosplenomegaly. A peripheral blood smear confirmed the "
        "presence of Plasmodium falciparum ring-stage trophozoites at high parasitemia, "
        "indicating severe malaria requiring immediate treatment with parenteral artesunate."
    ),

    # Punctuation string — tests tokenizer edge cases for punctuation splitting.
    "punctuation_string": (
        "Signs & symptoms: fever (>38°C), chills, headache — seek care immediately!"
    ),
}

def main():
    print(f"Loading model: {MODEL_ID}")
    model = SentenceTransformer(MODEL_ID)

    # Set max_seq_length=128 to match the Nihal2000 TFLite conversion parameters.
    # CRITICAL: both sides must truncate at the same boundary — if Python encodes the
    # full string and Dart truncates at 128, the comparison is meaningless for long inputs.
    # In sentence-transformers v3+, truncation is controlled via model.max_seq_length,
    # not as kwargs to encode().
    model.max_seq_length = 128
    print(f"max_seq_length set to: {model.max_seq_length}")

    results = {}
    for key, text in TEST_STRINGS.items():
        embedding = model.encode(text, normalize_embeddings=True)
        results[key] = embedding.tolist()
        preview = f"[{embedding[0]:.6f}, {embedding[1]:.6f}, ...]"
        print(f"  '{key}' -> {preview} (dim={len(embedding)})")

    # Sanity check: semantically similar pairs should score higher than unrelated ones
    v_malaria = np.array(results["malaria symptoms"])
    v_signs   = np.array(results["signs of malaria"])
    v_water   = np.array(results["clean drinking water"])

    cos_similar  = float(np.dot(v_malaria, v_signs))
    cos_unrelated = float(np.dot(v_malaria, v_water))

    print(f"\nSanity checks:")
    print(f"  'malaria symptoms' vs 'signs of malaria':    {cos_similar:.4f}  [expect >> 0.7]")
    print(f"  'malaria symptoms' vs 'clean drinking water': {cos_unrelated:.4f}  [expect < 0.5]")

    if cos_similar <= cos_unrelated:
        print("  WARNING: Similar pair scored lower than unrelated pair — model may not be loaded correctly!")
    else:
        print("  OK: Semantic ordering is correct.")

    output_path = "test/fixtures/reference_embeddings.json"
    with open(output_path, "w") as f:
        json.dump({
            "model": MODEL_ID,
            "max_seq_len": 128,
            "vectors": results,
        }, f, indent=2)
    print(f"\nReference vectors saved to: {output_path}")
    print("Now run the Dart test: flutter test test/embedding_pipeline_verification_test.dart")


if __name__ == "__main__":
    main()
