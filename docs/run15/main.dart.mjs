// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: x0 => new Int16Array(x0),
      AC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      AD: x0 => x0.screen,
      AE: x0 => new ResizeObserver(x0),
      AF: x0 => x0.identifier,
      AG: (x0,x1) => x0.querySelectorAll(x1),
      AH: x0 => x0.clipboard,
      AI: (x0,x1,x2) => x0.insertBefore(x1,x2),
      AJ: x0 => x0.duration,
      AK: (x0,x1) => x0.key(x1),
      B: s => printToConsole(s),
      BB: x0 => new Uint16Array(x0),
      BC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      BD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      BE: (x0,x1) => x0.getPropertyValue(x1),
      BF: x0 => x0.touches,
      BG: (x0,x1) => x0.requestAnimationFrame(x1),
      BH: (x0,x1) => x0.writeText(x1),
      BI: x0 => x0.id,
      BJ: x0 => x0.image,
      BK: x0 => x0.length,
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      CC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      CD: x0 => x0.tabIndex,
      CE: x0 => globalThis.parseFloat(x0),
      CF: x0 => x0.pressure,
      CG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CH: x0 => x0.unlock(),
      CI: x0 => x0.offsetHeight,
      CJ: x0 => x0.close(),
      CK: (x0,x1,x2) => x0.setItem(x1,x2),
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: x0 => new Int32Array(x0),
      DC: (x0,x1) => x0.querySelector(x1),
      DD: (x0,x1) => x0.contains(x1),
      DE: (x0,x1) => x0.getComputedStyle(x1),
      DF: x0 => x0.tiltY,
      DG: x0 => x0.now(),
      DH: (x0,x1) => x0.lock(x1),
      DI: x0 => x0.offsetWidth,
      DJ: () => globalThis.window.ImageDecoder,
      DK: (x0,x1) => x0.canShare(x1),
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      EC: (x0,x1) => x0.item(x1),
      ED: x0 => x0.activeElement,
      EE: x0 => x0.documentElement,
      EF: x0 => x0.tiltX,
      EG: x0 => x0.performance,
      EH: x0 => x0.orientation,
      EI: x0 => x0.stopPropagation(),
      EJ: (x0,x1) => x0.item(x1),
      EK: (x0,x1) => x0.share(x1),
      F: () => new Error().stack,
      FB: x0 => new Uint32Array(x0),
      FC: x0 => x0.length,
      FD: x0 => x0.parentNode,
      FE: x0 => x0.computedStyleMap(),
      FF: x0 => x0.pointerType,
      FG: (d, digits) => d.toFixed(digits),
      FH: (x0,x1) => x0.querySelector(x1),
      FI: x0 => x0.disabled,
      FJ: (x0,x1) => x0.removeChild(x1),
      FK: x0 => x0.message,
      G: s => JSON.stringify(s),
      GB: x0 => new Float32Array(x0),
      GC: (x0,x1) => x0.querySelectorAll(x1),
      GD: x0 => x0.tagName,
      GE: (x0,x1) => x0.get(x1),
      GF: x0 => x0.pointerId,
      GG: x0 => x0.maxHeight,
      GH: (x0,x1) => { x0.title = x1 },
      GI: (x0,x1) => { x0.min = x1 },
      GJ: (x0,x1) => x0.appendChild(x1),
      GK: x0 => x0.name,
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      HC: (x0,x1) => x0.getAttribute(x1),
      HD: x0 => x0.target,
      HE: (o, p) => p in o,
      HF: x0 => x0.getCoalescedEvents(),
      HG: x0 => x0.maxWidth,
      HH: (x0,x1) => x0.vibrate(x1),
      HI: (x0,x1) => { x0.max = x1 },
      HJ: x0 => x0.click(),
      HK: (x0,x1,x2) => ({files: x0,title: x1,text: x2}),
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Float64Array(x0),
      IC: x0 => x0.remove(),
      ID: x0 => x0.clientY,
      IE: (x0,x1) => { x0.textContent = x1 },
      IF: (x0,x1) => x0.getModifierState(x1),
      IG: x0 => x0.minHeight,
      IH: x0 => x0.arrayBuffer(),
      II: (x0,x1) => { x0.disabled = x1 },
      IJ: x0 => x0.length,
      IK: (x0,x1) => ({files: x0,text: x1}),
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (x0,x1) => x0.appendChild(x1),
      JD: x0 => x0.clientX,
      JE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      JF: s => s.trimLeft(),
      JG: x0 => x0.minWidth,
      JH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      JI: (x0,x1) => { x0.scrollLeft = x1 },
      JJ: x0 => x0.children,
      JK: (x0,x1) => ({files: x0,title: x1}),
      K: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      KB: x0 => new ArrayBuffer(x0),
      KC: (x0,x1) => x0.append(x1),
      KD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      KE: x0 => x0.matches,
      KF: (x0,x1) => x0[x1],
      KG: (x0,x1) => x0.removeProperty(x1),
      KH: x0 => x0.status,
      KI: (x0,x1) => { x0.spellcheck = x1 },
      KJ: (x0,x1) => x0.createElement(x1),
      KK: x0 => ({files: x0}),
      L: o => o === undefined,
      LB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      LC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      LD: x0 => x0.getBoundingClientRect(),
      LE: (x0,x1) => x0.matchMedia(x1),
      LF: x0 => x0.index,
      LG: (x0,x1) => x0.add(x1),
      LH: (x0,x1) => x0.fetch(x1),
      LI: (x0,x1) => { x0.disabled = x1 },
      LJ: (x0,x1) => { x0.download = x1 },
      LK: (x0,x1) => ({title: x0,text: x1}),
      M: o => String(o),
      MB: (x0,x1,x2) => new DataView(x0,x1,x2),
      MC: x0 => x0.style,
      MD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      ME: x0 => x0.matches,
      MF: (o, p, r) => o.replace(p, () => r),
      MG: x0 => x0.data,
      MH: x0 => x0.content,
      MI: (x0,x1) => x0.transferFromImageBitmap(x1),
      MJ: (x0,x1) => { x0.href = x1 },
      MK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      N: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      NB: (o, p) => o[p],
      NC: x0 => x0.debugShowSemanticsNodes,
      ND: s => new Date(s * 1000).getTimezoneOffset() * 60,
      NE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      NF: s => s.toUpperCase(),
      NG: (x0,x1) => { x0.scrollTop = x1 },
      NH: x0 => x0.document,
      NI: (x0,x1) => x0.getContext(x1),
      NJ: () => globalThis.document,
      NK: (x0,x1,x2) => x0.addEventListener(x1,x2),
      O: (x0,x1) => x0.didCreateEngineInitializer(x1),
      OB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      OC: o => o,
      OD: Date.now,
      OE: f => f.dartFunction,
      OF: x0 => x0.flags,
      OG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      OH: () => typeof dartUseDateNowForTicks !== "undefined",
      OI: (x0,x1) => { x0.height = x1 },
      OJ: (x0,x1) => x0.querySelector(x1),
      OK: x0 => x0.remove(),
      P: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      PC: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      PD: (handle) => clearTimeout(handle),
      PE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PF: (a, s) => a.join(s),
      PG: (x0,x1) => { x0.value = x1 },
      PH: () => Date.now(),
      PI: (x0,x1) => { x0.width = x1 },
      PJ: x0 => x0.body,
      PK: x0 => x0.message,
      Q: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      QB: o => o.byteOffset,
      QC: (x0,x1) => x0.warn(x1),
      QD: (x0,x1) => x0.closest(x1),
      QE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      QF: (x0,x1) => x0.error(x1),
      QG: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      QH: () => 1000 * performance.now(),
      QI: x0 => x0.height,
      QJ: (x0,x1) => { x0.id = x1 },
      QK: x0 => x0.lastModified,
      R: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      RB: o => o.buffer,
      RC: x0 => x0.console,
      RD: x0 => x0.bottom,
      RE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      RF: () => globalThis.console,
      RG: (x0,x1) => { x0.value = x1 },
      RH: x0 => new Uint8Array(x0),
      RI: x0 => x0.width,
      RJ: x0 => globalThis.URL.createObjectURL(x0),
      RK: x0 => x0.size,
      S: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      SB: Function.prototype.call.bind(DataView.prototype.getUint8),
      SC: () => globalThis.window,
      SD: x0 => x0.top,
      SE: (o, i) => o[i],
      SF: s => s.trimRight(),
      SG: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      SH: (x0,x1,x2) => x0.slice(x1,x2),
      SI: x0 => x0.rasterEndMilliseconds,
      SJ: x0 => ({type: x0}),
      SK: x0 => x0.name,
      T: x0 => new Promise(x0),
      TB: (b, o) => new DataView(b, o),
      TC: (o, c) => o instanceof c,
      TD: x0 => x0.right,
      TE: o => o.length,
      TF: x0 => x0.blur(),
      TG: x0 => x0.value,
      TH: (x0,x1) => x0.decode(x1),
      TI: x0 => x0.rasterStartMilliseconds,
      TJ: (x0,x1) => new Blob(x0,x1),
      TK: x0 => x0.type,
      U: (x0,x1,x2) => x0.call(x1,x2),
      UB: (b, o, l) => new DataView(b, o, l),
      UC: (x0,x1) => x0.exec(x1),
      UD: x0 => x0.left,
      UE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      UF: x0 => x0.button,
      UG: x0 => x0.selectionDirection,
      UH: (x0,x1) => x0.adoptText(x1),
      UI: x0 => x0.imageBitmaps,
      UJ: () => new FileReader(),
      UK: (x0,x1) => x0.item(x1),
      V: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      VB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      VC: x0 => x0.length,
      VD: x0 => x0.clientY,
      VE: x0 => x0.language,
      VF: x0 => x0.innerHeight,
      VG: x0 => x0.selectionStart,
      VH: x0 => x0.first(),
      VI: x0 => x0.canvasKitMaximumSurfaces,
      VJ: (x0,x1) => x0.readAsArrayBuffer(x1),
      VK: x0 => x0.length,
      W: x0 => new Array(x0),
      WB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      WC: (x0,x1) => { x0.lastIndex = x1 },
      WD: x0 => x0.clientX,
      WE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      WF: x0 => x0.innerWidth,
      WG: x0 => x0.selectionEnd,
      WH: x0 => x0.next(),
      WI: (a, i) => a.splice(i, 1),
      WJ: x0 => x0.result,
      WK: x0 => x0.files,
      X: o => [o],
      XB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      XC: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      XD: x0 => x0.changedTouches,
      XE: () => globalThis.window.FinalizationRegistry,
      XF: x0 => x0.height,
      XG: x0 => x0.value,
      XH: x0 => x0.current(),
      XI: a => a.pop(),
      XJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XK: (x0,x1) => { x0.multiple = x1 },
      Y: (o0, o1) => [o0, o1],
      YB: (t, s) => t.set(s),
      YC: o => o instanceof RegExp,
      YD: x0 => x0.offsetY,
      YE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YF: x0 => x0.width,
      YG: x0 => x0.selectionDirection,
      YH: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      YI: (map, o, v) => map.set(o, v),
      YJ: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      YK: (x0,x1) => { x0.accept = x1 },
      Z: (o0, o1, o2) => [o0, o1, o2],
      ZB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      ZC: (string, times) => string.repeat(times),
      ZD: x0 => x0.offsetX,
      ZE: x0 => new window.FinalizationRegistry(x0),
      ZF: x0 => x0.clientHeight,
      ZG: x0 => x0.selectionStart,
      ZH: x0 => x0.v8BreakIterator,
      ZI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      ZJ: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      ZK: (x0,x1) => { x0.type = x1 },
      a: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      aB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      aC: x0 => x0.dotAll,
      aD: x0 => x0.type,
      aE: (x0,x1) => x0.unregister(x1),
      aF: x0 => x0.clientWidth,
      aG: x0 => x0.selectionEnd,
      aH: () => globalThis.Intl,
      aI: (a, s, e) => a.slice(s, e),
      aJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      aK: x0 => x0.href,
      b: (x0,x1,x2) => { x0[x1] = x2 },
      bB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      bC: x0 => x0.unicode,
      bD: x0 => x0.maxTouchPoints,
      bE: (x0,x1) => x0.contains(x1),
      bF: (x0,x1) => { x0.content = x1 },
      bG: x0 => x0.keyCode,
      bH: (x0,x1) => x0.segment(x1),
      bI: x0 => x0.pop(),
      bJ: () => new XMLHttpRequest(),
      bK: x0 => x0.location,
      c: o => o,
      cB: Function.prototype.call.bind(DataView.prototype.getUint32),
      cC: x0 => x0.ignoreCase,
      cD: x0 => x0.platform,
      cE: (s) => +s,
      cF: (x0,x1) => { x0.name = x1 },
      cG: (x0,x1) => x0.scrollIntoView(x1),
      cH: x0 => x0.index,
      cI: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      cJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      cK: x0 => x0.length,
      d: (o, p) => o[p],
      dB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      dC: x0 => x0.multiline,
      dD: x0 => x0.body,
      dE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      dF: x0 => x0.head,
      dG: x0 => x0.multiViewEnabled,
      dH: x0 => x0.next(),
      dI: x0 => x0.naturalHeight,
      dJ: x0 => x0.send(),
      dK: x0 => x0.getReader(),
      e: () => globalThis,
      eB: Function.prototype.call.bind(DataView.prototype.getInt32),
      eC: (string, token) => string.split(token),
      eD: () => globalThis.document,
      eE: s => s.trim(),
      eF: (x0,x1) => x0.removeChild(x1),
      eG: (x0,x1) => x0.replaceWith(x1),
      eH: x0 => x0.value,
      eI: x0 => x0.naturalWidth,
      eJ: x0 => x0.type,
      eK: x0 => x0.value,
      f: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      fB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      fC: o => o instanceof Array,
      fD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      fE: x0 => x0.classList,
      fF: x0 => x0.firstChild,
      fG: (x0,x1) => { x0.type = x1 },
      fH: x0 => x0.done,
      fI: (x0,x1) => { x0.src = x1 },
      fJ: x0 => x0.response,
      fK: x0 => x0.done,
      g: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      gB: o => o instanceof Uint16Array,
      gC: (a, i) => a[i],
      gD: x0 => x0.hasFocus(),
      gE: x0 => x0.preventDefault(),
      gF: x0 => x0.viewConstraints,
      gG: (x0,x1) => { x0.className = x1 },
      gH: (o, m, a) => o[m].apply(o, a),
      gI: x0 => x0.decode(),
      gJ: (x0,x1) => { x0.responseType = x1 },
      gK: x0 => x0.read(),
      h: (x0,x1) => ({addView: x0,removeView: x1}),
      hB: Function.prototype.call.bind(DataView.prototype.getUint16),
      hC: a => a.length,
      hD: x0 => x0.relatedTarget,
      hE: x0 => x0.parent,
      hF: x0 => x0.hostElement,
      hG: (x0,x1) => { x0.tabIndex = x1 },
      hH: x0 => x0.iterator,
      hI: (x0,x1) => { x0.decoding = x1 },
      hJ: x0 => x0.vendor,
      hK: x0 => x0.body,
      i: (l, r) => l === r,
      iB: o => o instanceof Int16Array,
      iC: (x0,x1) => x0.test(x1),
      iD: x0 => x0.shiftKey,
      iE: x0 => x0.timeStamp,
      iF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iG: (x0,x1) => { x0.name = x1 },
      iH: () => globalThis.Symbol,
      iI: (x0,x1) => { x0.crossOrigin = x1 },
      iJ: x0 => x0.navigator,
      iK: (x0,x1) => new OffscreenCanvas(x0,x1),
      j: x0 => x0.random(),
      jB: Function.prototype.call.bind(DataView.prototype.getInt16),
      jC: x0 => x0.userAgent,
      jD: (decoder, codeUnits) => decoder.decode(codeUnits),
      jE: (x0,x1) => x0.hasAttribute(x1),
      jF: x0 => ({runApp: x0}),
      jG: (x0,x1) => { x0.placeholder = x1 },
      jH: (x0,x1) => new Intl.Segmenter(x0,x1),
      jI: (x0,x1) => x0.revokeObjectURL(x1),
      jJ: () => globalThis.window,
      jK: x0 => x0.assetBase,
      k: o => o,
      kB: o => o instanceof Uint8ClampedArray,
      kC: x0 => x0.navigator,
      kD: () => new TextDecoder("utf-8", {fatal: true}),
      kE: x0 => x0.buttons,
      kF: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      kG: (x0,x1) => { x0.autocomplete = x1 },
      kH: x0 => x0.Segmenter,
      kI: (x0,x1) => x0.createObjectURL(x1),
      kJ: secondsSinceEpoch => {
        const date = new Date(secondsSinceEpoch * 1000);
        const match = /\((.*)\)/.exec(date.toString());
        if (match == null) {
            // This should never happen on any recent browser.
            return '';
        }
        return match[1];
      },
      kK: x0 => x0.loader,
      l: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      lB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      lC: Function.prototype.call.bind(String.prototype.toLowerCase),
      lD: () => new TextDecoder("utf-8", {fatal: false}),
      lE: x0 => x0.ctrlKey,
      lF: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      lG: (x0,x1) => { x0.name = x1 },
      lH: x0 => x0.buffer,
      lI: x0 => x0.URL,
      lJ: (d, f) => d.toExponential(f),
      lK: () => globalThis._flutter,
      m: () => globalThis.Math,
      mB: Function.prototype.call.bind(DataView.prototype.setInt32),
      mC: Object.is,
      mD: (a, i, v) => a[i] = v,
      mE: x0 => x0.y,
      mF: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      mG: (x0,x1) => { x0.placeholder = x1 },
      mH: x0 => x0.wasmMemory,
      mI: x0 => new Blob(x0),
      mJ: x0 => x0.hostElement,
      n: (x0,x1) => x0.prepend(x1),
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => x0.vendor,
      nD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      nE: x0 => x0.x,
      nF: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      nG: (x0,x1) => { x0.action = x1 },
      nH: () => globalThis.window._flutter_skwasmInstance,
      nI: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      nJ: x0 => x0.location,
      o: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      oB: Function.prototype.call.bind(DataView.prototype.setInt16),
      oC: (x0,x1) => x0.createTextNode(x1),
      oD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      oE: x0 => x0.scrollTop,
      oF: x0 => x0.history,
      oG: (x0,x1) => { x0.method = x1 },
      oH: () => new TextDecoder(),
      oI: x0 => new window.ImageDecoder(x0),
      oJ: (x0,x1) => x0.getModifierState(x1),
      p: b => !!b,
      pB: Function.prototype.call.bind(DataView.prototype.setUint16),
      pC: (x0,x1) => { x0.id = x1 },
      pD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pE: x0 => x0.offsetTop,
      pF: x0 => x0.search,
      pG: (x0,x1) => { x0.noValidate = x1 },
      pH: x0 => x0.debugSkipFontRetryDelay,
      pI: x0 => x0.name,
      pJ: x0 => x0.metaKey,
      q: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qB: Function.prototype.call.bind(DataView.prototype.setUint8),
      qC: (x0,x1) => { x0.nonce = x1 },
      qD: x0 => x0.visibilityState,
      qE: x0 => x0.scrollLeft,
      qF: x0 => x0.location,
      qG: (x0,x1) => x0.removeAttribute(x1),
      qH: (x0,x1,x2) => x0.set(x1,x2),
      qI: x0 => x0.repetitionCount,
      qJ: x0 => x0.altKey,
      r: (x0,x1) => x0.focus(x1),
      rB: Function.prototype.call.bind(DataView.prototype.setInt8),
      rC: x0 => x0.nonce,
      rD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      rE: x0 => x0.offsetLeft,
      rF: x0 => x0.pathname,
      rG: x0 => x0.isConnected,
      rH: x0 => x0.fontFallbackBaseUrl,
      rI: x0 => x0.frameCount,
      rJ: x0 => x0.ctrlKey,
      s: () => ({}),
      sB: Function.prototype.call.bind(DataView.prototype.getInt8),
      sC: () => globalThis.window.flutterConfiguration,
      sD: x0 => x0.disconnect(),
      sE: x0 => x0.offsetParent,
      sF: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      sG: x0 => x0.click(),
      sH: (handle) => clearInterval(handle),
      sI: x0 => x0.selectedTrack,
      sJ: x0 => x0.isComposing,
      t: (o, p, v) => o[p] = v,
      tB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      tC: (x0,x1) => x0.attachShadow(x1),
      tD: x0 => new Intl.Locale(x0),
      tE: (o, p, r) => o.replaceAll(p, () => r),
      tF: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      tG: (x0,x1) => x0.getElementsByClassName(x1),
      tH: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      tI: x0 => x0.completed,
      tJ: x0 => x0.code,
      u: () => [],
      uB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      uC: (x0,x1) => x0.createElement(x1),
      uD: x0 => x0.region,
      uE: x0 => x0.deltaMode,
      uF: o => Object.keys(o),
      uG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      uH: () => Date.now(),
      uI: x0 => x0.ready,
      uJ: x0 => x0.repeat,
      v: (a, i) => a.push(i),
      vB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      vC: x0 => x0.scale,
      vD: x0 => x0.script,
      vE: x0 => x0.deltaY,
      vF: x0 => x0.state,
      vG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      vH: (map, o) => map.get(o),
      vI: x0 => x0.tracks,
      vJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      w: x0 => new Int8Array(x0),
      wB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      wC: x0 => x0.visualViewport,
      wD: x0 => x0.language,
      wE: x0 => x0.deltaX,
      wF: x0 => x0.hash,
      wG: (x0,x1) => x0.dispatchEvent(x1),
      wH: () => new WeakMap(),
      wI: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      wJ: x0 => x0.userAgent,
      x: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      xC: x0 => x0.devicePixelRatio,
      xD: x0 => x0.languages,
      xE: x0 => x0.wheelDeltaY,
      xF: x0 => x0.state,
      xG: (x0,x1) => x0.createEvent(x1),
      xH: x0 => new WeakRef(x0),
      xI: (x0,x1) => x0.decode(x1),
      xJ: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      y: x0 => new Uint8Array(x0),
      yB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      yC: x0 => x0.height,
      yD: (x0,x1) => x0.observe(x1),
      yE: x0 => x0.wheelDeltaX,
      yF: (x0,x1) => x0.go(x1),
      yG: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      yH: x0 => x0.deref(),
      yI: x0 => x0.displayHeight,
      yJ: (x0,x1) => x0.getItem(x1),
      z: x0 => new Uint8ClampedArray(x0),
      zB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      zC: x0 => x0.width,
      zD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      zE: x0 => x0.key,
      zF: x0 => x0.parentElement,
      zG: x0 => x0.readText(),
      zH: () => globalThis.WeakRef,
      zI: x0 => x0.displayWidth,
      zJ: x0 => x0.localStorage,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
