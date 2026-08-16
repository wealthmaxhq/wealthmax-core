import { ErrorRequestHandler, RequestHandler } from 'express';

const apiContentSecurityPolicy = [
  "default-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join('; ');

export const secureResponseHeaders: RequestHandler = (req, res, next) => {
  res.setHeader('Content-Security-Policy', apiContentSecurityPolicy);
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  res.setHeader('Permissions-Policy', 'camera=(), geolocation=(), microphone=()');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');

  if (req.path.startsWith('/api/')) {
    res.setHeader('Cache-Control', 'no-store');
  }
  next();
};

type BodyParserError = SyntaxError & {
  status?: number;
  type?: string;
};

export const jsonParseErrorHandler: ErrorRequestHandler = (error, _req, res, next) => {
  const parseError = error as BodyParserError;
  if (parseError.type === 'entity.too.large') {
    res.status(413).json({ error: 'Request body is too large.' });
    return;
  }
  if (parseError.status === 400 && parseError instanceof SyntaxError) {
    res.status(400).json({ error: 'Request body must contain valid JSON.' });
    return;
  }
  next(error);
};
