# Node Backend with Keycloak Auth and WebSocket Quiz

- Auth endpoints remain in `server.js`.
- Quiz REST API is under `/api`.
- WebSocket namespace uses default Socket.IO namespace.

## REST

- GET `/api/questions` — list all questions
- POST `/api/questions` — body: `{ text, options: [4 strings], answerIndex: number }`
- DELETE `/api/questions/:id`

## WebSocket events

- Client -> Server: `student:join` `{ name }`
- Server -> Client: `student:questions` `[question]` (shuffled)
- Client -> Server: `student:answer` `{ name, questionId, selectedOptionId, isCorrect }`
- Server -> All: `score:update` `{ name, correct, incorrect }`

> Note: This uses in-memory storage. Replace with a database for persistence.
