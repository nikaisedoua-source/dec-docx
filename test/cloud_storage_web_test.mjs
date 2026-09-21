import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';

class Directory {
  constructor(name) { this.name=name; this.kind='directory'; this.items=new Map(); this.permission='granted'; }
  async queryPermission(){return this.permission;}
  async requestPermission(){return this.permission;}
  async getDirectoryHandle(name,{create=false}={}) {
    if(!this.items.has(name) && create) this.items.set(name,new Directory(name));
    if(!this.items.has(name)) throw new DOMException('Missing','NotFoundError');
    return this.items.get(name);
  }
  async getFileHandle(name,{create=false}={}) {
    if(!this.items.has(name) && create) {
      const item={kind:'file',bytes:new Uint8Array(),modified:Date.now()};
      item.getFile=async()=>({size:item.bytes.length,lastModified:item.modified,arrayBuffer:async()=>item.bytes.slice().buffer});
      item.createWritable=async()=>({write:async bytes=>{item.bytes=bytes.slice();},close:async()=>{},abort:async()=>{}});
      this.items.set(name,item);
    }
    if(!this.items.has(name)) throw new DOMException('Missing','NotFoundError');
    return this.items.get(name);
  }
  async *entries(){yield* this.items.entries();}
}
function setup() {
  const values=new Map();
  const root=new Directory('Google Drive');
  const indexedDB={open:()=>{
    const request={};
    request.result={close(){},transaction(){
      const tx={objectStore:()=>({
        get(key){const r={result:values.get(key)};queueMicrotask(()=>tx.oncomplete());return r;},
        put(value,key){values.set(key,value);const r={result:key};queueMicrotask(()=>tx.oncomplete());return r;},
        delete(key){values.delete(key);const r={};queueMicrotask(()=>tx.oncomplete());return r;},
      })};return tx;
    }};
    queueMicrotask(()=>request.onsuccess());return request;
  }};
  const window={showDirectoryPicker:async()=>root};
  const context=vm.createContext({window,indexedDB,crypto:webcrypto,Uint8Array,DOMException,console});
  const script=fs.readFileSync(new URL('../web/cloud_storage.js',import.meta.url),'utf8');
  const reload=()=>vm.runInContext(script,context);
  reload();
  const call=async(method,args={},bytes=new Uint8Array())=>JSON.parse(await window.decCloudCall(method,JSON.stringify(args),bytes));
  return {root,window,call,reload};
}

test('web folder persistence, versioning, retrieval and disconnect preserve documents',async()=>{
  const {call,window,reload}=setup();
  await call('choose',{provider:'Google Drive'});
  const bytes=new Uint8Array([80,75,3,4,12]);
  const args={language:'中文',person:'Groupe A',name:'Kacou 182'};
  const a=await call('save',args,bytes), b=await call('save',args,bytes);
  assert.notEqual(a,b);
  assert.equal((await call('list')).length,2);
  assert.deepEqual(await window.decCloudRead(a),bytes);
  reload();
  const restored=await call('restore');
  assert.equal(restored.provider,'Google Drive');
  assert.equal(restored.permission,'granted');
  assert.equal((await call('list')).length,2);
  await assert.rejects(window.decCloudRead('../private.txt'),/Chemin invalide/);
  await call('disconnect');
  assert.equal(await call('restore'),null);
  await call('choose',{provider:'Google Drive'});
  assert.equal((await call('list')).length,2);
});

test('local mode is remembered without pretending a cloud folder is connected',async()=>{
  const {call,reload}=setup();
  assert.deepEqual(await call('chooseLocal'),{mode:'local',permission:'granted'});
  reload();
  assert.deepEqual(await call('restore'),{mode:'local',permission:'granted'});
  await assert.rejects(
    call('save',{language:'fr',person:'a',name:'doc'},new Uint8Array([1])),
    /Choisissez un dossier synchronisé/,
  );
});

test('refused permissions and cancelled selection never pretend a save succeeded',async()=>{
  const {root,call,window}=setup();
  window.showDirectoryPicker=async()=>{throw new DOMException('Cancelled','AbortError');};
  assert.equal(await call('choose',{provider:'MEGA'}),null);
  window.showDirectoryPicker=async()=>root;
  await call('choose',{provider:'OneDrive'});
  root.permission='denied';
  await assert.rejects(call('save',{language:'fr',person:'a',name:'doc'},new Uint8Array([1])),/Accès refusé/);
  assert.equal(root.items.size,0);
});
