# Darija speech evaluation

No real speech-quality benchmark has been run. Default provider/model/voice choices are configurable starting points, not a claim of native Darija fluency or superiority. Generic Arabic voices may pronounce Darija poorly.

Use `evaluation/manifest.example.json` as a schema example. The referenced WAV is intentionally absent: record consenting native speakers and manually verify reference transcriptions. Keep private recordings outside Git. Include quiet/noisy workshops, different regions/professions, Arabic/Latin Darija, Arabizi, French mixing, MSA mixing, tool/service vocabulary, silence and cancellation. References must describe the actual recording, not a synthetic expected result.

Run STT using the configured adapter, preserving sample ID, provider/model/version, duration, actual transcription, expected/predicted intent and category. The harness consumes JSON rows with `reference` and actual `transcription`; optional expected/predicted intent enables intent accuracy:

```sh
python evaluation/evaluate.py /path/to/verified-results.json
python -m unittest discover -s evaluation -p test_evaluate.py -v
```

WER and CER are aggregate edit errors divided by aggregate reference words/characters. Normalization uses Unicode NFKC, lowercasing, punctuation removal and whitespace folding; it does not translate Arabizi or automatically align alternative Darija spellings. Report the normalization policy with results. Empty corpora yield null metrics, never a fabricated success. Intent accuracy requires an independently labeled actual prediction; the harness does not invent a classifier.

For TTS, have native reviewers rate each actual audio output for intelligibility, Darija naturalness, pronunciation, usefulness and code-switching on a documented 1–5 scale. Store reviewer consent/pseudonym, sample ID, actual voice/model and notes under `native_speaker_tts_ratings`. Compare multiple speakers/voices only on the same corpus. Publish sample counts and variation, not just averages. Automated tests exercise pipeline mechanics; human review establishes speech quality.
