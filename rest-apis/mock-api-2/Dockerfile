
FROM node:18-alpine

LABEL maintainer="Word Game Team"
LABEL description="REST API for hints and achievements"

WORKDIR /app

RUN npm install -g json-server@0.17.4

COPY db.json /app/db.json

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/hints', (r) => {if(r.statusCode !== 200) throw new Error()})"

CMD ["json-server", "--watch", "/app/db.json", "--host", "0.0.0.0", "--port", "3001"]
