"""Evaluate human-verified transcripts, never fabricate provider scores."""
import argparse
import json
import re
import unicodedata
from pathlib import Path


def normalize(text):
    text = unicodedata.normalize('NFKC', text).lower()
    return re.sub(r'\s+', ' ', re.sub(r'[^\w\s]', '', text)).strip()


def distance(reference, actual):
    previous = list(range(len(actual) + 1))
    for i, left in enumerate(reference, 1):
        current = [i]
        for j, right in enumerate(actual, 1):
            current.append(min(current[-1] + 1, previous[j] + 1, previous[j-1] + (left != right)))
        previous = current
    return previous[-1]


def evaluate(rows):
    words = chars = word_errors = char_errors = intent_correct = intent_count = 0
    for row in rows:
        reference, actual = normalize(row['reference']), normalize(row['transcription'])
        if not reference:
            raise ValueError('Reference cannot be empty')
        words += len(reference.split()); chars += len(reference)
        word_errors += distance(reference.split(), actual.split())
        char_errors += distance(reference, actual)
        if row.get('expected_intent') and row.get('predicted_intent'):
            intent_count += 1
            intent_correct += row['expected_intent'] == row['predicted_intent']
    return {'samples': len(rows), 'wer': word_errors / words if words else None,
            'cer': char_errors / chars if chars else None,
            'intent_samples': intent_count,
            'intent_accuracy': intent_correct / intent_count if intent_count else None}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('results', type=Path, help='JSON list of human-verified results')
    args = parser.parse_args()
    print(json.dumps(evaluate(json.loads(args.results.read_text())), indent=2))
