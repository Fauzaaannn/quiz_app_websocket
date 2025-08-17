const WebSocket = require("ws");
const { listQuestions, getQuestion } = require("../store/quizStore");

function setupQuizWebSocket(server) {
  const wss = new WebSocket.Server({ server, path: "/ws" });

  function wsBroadcast(type, payload) {
    const data = JSON.stringify({ type, payload });
    for (const client of wss.clients) {
      if (client.readyState === WebSocket.OPEN) client.send(data);
    }
  }

  wss.on("connection", (ws) => {
    ws.on("message", (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch (e) {
        return;
      }
      const { type, payload } = msg || {};
      if (type === "student:join") {
        const shuffled = [...listQuestions()].sort(() => Math.random() - 0.5); // mengacak pertanyaan
        ws.send(
          JSON.stringify({ type: "student:questions", payload: shuffled })
        );
        // mengirimkan pertanyaan yang sudah diacak ke mahasiswa
      } else if (type === "student:answer") {
        // mahasiswa menjawab
        const { name, questionId, selectedOptionId } = payload || {}; // mengambil data dari payload
        const q = getQuestion(questionId); // mengambil pertanyaan berdasarkan ID
        if (!q) return; // jika pertanyaan tidak ditemukan
        const isCorrect = q.answerId === selectedOptionId; // memeriksa apakah jawaban benar
        wsBroadcast("score:update", {
          name,
          correct: isCorrect ? 1 : 0,
          incorrect: isCorrect ? 0 : 1,
        });
        // mengirimkan update skor ke semua klien
      }
    });
  });

  // Optional: return wsBroadcast if needed for event bus
  return { emit: wsBroadcast };
}

module.exports = { setupQuizWebSocket };
