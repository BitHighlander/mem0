/**
 * Authentication middleware for Mem0 API
 * 
 * This middleware checks for a valid API key in the request headers
 * and rejects unauthorized requests.
 */

const apiKeyMiddleware = (req, res, next) => {
  // Get API key from environment variable
  const validApiKey = process.env.API_KEY;
  
  // Skip auth check if no API key is configured
  if (!validApiKey || validApiKey === '') {
    console.warn('WARNING: No API key configured. Running in insecure mode.');
    return next();
  }
  
  // Get API key from request header
  const apiKey = req.headers['x-api-key'];
  
  // Check if API key is valid
  if (!apiKey || apiKey !== validApiKey) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or missing API key'
    });
  }
  
  // API key is valid, proceed to next middleware
  next();
};

module.exports = apiKeyMiddleware;
