"""
Token ID diagnostic dump for side-by-side comparison with Dart WordPieceTokenizer.

Prints the exact input_ids, attention_mask, and human-readable tokens that
the canonical HuggingFace tokenizer produces for each test string.

Usage:
    python test/fixtures/dump_token_ids.py
"""

from transformers import AutoTokenizer

MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"

# Same strings used in embedding_pipeline_verification_test.dart
TEST_STRINGS = {
    "fever_and_chills": "fever and chills",
    "malaria_symptoms": "malaria symptoms",
    "punctuation_string": 'Signs & symptoms: fever (>38\u00b0C), chills, headache \u2014 seek care immediately!',
    "long_string": (
        "The patient presented with a history of high-grade fever for five days, "
        "associated with rigors, chills, and profuse sweating, particularly at night. "
        "She also reported headache, myalgia, and nausea without vomiting. "
        "On examination, she was febrile at 39.8 degrees Celsius, with mild pallor "
        "and tender hepatosplenomegaly. A peripheral blood smear confirmed the "
        "presence of Plasmodium falciparum ring-stage trophozoites at high parasitemia, "
        "indicating severe malaria requiring immediate treatment with parenteral artesunate."
    ),
}

def main():
    print(f"Loading tokenizer: {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

    for label, text in TEST_STRINGS.items():
        encoded = tokenizer(
            text,
            max_length=128,
            truncation=True,
            padding="max_length",
        )
        tokens = tokenizer.convert_ids_to_tokens(encoded["input_ids"])

        # Count real (non-padding) tokens
        real_count = sum(encoded["attention_mask"])

        print(f"\n{'='*60}")
        print(f"=== {label} ===")
        print(f"Text: {text[:80]}{'...' if len(text) > 80 else ''}")
        print(f"Real tokens (non-pad): {real_count}")
        print(f"input_ids ({len(encoded['input_ids'])}): {encoded['input_ids']}")
        print(f"attention_mask: {encoded['attention_mask']}")
        print(f"tokens: {tokens}")

        # Print just the real tokens for easy visual comparison
        real_tokens = [t for t, m in zip(tokens, encoded["attention_mask"]) if m == 1]
        print(f"real_tokens_only: {real_tokens}")


if __name__ == "__main__":
    main()
