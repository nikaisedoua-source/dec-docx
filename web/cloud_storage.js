(() => {
  let connection = null;
  window.decCloudSupported = typeof window.showDirectoryPicker === 'function';
  const database = () => new Promise((resolve, reject) => {
    const request = indexedDB.open('dec-docx-cloud', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('settings');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  async function settings(operation, value) {
    const db = await database();
    try {
      return await new Promise((resolve, reject) => {
        const tx = db.transaction('settings', operation === 'get' ? 'readonly' : 'readwrite');
        const store = tx.objectStore('settings');
        const request = operation === 'get' ? store.get('folder') : operation === 'put' ? store.put(value, 'folder') : store.delete('folder');
        tx.oncomplete = () => resolve(request.result);
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error || new Error('Enregistrement interrompu'));
      });
    } finally { db.close(); }
  }
  const state = () => connection ? {folder: connection.handle.name, provider: connection.provider} : null;
  async function library(write = false) {
    if (!connection) throw new Error('Choisissez un dossier synchronisé.');
    const opts = {mode: write ? 'readwrite' : 'read'};
    if (await connection.handle.queryPermission(opts) !== 'granted' &&
        await connection.handle.requestPermission(opts) !== 'granted') {
      throw new Error('Accès refusé. Autorisez le dossier pour continuer.');
    }
    return connection.handle.getDirectoryHandle('DEC DOCX', {create: write});
  }
  const segments = path => {
    const parts = path.split('/');
    if (parts.some(p => !p || p === '.' || p === '..' || /[\\:]/.test(p))) throw new Error('Chemin invalide');
    return parts;
  };
  const safe = value => {
    if (typeof value !== 'string' || segments(value).length !== 1) throw new Error('Nom invalide');
    return value;
  };
  const operations = {
    async restore() { connection = await settings('get') || null; return state(); },
    async choose(args) {
      try {
        const handle = await window.showDirectoryPicker({mode:'readwrite',id:'dec-docx-cloud'});
        const next = {handle, provider: args.provider};
        await settings('put', next);
        connection = next;
        return state();
      } catch (error) { if(error.name === 'AbortError') return state(); throw error; }
    },
    async disconnect() { await settings('delete'); connection = null; return null; },
    async save(args, bytes) {
      let dir = await library(true);
      for (const name of [safe(args.language), safe(args.person)]) dir = await dir.getDirectoryHandle(name,{create:true});
      const name = `${safe(args.name)}-${Date.now()}-${crypto.randomUUID().slice(0,8)}.docx`;
      const handle = await dir.getFileHandle(name, {create:true});
      const stream = await handle.createWritable();
      try { await stream.write(bytes); await stream.close(); }
      catch (error) { await stream.abort().catch(()=>{}); throw error; }
      return `${args.language}/${args.person}/${name}`;
    },
    async list() {
      let root;
      try { root = await library(); }
      catch(error) { if(error.name === 'NotFoundError') return []; throw error; }
      const files = [];
      async function visit(dir, prefix = '', depth = 0) {
        for await (const [name, handle] of dir.entries()) {
          if (handle.kind === 'directory' && depth < 2) await visit(handle,`${prefix}${name}/`,depth+1);
          else if(handle.kind === 'file' && name.toLowerCase().endsWith('.docx')) {
            const file = await handle.getFile();
            files.push({path:prefix+name,size:file.size,modified:file.lastModified});
          }
        }
      }
      await visit(root);
      return files.sort((a,b)=>b.modified-a.modified);
    },
  };
  window.decCloudCall = async (method, json, bytes) => {
    if (!Object.hasOwn(operations, method)) throw new Error('Action inconnue');
    return JSON.stringify(await operations[method](JSON.parse(json), bytes));
  };
  window.decCloudRead = async path => {
    const parts = segments(path);
    let dir = await library();
    for (const part of parts.slice(0,-1)) dir = await dir.getDirectoryHandle(part);
    const file = await (await dir.getFileHandle(parts.at(-1))).getFile();
    return new Uint8Array(await file.arrayBuffer());
  };
})();
