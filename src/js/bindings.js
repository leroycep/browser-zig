let next_handle = 4000;
let handles = {};
let child_handles = {};

export function makeHandle(obj, parentHandle) {
  const handle = next_handle;
  next_handle += 4;
  handles[handle] = obj;

  if (parentHandle) {
    if (child_handles[parentHandle]) {
      child_handles[parentHandle].push(handle);
    } else {
      child_handles[parentHandle] = [handle];
    }
  }

  return handle;
}

export function freeHandle(handle) {
  let handles_to_free = [handle];
  let to_free_index = 0;
  while (to_free_index < handles_to_free.length) {
    const h = handles_to_free[to_free_index];
    if (child_handles[h]) {
      for (let child of child_handles[h]) {
        handles_to_free.push(child);
      }
    }
    delete child_handles[h];
    to_free_index += 1;
  }
  for (let h of handles_to_free) {
    delete handles[h];
  }
}

export function getWASMImports(getInstanceExports, mixins) {
  let getMem = () => getInstanceExports().memory;

  const text_decoder = new TextDecoder();
  function readStr(ptr, len) {
    const array = new Uint8Array(getMem().buffer, ptr, len);
    return text_decoder.decode(array);
  }
  const text_encoder = new TextEncoder();

  function writeStr(ptr, len, text) {
    const buf = new Uint8Array(getMem().buffer, ptr, len);

    const res = text_encoder.encodeInto(text, buf);

    if (res.read < text.length) {
      return -res.written;
    }

    return res.written;
  }

  const METHOD = {
    GET: 1,
    POST: 2,
  };

  const ERROR_UNKNOWN = 1;
  const ERROR_OUT_OF_MEMORY = 10;

  let console_string = "";

  return {
    env: {
      ...(mixins.env ? mixins.env : {}),

      handle_free: freeHandle,
      handle_clone(handle) {
        return makeHandle(handles[handle]);
      },

      console_log: (ptr, len) => {
        console.log(readStr(ptr, len));
      },
      console_log_write: (ptr, len) => {
        console_string = console_string.concat(readStr(ptr, len));
      },
      console_log_flush: (ptr, len) => {
        console.log(console_string);
        console_string = "";
      },

      event_fetch_request: (fetchHandle) => {
        const fetch_event = handles[fetchHandle];
        return makeHandle(fetch_event.request, fetchHandle);
      },

      event_fetch_respond_with: (handle, responseHandle) => {
        const fetch_event = handles[handle];
        const response = handles[responseHandle];
        fetch_event.respondWith(response);
      },

      request_method: (handle) => {
        const request = handles[handle];
        switch (request.method) {
          case "GET":
            return METHOD.GET;
          case "POST":
            return METHOD.POST;
          default:
            return -1;
        }
      },

      request_url: (handle, bufPtr, bufLen) => {
        const request = handles[handle];

        const buf = new Uint8Array(getMem().buffer, bufPtr, bufLen);

        const res = text_encoder.encodeInto(request.url, buf);

        if (res.read < request.url.length) {
          return -res.written;
        }

        return res.written;
      },

      request_referrer(requestHandle, bufPtr, bufLen) {
        const request = handles[requestHandle];

        const buf = new Uint8Array(getMem().buffer, bufPtr, bufLen);

        const res = text_encoder.encodeInto(request.referrer, buf);

        if (res.read < request.referrer.length) {
          return -res.written;
        }

        return res.written;
      },

      request_headers(requestHandle) {
        const request = handles[requestHandle];
        return makeHandle(request.headers);
      },

      request_body_open: (handle) => {
        //console.log("request body open", handle);
        //const request = handles[handle];
        //console.log(request);
        //const reader = request.body.getReader();
        //return makeHandle(reader, handle);
        return handle;
      },

      response_new: (blobHandle, initHandle) => {
        const blob = handles[blobHandle];
        const init = handles[initHandle];
        return makeHandle(new Response(blob, init));
      },

      response_free: freeHandle,

      readable_stream_read: (
        handle,
        bufPtr,
        bufLen,
        resumeReadCb,
        userdata
      ) => {
        const request = handles[handle];
        request.arrayBuffer().then((arrayBuffer) => {
          const buf = new Uint8Array(getMem().buffer, bufPtr, bufLen);
          buf.set(new Uint8Array(arrayBuffer));

          const cb_fn =
            getInstanceExports().__indirect_function_table.get(resumeReadCb);

          cb_fn(userdata, true, arrayBuffer.byteLength);
        });
      },

      set_timeout: (cbFnIndex, duration_ms) => {
        setTimeout(() => {
          const cb_fn =
            getInstanceExports.__indirect_function_table.get(cbFnIndex);
          cb_fn();
        }, duration_ms);
      },

      blob_new: (mimeTypePtr, mimeTypeLen, bodyPtr, bodyLen) => {
        const mime_type = readStr(mimeTypePtr, mimeTypeLen);

        const body = new Uint8Array(getMem().buffer, bodyPtr, bodyLen);

        return makeHandle(new Blob([body], { type: mime_type }));
      },

      blob_free: (handle) => {
        freeHandle(handle);
      },

      array_new() {
        return makeHandle([]);
      },

      array_push_str(handle, ptr, len) {
        const array = handles[handle];
        array.push(readStr(ptr, len));
      },

      array_free: (handle) => {
        freeHandle(handle);
      },

      object_new() {
        return makeHandle({});
      },

      object_free: freeHandle,

      object_set_bool(handle, namePtr, nameLen, value) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        object[name] = value !== 0;
      },

      object_set_uint32(handle, namePtr, nameLen, value) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        object[name] = value;
      },

      object_set_str(handle, namePtr, nameLen, valPtr, valLen) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        object[name] = readStr(valPtr, valLen);
      },

      object_set_object(handle, namePtr, nameLen, objHandle) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        object[name] = handles[objHandle];
      },

      object_set_json(handle, namePtr, nameLen, jsonPtr, jsonLen) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        object[name] = JSON.parse(readStr(jsonPtr, jsonLen));
      },

      object_get_bool(handle, namePtr, nameLen) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        return object[name];
      },

      object_get_str(handle, namePtr, nameLen, bufPtr, bufLen) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        return writeStr(bufPtr, bufLen, object[name]);
      },

      object_get_obj(handle, namePtr, nameLen) {
        const object = handles[handle];
        const name = readStr(namePtr, nameLen);
        return makeHandle(object[name], handle);
      },

      object_as_str(handle, bufPtr, bufLen) {
        const object = handles[handle];
        return writeStr(bufPtr, bufLen, object);
      },

      object_as_i64(handle) {
        const object = handles[handle];
        console.log(object);
        return Number(object);
      },

      promise_new(resumeFn, cleanupFn, userdata) {
        return makeHandle(
          new Promise((resolve, reject) => {
            const resolverHandle = makeHandle({ resolve, reject });
            const resume =
              getInstanceExports().__indirect_function_table.get(resumeFn);
            resume(userdata, resolverHandle);
          }).finally(() => {
            const cleanup =
              getInstanceExports().__indirect_function_table.get(cleanupFn);
            cleanup(userdata);
          })
        );
      },

      promise_resolver_resolve_void(resolveHandle) {
        const { resolve } = handles[resolveHandle];
        resolve();
        freeHandle(resolveHandle);
      },

      promise_resolver_resolve_any(resolveHandle, anyHandle) {
        const { resolve } = handles[resolveHandle];
        const any = handles[anyHandle];
        resolve(any);
        freeHandle(resolveHandle);
      },

      promise_resolver_reject(rejectHandle, reasonPtr, reasonLen) {
        const { reject } = handles[rejectHandle];
        const reason = readStr(reasonPtr, reasonLen);
        reject(reason);
        freeHandle(rejectHandle);
      },

      headers_get(headersHandle, headerNamePtr, headerNameLen, bufPtr, bufLen) {
        const headers = handles[headersHandle];
        const header_name = readStr(headerNamePtr, headerNameLen);

        const buf = new Uint8Array(getMem().buffer, bufPtr, bufLen);

        const header = headers.get(header_name);

        if (header === null) {
          return 0;
        }

        const res = text_encoder.encodeInto(header, buf);

        if (res.read < header.length) {
          return -res.written;
        }

        return res.written;
      },

      date_now() {
        return BigInt(Date.now());
      },

      math_random() {
        return Math.random();
      },
    },

    indexeddb: {
      ...(mixins.indexeddb ? mixins.indexeddb : {}),

      indexeddb_open(namePtr, nameLen, version, callbacksPtr, userdata) {
        const name = readStr(namePtr, nameLen);

        const callbacks_dataview = new Uint32Array(
          getMem().buffer,
          callbacksPtr,
          4
        );
        const callbacks = {
          success: callbacks_dataview[0],
          upgradeneeded: callbacks_dataview[1],
          error: callbacks_dataview[2],
          blocked: callbacks_dataview[3],
        };

        let already_opened = false;

        const openRequest = self.indexedDB.open(name, version);
        openRequest.onsuccess = (event) => {
          if (already_opened) throw new Error("Already opened");
          already_opened = true;
          const success_cb = getInstanceExports().__indirect_function_table.get(
            callbacks.success
          );

          const db_handle = makeHandle(event.target.result);
          success_cb(userdata, db_handle);
        };
        openRequest.onupgradeneeded = (event) => {
          const upgrade_cb = getInstanceExports().__indirect_function_table.get(
            callbacks.upgradeneeded
          );

          const db_handle = makeHandle(event.target.result);
          upgrade_cb(userdata, db_handle);
          freeHandle(db_handle);
        };
        openRequest.onerror = (event) => {
          getInstanceExports().__indirect_function_table.get(callbacks.error)(
            userdata,
            0
          );
        };
        openRequest.onblocked = (event) => {
          getInstanceExports().__indirect_function_table.get(callbacks.blocked)(
            userdata
          );
        };
      },

      indexeddb_close(handle) {
        const db = handles[handle];
        db.close();
      },

      create_object_store(dbHandle, namePtr, nameLen, optionsPtr) {
        const db = handles[dbHandle];

        const name = readStr(namePtr, nameLen);

        const options_dataview = new Uint32Array(
          getMem().buffer,
          optionsPtr,
          3
        );
        const options = {
          keyPath: options_dataview[0]
            ? readStr(options_dataview[0], options_dataview[1])
            : null,
          autoIncrement: options_dataview[2] > 0,
        };

        console.log("createObjectStore", name, options);

        return makeHandle(db.createObjectStore(name, options), dbHandle);
      },

      indexeddb_transaction(dbHandle, storeNamesHandle, optionsPtr) {
        const db = handles[dbHandle];
        const storeNames = handles[storeNamesHandle];

        const int_to_mode = (integer) => {
          switch (integer) {
            case 0:
              return "readonly";
            case 1:
              return "readwrite";
          }
        };
        const int_to_durability = (integer) => {
          switch (integer) {
            case 0:
              return "default";
            case 1:
              return "strict";
            case 2:
              return "relaxed";
          }
        };

        const options_dataview = new Uint32Array(
          getMem().buffer,
          optionsPtr,
          3
        );
        const mode = int_to_mode(options_dataview[0]);
        const options = {
          durability: int_to_durability(options_dataview[1]),
        };

        return makeHandle(db.transaction(storeNames, mode, options), dbHandle);
      },

      transaction_abort(transactionHandle, namePtr, nameLen) {
        const transaction = handles[transactionHandle];
        transaction.abort();
      },

      transaction_object_store(transactionHandle, namePtr, nameLen) {
        const transaction = handles[transactionHandle];
        const name = readStr(namePtr, nameLen);

        return makeHandle(transaction.objectStore(name), transactionHandle);
      },

      object_store_add(objectStoreHandle, valueHandle) {
        const objectStore = handles[objectStoreHandle];
        const value = handles[valueHandle];
        objectStore.add(value);
      },

      object_store_add_json(objectStoreHandle, valJSONPtr, valJSONLen) {
        const objectStore = handles[objectStoreHandle];
        const value = JSON.parse(readStr(valJSONPtr, valJSONLen));
        objectStore.add(value);
      },

      object_store_put(objectStoreHandle, valueHandle) {
        const objectStore = handles[objectStoreHandle];
        const value = handles[valueHandle];
        objectStore.put(value);
      },

      object_store_get_json(
        objectStoreHandle,
        onsuccessFn,
        onerrorFn,
        userdata,
        keyJSONPtr,
        keyJSONLen,
        valBufPtr,
        valBufLen
      ) {
        const objectStore = handles[objectStoreHandle];

        const key = JSON.parse(readStr(keyJSONPtr, keyJSONLen));
        const valBuf = new Uint8Array(getMem().buffer, valBufPtr, valBufLen);
        const onsuccess =
          getInstanceExports().__indirect_function_table.get(onsuccessFn);
        const onerror =
          getInstanceExports().__indirect_function_table.get(onerrorFn);

        const req = objectStore.get(key);
        req.onsuccess = () => {
          const val_json = JSON.stringify(req.result);
          const encode_res = text_encoder.encodeInto(val_json, valBuf);
          if (
            encode_res.written == valBufLen &&
            encode_res.written < val_json.length
          ) {
            onerror(userdata, ERROR_OUT_OF_MEMORY);
            return;
          }
          onsuccess(userdata, encode_res.written);
        };
        req.onerror = (e) => {
          console.log(e);
          onerror(userdata, ERROR_UNKNOWN);
        };
      },

      object_store_get(
        objectStoreHandle,
        onsuccessFn,
        onerrorFn,
        userdata,
        keyJSONPtr,
        keyJSONLen
      ) {
        const objectStore = handles[objectStoreHandle];

        const keyJSON = readStr(keyJSONPtr, keyJSONLen);
        const key = JSON.parse(keyJSON);
        const onsuccess =
          getInstanceExports().__indirect_function_table.get(onsuccessFn);
        const onerror =
          getInstanceExports().__indirect_function_table.get(onerrorFn);

        const req = objectStore.get(key);
        req.onsuccess = () => {
          onsuccess(userdata, req.result ? makeHandle(req.result) : 0);
        };
        req.onerror = (e) => {
          console.log(e);
          onerror(userdata, ERROR_UNKNOWN);
        };
      },

      object_store_open_cursor(
        objectStoreHandle,
        queryHandle,
        directionInt,
        successCbIdx,
        userdata
      ) {
        object_store_open_cursor_fn(
          getInstanceExports(),
          false,
          objectStoreHandle,
          queryHandle,
          directionInt,
          successCbIdx,
          userdata
        );
      },

      object_store_open_key_cursor(
        objectStoreHandle,
        queryHandle,
        directionInt,
        successCbIdx,
        userdata
      ) {
        object_store_open_cursor_fn(
          getInstanceExports(),
          true,
          objectStoreHandle,
          queryHandle,
          directionInt,
          successCbIdx,
          userdata
        );
      },

      object_store_create_index(
        objectStoreHandle,
        namePtr,
        nameLen,
        keyPathPtr,
        keyPathLen,
        objJSONPtr,
        objJSONLen
      ) {
        const objectStore = handles[objectStoreHandle];
        const name = readStr(namePtr, nameLen);
        const keyPath = readStr(keyPathPtr, keyPathLen);

        const options = objJSONPtr
          ? JSON.parse(readStr(objJSONPtr, objJSONLen))
          : {};

        // TODO: Wrap in try/catch block
        return makeHandle(
          objectStore.createIndex(name, keyPath, options),
          objectStoreHandle
        );
      },

      cursor_continue(cursorHandle) {
        const cursor = handles[cursorHandle];
        freeHandle(cursorHandle);
        cursor.continue();
      },

      cursor_get_key_u32(cursorHandle) {
        return handles[cursorHandle].key;
      },
    },
  };
}

function object_store_open_cursor_fn(
  instanceExports,
  isKeyCursor,
  objectStoreHandle,
  queryHandle,
  directionInt,
  successCbIdx,
  userdata
) {
  const objectStore = handles[objectStoreHandle];
  const query = queryHandle === 0 ? handles[queryHandle] : null;

  const directionIntToString = (x) => {
    switch (x) {
      case 0:
        return "next";
      case 1:
        return "nextunique";
      case 2:
        return "prev";
      case 3:
        return "prevunique";
    }
  };
  const dir = directionIntToString(directionInt);

  const request = isKeyCursor
    ? objectStore.openKeyCursor(query, dir)
    : objectStore.openCursor(query, dir);

  request.onsuccess = (event) => {
    const cursor = event.target.result;
    const success_cb =
      instanceExports.__indirect_function_table.get(successCbIdx);
    if (cursor) {
      const cursor_handle = makeHandle(cursor);
      const key_handle = makeHandle(cursor.key, cursor_handle);
      const value_handle = cursor.value
        ? makeHandle(cursor.value, cursor_handle)
        : null;
      success_cb(userdata, key_handle, value_handle, cursor_handle);
    } else {
      success_cb(userdata, null, null, null);
    }
  };
}
