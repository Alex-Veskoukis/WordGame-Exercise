# ============================================
# Mock API #2 - Custom Hints and Achievements
# ============================================
# This is a custom-built REST API using json-server
# Provides hints and achievement data
# ============================================

FROM node:18-alpine

LABEL maintainer="Word Game Team"
LABEL description="Mock REST API for hints and achievements"

# Set working directory
WORKDIR /app

# Install json-server globally
RUN npm install -g json-server@0.17.4

# Copy the database file
COPY db.json /app/db.json

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/hints', (r) => {if(r.statusCode !== 200) throw new Error()})"

# Run json-server
# --watch: Reload on file changes
# --host: Allow external connections
# --port: Port to listen on
CMD ["json-server", "--watch", "/app/db.json", "--host", "0.0.0.0", "--port", "3001"]

# ============================================
# Build instructions:
#   docker build -t word-game-mock-api .
#
# Run instructions:
#   docker run -p 3001:3001 word-game-mock-api
#
# Access:
#   http://localhost:3001/hints
#   http://localhost:3001/achievements
#   http://localhost:3001/powerups
# ============================================
