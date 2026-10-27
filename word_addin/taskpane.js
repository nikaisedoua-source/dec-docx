/* global Office, Word */
const appUrl = "https://nikaisedoua-source.github.io/dec-docx/";
let dialog;
let selectedText = "";
let openingDialog = false;
let button;

function setStatus(message) {
  document.getElementById("status").textContent = message;
}

function sendToDialog(message) {
  if (!dialog) return;
  try {
    dialog.messageChild(JSON.stringify(message));
  } catch (error) {
    setStatus(`Connexion à DEC DOCX interrompue : ${error.message || error}`);
  }
}

async function insertDocx(message) {
  if (typeof message.base64 !== "string" || !message.base64) {
    sendToDialog({ type: "error", message: "Le document DOCX est vide." });
    setStatus("Le document généré est vide.");
    return;
  }

  try {
    if (!Office.context.requirements.isSetSupported("WordApi", "1.1")) {
      throw new Error("Cette version de Word ne prend pas en charge l’insertion directe. Télécharge le DOCX depuis DEC DOCX.");
    }
    const bytes = atob(message.base64).length;
    if (bytes > 4 * 1024 * 1024) {
      throw new Error("Word limite l’insertion directe à 4 Mo. Télécharge le DOCX depuis DEC DOCX.");
    }
    await Word.run(async (context) => {
      context.document.getSelection().insertFileFromBase64(
        message.base64,
        Word.InsertLocation.replace,
      );
      await context.sync();
    });
    setStatus("Document formaté inséré dans Word à la place de la sélection.");
    sendToDialog({ type: "inserted" });
    window.setTimeout(() => {
      dialog?.close();
      dialog = undefined;
    }, 500);
  } catch (error) {
    const details = error.message || String(error);
    setStatus(`Insertion impossible : ${details}`);
    sendToDialog({ type: "error", message: details });
  }
}

function handleDialogMessage(event) {
  let message;
  try {
    message = JSON.parse(event.message);
  } catch (_) {
    setStatus("Message reçu de DEC DOCX illisible.");
    return;
  }

  if (message.type === "ready") {
    sendToDialog({ type: "selection", text: selectedText });
  } else if (message.type === "docx") {
    void insertDocx(message);
  }
}

async function openDecDocx() {
  if (openingDialog || dialog) {
    setStatus("DEC DOCX est déjà ouvert. Termine ou ferme cette fenêtre avant d’en ouvrir une autre.");
    return;
  }
  if (!Office.context.requirements.isSetSupported("DialogApi", "1.2")) {
    setStatus("Cette version de Word ne prend pas en charge le transfert direct. Télécharge le DOCX depuis DEC DOCX.");
    return;
  }
  if (!Office.context.requirements.isSetSupported("WordApi", "1.1")) {
    setStatus("Cette version de Word ne prend pas en charge l’insertion directe. Télécharge le DOCX depuis DEC DOCX.");
    return;
  }

  openingDialog = true;
  if (button) button.disabled = true;
  try {
    await Word.run(async (context) => {
      const range = context.document.getSelection();
      range.load("text");
      await context.sync();
      selectedText = range.text;
    });
    if (!selectedText.trim()) {
      setStatus("Sélectionne les versets à traiter dans Word, puis réessaie.");
      return;
    }

    const url = new URL(appUrl);
    url.searchParams.set("officeBridge", "1");
    Office.context.ui.displayDialogAsync(
      url.href,
      { height: 90, width: 90 },
      (result) => {
        if (result.status !== Office.AsyncResultStatus.Succeeded) {
          setStatus(`Impossible d’ouvrir DEC DOCX : ${result.error.message}`);
          openingDialog = false;
          if (button) button.disabled = false;
          return;
        }
        dialog = result.value;
        openingDialog = false;
        if (button) button.disabled = false;
        dialog.addEventHandler(Office.EventType.DialogMessageReceived, handleDialogMessage);
        dialog.addEventHandler(Office.EventType.DialogEventReceived, (event) => {
          dialog = undefined;
          selectedText = "";
          if (button) button.disabled = false;
          if (event.error !== 12006) {
            setStatus(`La fenêtre DEC DOCX s’est fermée avec le code ${event.error}. Le fichier reste disponible au téléchargement.`);
          }
        });
        setStatus("DEC DOCX est ouvert. Génère le document pour remplacer la sélection Word.");
      },
    );
  } catch (error) {
    setStatus(`Lecture de la sélection impossible : ${error.message || error}`);
  } finally {
    openingDialog = false;
    if (button) button.disabled = false;
  }
}

Office.onReady(() => {
  if (Office.context.host !== Office.HostType.Word) {
    setStatus("Ouvre ce complément dans Microsoft Word.");
    return;
  }
  button = document.getElementById("open-app");
  button.addEventListener("click", () => {
    void openDecDocx();
  });
  setStatus("Sélectionne un ou plusieurs versets dans ton document Word.");
});
