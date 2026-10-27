(() => {
  const params = new URLSearchParams(window.location.search);
  const bridgeMode = params.get("officeBridge") === "1";
  let selection = null;
  let resolveSelection;
  let resolveTransfer;
  const selectionPromise = new Promise((resolve) => {
    resolveSelection = resolve;
  });
  window.setTimeout(() => resolveSelection(""), 30000);

  window.decOfficeBridgeActive = () => bridgeMode;
  window.decOfficeReceiveSelection = () => selection === null
    ? selectionPromise
    : Promise.resolve(selection);
  window.decOfficeSendDocx = (base64, fileName) => new Promise((resolve) => {
    if (!bridgeMode || !window.Office?.context?.ui) {
      resolve("unavailable");
      return;
    }
    resolveTransfer = resolve;
    try {
      Office.context.ui.messageParent(JSON.stringify({
        type: "docx",
        base64,
        fileName,
      }));
    } catch (error) {
      resolveTransfer = null;
      resolve(`error: ${error.message || error}`);
    }
    window.setTimeout(() => {
      if (!resolveTransfer) return;
      resolveTransfer("timeout");
      resolveTransfer = null;
    }, 30000);
  });

  if (!bridgeMode) return;

  const officeScript = document.createElement("script");
  officeScript.src = "https://appsforoffice.microsoft.com/lib/1/hosted/office.js";
  officeScript.onload = () => Office.onReady(() => {
    Office.context.ui.addHandlerAsync(
      Office.EventType.DialogParentMessageReceived,
      (event) => {
        let message;
        try {
          message = JSON.parse(event.message);
        } catch (_) {
          return;
        }
        if (message.type === "selection") {
          selection = typeof message.text === "string" ? message.text : "";
          resolveSelection(selection);
        } else if (message.type === "inserted" || message.type === "error") {
          if (resolveTransfer) {
            resolveTransfer(message.type === "inserted"
              ? "inserted"
              : `error: ${message.message || "Word insertion failed"}`);
            resolveTransfer = null;
          }
        }
      },
      (result) => {
        if (result.status === Office.AsyncResultStatus.Succeeded) {
          Office.context.ui.messageParent(JSON.stringify({ type: "ready" }));
        } else {
          resolveSelection("");
        }
      },
    );
  });
  officeScript.onerror = () => resolveSelection("");
  document.head.appendChild(officeScript);
})();
