const appUrl = "https://nikaisedoua-source.github.io/dec-docx/";
const status = document.getElementById("status");

async function openApp() {
  await chrome.tabs.create({ url: appUrl });
}

async function copySelection() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || tab.id == null) throw new Error("Onglet actif introuvable.");
  const [{ result = "" } = {}] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => window.getSelection()?.toString().trim() || "",
  });
  if (!result) throw new Error("Sélectionne d’abord un texte sur la page.");
  await navigator.clipboard.writeText(result);
  status.textContent = "Sélection copiée. Colle-la dans DEC DOCX.";
  await openApp();
}

document.getElementById("selection").addEventListener("click", () => {
  copySelection().catch((error) => { status.textContent = error.message; });
});
document.getElementById("open").addEventListener("click", () => {
  openApp().catch((error) => { status.textContent = error.message; });
});
