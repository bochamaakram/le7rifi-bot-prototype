import unittest
from evaluate import evaluate

class MetricsTests(unittest.TestCase):
    def test_known_errors_and_intent(self):
        result = evaluate([{'reference': 'bghit video', 'transcription': 'bghit script',
                            'expected_intent': 'video', 'predicted_intent': 'video'}])
        self.assertEqual(result['wer'], 0.5)
        self.assertEqual(result['intent_accuracy'], 1)

    def test_empty_results_are_not_claimed_successful(self):
        self.assertIsNone(evaluate([])['wer'])
        self.assertIsNone(evaluate([])['intent_accuracy'])
