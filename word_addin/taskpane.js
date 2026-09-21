/* global Office, Word */
const appUrl = "https://nikaisedoua-source.github.io/dec-docx/";

function setStatus(message) {
  document.getElementById("status").textContent = message;
}

async function readSelection() {
  await Word.run(async (context) => {
    const range = context.document.getSelection();
    range.load("text");
    await context.sync();
    document.getElementById("selection").value = range.text.trim();
    setStatus("Sélection récupérée depuis Word.");
  });
}

async function insertSelection() {
  const text = document.getElementById("selection").value.trim();
  if (!text) {
    setStatus("Ajoute ou récupère un texte avant de le réinsérer.");
    return;
  }
  await Word.run(async (context) => {
    context.document.getSelection().insertText(text, Word.InsertLocation.replace);
    await context.sync();
    setStatus("Texte réinséré dans Word.");
  });
}

Office.onReady(() => {
  document.getElementById("read").addEventListener("click", () => readSelection().catch((error) => setStatus(error.message)));
  document.getElementById("insert").addEventListener("click", () => insertSelection().catch((error) => setStatus(error.message)));
  document.getElementById("open-app").addEventListener("click", () => window.open(appUrl, "_blank", "noopener"));
});
