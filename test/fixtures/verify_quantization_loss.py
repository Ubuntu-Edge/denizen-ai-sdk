import numpy as np
import tensorflow as tf
from transformers import AutoTokenizer
from sentence_transformers import SentenceTransformer
import os

def cosine(a, b):
    dot = np.dot(a, b)
    normA = np.linalg.norm(a)
    normB = np.linalg.norm(b)
    return float(dot / (normA * normB))

def main():
    model_id = "sentence-transformers/all-MiniLM-L6-v2"
    tflite_path = "assets/models/all-MiniLM-L6-v2.tflite"

    print("Loading PyTorch FP32 model...")
    st_model = SentenceTransformer(model_id)
    st_model.max_seq_length = 128
    
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(model_id)

    print(f"Loading TFLite INT8 model from {tflite_path}...")
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    
    # Must resize tensors before allocate_tensors() for dynamic axes
    input_details = interpreter.get_input_details()
    for detail in input_details:
        interpreter.resize_tensor_input(detail['index'], [1, 128])
        
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    input_indices = {}
    for detail in input_details:
        name = detail['name']
        if 'inputs:0' in name or name == 'serving_default_inputs:0':
            input_indices['attention_mask'] = detail['index']  # swapped
        elif 'inputs_1:0' in name or name == 'serving_default_inputs_1:0':
            input_indices['input_ids'] = detail['index']       # swapped
        elif 'inputs_2:0' in name:
            input_indices['token_type_ids'] = detail['index']
            
    out_idx = output_details[0]['index']

    test_strings = [
        "malaria symptoms",
        "signs of malaria",
        "fever and chills",
        "clean drinking water",
        "The patient presented with a history of high-grade fever for five days, associated with rigors, chills, and profuse sweating, particularly at night. She also reported headache, myalgia, and nausea without vomiting. On examination, she was febrile at 39.8 degrees Celsius, with mild pallor and tender hepatosplenomegaly. A peripheral blood smear confirmed the presence of Plasmodium falciparum ring-stage trophozoites at high parasitemia, indicating severe malaria requiring immediate treatment with parenteral artesunate.",
        "Signs and symptoms: fever (>38C), chills, headache -- seek care immediately!"
    ]

    for text in test_strings:
        fp32_emb = st_model.encode(text, normalize_embeddings=True)
        
        encoded = tokenizer(text, max_length=128, padding='max_length', truncation=True, return_tensors='np')
        input_ids = encoded['input_ids'].astype(np.int32)
        attention_mask = encoded['attention_mask'].astype(np.int32)
        
        interpreter.set_tensor(input_indices['input_ids'], input_ids)
        if 'attention_mask' in input_indices:
            interpreter.set_tensor(input_indices['attention_mask'], attention_mask)
        if 'token_type_ids' in input_indices:
            token_type_ids = encoded['token_type_ids'].astype(np.int32)
            interpreter.set_tensor(input_indices['token_type_ids'], token_type_ids)
            
        interpreter.invoke()
        tflite_out = interpreter.get_tensor(out_idx)
        
        if len(tflite_out.shape) == 3:
            mask = attention_mask.astype(np.float32)
            mask_expanded = np.expand_dims(mask, -1)
            sum_embeddings = np.sum(tflite_out * mask_expanded, axis=1)
            sum_mask = np.clip(np.sum(mask_expanded, axis=1), a_min=1e-9, a_max=1e9)
            pooled = sum_embeddings / sum_mask
            pooled_norm = np.linalg.norm(pooled, axis=1, keepdims=True)
            int8_emb = (pooled / pooled_norm)[0]
        else:
            int8_emb = tflite_out[0]
            int8_emb = int8_emb / np.linalg.norm(int8_emb)
            
        sim = cosine(fp32_emb, int8_emb)
        print(f"Text: '{text[:20]}...' -> Cosine Similarity FP32 vs INT8: {sim:.6f}")

if __name__ == '__main__':
    main()
