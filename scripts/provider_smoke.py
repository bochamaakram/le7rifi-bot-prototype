"""Explicit, billable end-to-end backend smoke test, never imported by pytest."""
import argparse
import os
import sys
import httpx

parser = argparse.ArgumentParser()
parser.add_argument('--allow-paid', action='store_true')
parser.add_argument('--base-url', default='http://localhost:8000')
parser.add_argument('--audio', required=True, help='Real Darija WAV recording, max 60 seconds')
parser.add_argument('--output', default='/tmp/le7rayfi-answer.mp3')
args = parser.parse_args()
if not args.allow_paid:
    parser.error('Pass --allow-paid to authorize billable provider calls')
token = os.environ.get('SMOKE_ACCESS_TOKEN')
if not token:
    sys.exit('Set SMOKE_ACCESS_TOKEN; do not put credentials in command arguments')
with httpx.Client(base_url=args.base_url, headers={'Authorization': f'Bearer {token}'}, timeout=150) as client:
    with open(args.audio, 'rb') as audio:
        response = client.post('/api/v1/speech/transcribe', files={'file': ('sample.wav', audio, 'audio/wav')})
    response.raise_for_status()
    text = response.json()['text']
    print('Review transcription:', text)
    text = input('Correct text, or Enter to confirm: ').strip() or text
    conversation = client.post('/api/v1/conversations'); conversation.raise_for_status()
    response = client.post('/api/v1/chat/messages', json={'conversation_id': conversation.json()['id'],
        'text': text, 'speech': True, 'script': 'arabic'})
    response.raise_for_status()
    result = response.json()
    print(result['answer']['text'])
    if result['audio_base64']:
        import base64
        from pathlib import Path
        Path(args.output).write_bytes(base64.b64decode(result['audio_base64']))
        print('Speech saved to', args.output)
    else:
        sys.exit('Text worked; TTS failed: ' + str(result['speech_error']))
