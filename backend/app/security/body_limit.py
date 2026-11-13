from starlette.responses import JSONResponse


class BodyLimitMiddleware:
    """Bound the entire streamed request before multipart parsing/spooling."""
    def __init__(self, app, limit=5_000_000):
        self.app, self.limit = app, limit

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        chunks, total = [], 0
        while True:
            message = await receive()
            if message['type'] == 'http.disconnect':
                return
            body = message.get('body', b'')
            total += len(body)
            if total > self.limit:
                response = JSONResponse({'error': 'request_too_large'}, status_code=413)
                return await response(scope, receive, send)
            chunks.append(body)
            if not message.get('more_body', False):
                break
        delivered = False

        async def replay():
            nonlocal delivered
            if delivered:
                return await receive()
            delivered = True
            return {'type': 'http.request', 'body': b''.join(chunks), 'more_body': False}
        await self.app(scope, replay, send)
