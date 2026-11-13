import unittest
from app.security.body_limit import BodyLimitMiddleware


class BodyLimitTests(unittest.IsolatedAsyncioTestCase):
    async def request(self, parts, limit):
        seen, sent = [], []
        async def app(scope, receive, send):
            seen.append((await receive())['body'])
            await send({'type': 'http.response.start', 'status': 204, 'headers': []})
            await send({'type': 'http.response.body', 'body': b''})
        queue = [{'type': 'http.request', 'body': part, 'more_body': i < len(parts)-1}
                 for i, part in enumerate(parts)]
        async def receive():
            return queue.pop(0) if queue else {'type': 'http.disconnect'}
        async def send(message):
            sent.append(message)
        await BodyLimitMiddleware(app, limit)({'type': 'http', 'method': 'POST'}, receive, send)
        return seen, sent

    async def test_chunked_overflow_never_reaches_parser(self):
        seen, sent = await self.request([b'abc', b'def'], 5)
        self.assertEqual(seen, [])
        self.assertEqual(sent[0]['status'], 413)

    async def test_bounded_body_is_replayed_exactly_once(self):
        seen, sent = await self.request([b'ab', b'cd'], 5)
        self.assertEqual(seen, [b'abcd'])
        self.assertEqual(sent[0]['status'], 204)
