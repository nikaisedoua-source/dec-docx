(() => {
  const open = () => new Promise((resolve, reject) => {
    const request = indexedDB.open('dec-docx-drafts', 1);
    request.onupgradeneeded = () => {
      request.result.createObjectStore('revisions', {keyPath: 'id'});
      request.result.createObjectStore('metadata', {keyPath: 'id'});
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('Fermez les autres onglets pour ouvrir les brouillons.'));
  });
  window.decDraftCall = async (method, payload) => {
    const value = JSON.parse(payload), db = await open();
    try {
      return JSON.stringify(await new Promise((resolve, reject) => {
        const tx = db.transaction(['revisions','metadata'], method === 'save' ? 'readwrite' : 'readonly');
        let result = null;
        tx.oncomplete = () => resolve(result);
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error || new Error('Sauvegarde interrompue'));
        if (method === 'save') {
          if (value.schema !== 1 || !value.id || !value.data) { tx.abort(); return; }
          tx.objectStore('revisions').add(value);
          tx.objectStore('metadata').add({id:value.id, title:value.title, savedAt:value.savedAt});
        } else if (method === 'read') {
          const request = tx.objectStore('revisions').get(value);
          request.onsuccess = () => { result = request.result; if (!result || result.schema !== 1) tx.abort(); };
        } else if (method === 'history') {
          result = [];
          const request = tx.objectStore('metadata').openCursor(null, 'prev');
          request.onsuccess = () => { const cursor = request.result; if (cursor && result.length < 50) { result.push(cursor.value); cursor.continue(); } };
        } else { tx.abort(); }
      }));
    } finally { db.close(); }
  };
})();
