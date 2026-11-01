import {
  encryptBytes,
  decryptBytes,
  passwordCharCount,
  MAX_FILE_BYTES,
  VctError,
} from './vct.js';

const VERSION = 'v2.6.0';

const I18N = {
  zh: {
    heroTitle: '在浏览器里加密你的文件',
    heroDesc: '三重 AES-256-GCM 加密，全部运算都在你的浏览器内完成——文件不会上传，也不会离开你的设备。',
    badgeLocal: '本地处理',
    badgeCompat: '兼容桌面版 V4',
    tabEncrypt: '加密文件',
    tabDecrypt: '解密文件',
    dropTitle: '拖放文件到这里，或点击选择',
    dropHint: '任意文件类型 · 单个文件不超过 64 MB',
    chooseFiles: '选择文件',
    password: '密码',
    passwordPh: '至少 8 个字符',
    pwNote: '密码按 Unicode 码点计数，至少 8 个。密码只存在于本次会话，丢失后无法恢复。',
    show: '显示',
    hide: '隐藏',
    encryptAction: '加密并生成 .VCT',
    decryptAction: '解密并还原文件',
    clear: '清空',
    workingEncrypt: '正在派生密钥并加密…',
    workingDecrypt: '正在校验密码并解密…',
    resultTitle: '处理完成',
    decryptNote: '已还原原始文件名',
    decoyNote: '此密码打开的是诱饵内容',
    download: '下载',
    downloadAll: '全部下载',
    remove: '移除',
    privacyTitle: '本地处理',
    privacyDesc: '所有加解密都在你的浏览器里完成，文件不会上传到任何服务器，也没有遥测。',
    compatTitle: '格式兼容',
    compatDesc: '输出与桌面版一致的 V4 容器（layout 0x02），可直接在桌面版打开；旧版 V1 / V2 文件也能打开。',
    limitTitle: '网页版说明',
    limitDesc: '网页版不提供汉喃界面、文件粉碎（擦除原文件）、诱饵/胁迫密码、收件人密钥等功能，需要这些请使用桌面版。',
    footerSite: '官网',
    footerGitHub: 'GitHub',
    footerDownload: '桌面版下载',
    errNoFiles: '请先选择文件。',
    errPASSWORD_TOO_SHORT: '密码至少需要 8 个字符（按 Unicode 码点计数）。',
    errFILE_TOO_LARGE: '文件超过 64 MB 上限，请改用桌面版。',
    errEMPTY_FILE: '空文件无法加密。',
    errWRONG_PASSWORD: '密码不正确，或文件已损坏。',
    errNOT_VCT: '这不是 VCT 加密文件。',
    errUNSUPPORTED_V3: '网页版不支持收件人密钥（V3）文件，请使用桌面版打开。',
    errUNSUPPORTED_FORMAT: '不支持的 VCT 版本，请使用桌面版打开。',
    errCORRUPT: '文件已损坏或已被篡改。',
    errFILE_TOO_SMALL: '文件太小，不是有效的 VCT 文件。',
    errPAYLOAD_CORRUPT: '解密后的内容不完整。',
    errGENERIC: '处理失败，请重试。',
  },
  en: {
    heroTitle: 'Encrypt your files in the browser',
    heroDesc: 'Triple AES-256-GCM encryption that runs entirely inside your browser — nothing is uploaded, nothing leaves your device.',
    badgeLocal: 'On-device',
    badgeCompat: 'Desktop V4 compatible',
    tabEncrypt: 'Encrypt',
    tabDecrypt: 'Decrypt',
    dropTitle: 'Drop files here, or click to choose',
    dropHint: 'Any file type · up to 64 MB per file',
    chooseFiles: 'Choose files',
    password: 'Password',
    passwordPh: 'At least 8 characters',
    pwNote: 'Passwords are counted in Unicode code points (8 minimum). The password only lives in this session — it cannot be recovered.',
    show: 'Show',
    hide: 'Hide',
    encryptAction: 'Encrypt to .VCT',
    decryptAction: 'Decrypt files',
    clear: 'Clear',
    workingEncrypt: 'Deriving keys and encrypting…',
    workingDecrypt: 'Verifying the password and decrypting…',
    resultTitle: 'Done',
    decryptNote: 'Original file name restored',
    decoyNote: 'This password opens the decoy content',
    download: 'Download',
    downloadAll: 'Download all',
    remove: 'Remove',
    privacyTitle: 'Local by design',
    privacyDesc: 'Every operation runs in your browser. No uploads, no servers, no telemetry.',
    compatTitle: 'Format compatible',
    compatDesc: 'Outputs the same V4 container as the desktop app (layout 0x02), so desktop opens it directly; older V1 / V2 files open too.',
    limitTitle: 'About the web edition',
    limitDesc: 'The web edition leaves out the Chữ Nôm UI, secure shredding, decoy/duress passwords and recipient keys — use the desktop app for those.',
    footerSite: 'Website',
    footerGitHub: 'GitHub',
    footerDownload: 'Desktop downloads',
    errNoFiles: 'Choose a file first.',
    errPASSWORD_TOO_SHORT: 'The password needs at least 8 characters (Unicode code points).',
    errFILE_TOO_LARGE: 'Files above 64 MB are not supported here — use the desktop app.',
    errEMPTY_FILE: 'An empty file cannot be encrypted.',
    errWRONG_PASSWORD: 'Wrong password, or the file is damaged.',
    errNOT_VCT: 'This is not a VCT container.',
    errUNSUPPORTED_V3: 'Recipient-key (V3) files are not supported by the web edition — open them with the desktop app.',
    errUNSUPPORTED_FORMAT: 'Unsupported VCT version — open it with the desktop app.',
    errCORRUPT: 'The file is damaged or has been tampered with.',
    errFILE_TOO_SMALL: 'Too small to be a valid VCT file.',
    errPAYLOAD_CORRUPT: 'The decrypted payload is incomplete.',
    errGENERIC: 'Something went wrong — please try again.',
  },
  fr: {
    heroTitle: 'Chiffrez vos fichiers dans le navigateur',
    heroDesc: 'Triple chiffrement AES-256-GCM exécuté entièrement dans votre navigateur — aucun fichier n’est envoyé, rien ne quitte votre appareil.',
    badgeLocal: 'Traitement local',
    badgeCompat: 'Compatible V4 bureau',
    tabEncrypt: 'Chiffrer',
    tabDecrypt: 'Déchiffrer',
    dropTitle: 'Déposez des fichiers ici ou cliquez pour choisir',
    dropHint: 'Tout type de fichier · 64 Mo maximum par fichier',
    chooseFiles: 'Choisir des fichiers',
    password: 'Mot de passe',
    passwordPh: 'Au moins 8 caractères',
    pwNote: 'Les mots de passe sont comptés en points de code Unicode (8 minimum). Le mot de passe ne vit que dans cette session : il est irrécupérable.',
    show: 'Afficher',
    hide: 'Masquer',
    encryptAction: 'Chiffrer en .VCT',
    decryptAction: 'Déchiffrer les fichiers',
    clear: 'Effacer',
    workingEncrypt: 'Dérivation des clés et chiffrement…',
    workingDecrypt: 'Vérification du mot de passe et déchiffrement…',
    resultTitle: 'Terminé',
    decryptNote: 'Nom de fichier d’origine restauré',
    decoyNote: 'Ce mot de passe ouvre le contenu leurre',
    download: 'Télécharger',
    downloadAll: 'Tout télécharger',
    remove: 'Retirer',
    privacyTitle: 'Traitement local',
    privacyDesc: 'Toutes les opérations se font dans votre navigateur. Aucun envoi, aucun serveur, aucune télémétrie.',
    compatTitle: 'Format compatible',
    compatDesc: 'Produit le même conteneur V4 que l’application de bureau (layout 0x02) ; les anciens fichiers V1 / V2 s’ouvrent aussi.',
    limitTitle: 'À propos de la version web',
    limitDesc: 'La version web ne propose pas l’interface Chữ Nôm, l’effacement sécurisé, les mots de passe leurre/contrainte ni les clés destinataires — utilisez l’application de bureau.',
    footerSite: 'Site',
    footerGitHub: 'GitHub',
    footerDownload: 'Télécharger la version bureau',
    errNoFiles: 'Choisissez d’abord un fichier.',
    errPASSWORD_TOO_SHORT: 'Le mot de passe doit contenir au moins 8 caractères (points de code Unicode).',
    errFILE_TOO_LARGE: 'Les fichiers de plus de 64 Mo ne sont pas pris en charge ici — utilisez l’application de bureau.',
    errEMPTY_FILE: 'Un fichier vide ne peut pas être chiffré.',
    errWRONG_PASSWORD: 'Mot de passe incorrect ou fichier endommagé.',
    errNOT_VCT: 'Ceci n’est pas un conteneur VCT.',
    errUNSUPPORTED_V3: 'Les fichiers à clé destinataire (V3) ne sont pas pris en charge par la version web — ouvrez-les avec l’application de bureau.',
    errUNSUPPORTED_FORMAT: 'Version VCT non prise en charge — ouvrez-la avec l’application de bureau.',
    errCORRUPT: 'Le fichier est endommagé ou a été altéré.',
    errFILE_TOO_SMALL: 'Trop petit pour être un fichier VCT valide.',
    errPAYLOAD_CORRUPT: 'Le contenu déchiffré est incomplet.',
    errGENERIC: 'Une erreur est survenue — réessayez.',
  },
  de: {
    heroTitle: 'Dateien im Browser verschlüsseln',
    heroDesc: 'Dreifache AES-256-GCM-Verschlüsselung, komplett im Browser — nichts wird hochgeladen, nichts verlässt dein Gerät.',
    badgeLocal: 'Lokal verarbeitet',
    badgeCompat: 'Kompatibel mit Desktop-V4',
    tabEncrypt: 'Verschlüsseln',
    tabDecrypt: 'Entschlüsseln',
    dropTitle: 'Dateien hierher ziehen oder klicken',
    dropHint: 'Beliebiger Dateityp · höchstens 64 MB pro Datei',
    chooseFiles: 'Dateien wählen',
    password: 'Passwort',
    passwordPh: 'Mindestens 8 Zeichen',
    pwNote: 'Passwörter werden in Unicode-Codepunkten gezählt (mindestens 8). Das Passwort gilt nur in dieser Sitzung und kann nicht wiederhergestellt werden.',
    show: 'Anzeigen',
    hide: 'Verbergen',
    encryptAction: 'Als .VCT verschlüsseln',
    decryptAction: 'Dateien entschlüsseln',
    clear: 'Leeren',
    workingEncrypt: 'Schlüssel werden abgeleitet und verschlüsselt…',
    workingDecrypt: 'Passwort wird geprüft und entschlüsselt…',
    resultTitle: 'Fertig',
    decryptNote: 'Ursprünglicher Dateiname wiederhergestellt',
    decoyNote: 'Dieses Passwort öffnet den Köderinhalt',
    download: 'Herunterladen',
    downloadAll: 'Alle herunterladen',
    remove: 'Entfernen',
    privacyTitle: 'Lokal verarbeitet',
    privacyDesc: 'Alles läuft in deinem Browser. Keine Uploads, keine Server, keine Telemetrie.',
    compatTitle: 'Formatkompatibel',
    compatDesc: 'Erzeugt denselben V4-Container wie die Desktop-App (Layout 0x02); ältere V1-/V2-Dateien lassen sich ebenfalls öffnen.',
    limitTitle: 'Zur Web-Version',
    limitDesc: 'Die Web-Version bietet keine Chữ-Nôm-Oberfläche, kein sicheren Löschen, keine Köder-/Nötigungspasswörter und keine Empfängerschlüssel — dafür gibt es die Desktop-App.',
    footerSite: 'Website',
    footerGitHub: 'GitHub',
    footerDownload: 'Desktop-Downloads',
    errNoFiles: 'Wähle zuerst eine Datei.',
    errPASSWORD_TOO_SHORT: 'Das Passwort braucht mindestens 8 Zeichen (Unicode-Codepunkte).',
    errFILE_TOO_LARGE: 'Dateien über 64 MB werden hier nicht unterstützt — nutze die Desktop-App.',
    errEMPTY_FILE: 'Eine leere Datei kann nicht verschlüsselt werden.',
    errWRONG_PASSWORD: 'Falsches Passwort oder beschädigte Datei.',
    errNOT_VCT: 'Das ist kein VCT-Container.',
    errUNSUPPORTED_V3: 'Dateien mit Empfängerschlüssel (V3) werden von der Web-Version nicht unterstützt — öffne sie mit der Desktop-App.',
    errUNSUPPORTED_FORMAT: 'Nicht unterstützte VCT-Version — öffne sie mit der Desktop-App.',
    errCORRUPT: 'Die Datei ist beschädigt oder wurde manipuliert.',
    errFILE_TOO_SMALL: 'Zu klein für eine gültige VCT-Datei.',
    errPAYLOAD_CORRUPT: 'Der entschlüsselte Inhalt ist unvollständig.',
    errGENERIC: 'Etwas ist schiefgelaufen — bitte erneut versuchen.',
  },
};

const state = {
  mode: 'encrypt',
  files: [],
  results: [],
  busy: false,
};

const el = {};
let lang = 'zh';

function t(key) {
  return I18N[lang][key] ?? I18N.en[key] ?? key;
}

function applyLanguage() {
  document.documentElement.lang =
    { zh: 'zh-CN', en: 'en', fr: 'fr', de: 'de' }[lang];
  for (const node of document.querySelectorAll('[data-i18n]')) {
    node.textContent = t(node.dataset.i18n);
  }
  for (const node of document.querySelectorAll('[data-i18n-placeholder]')) {
    node.placeholder = t(node.dataset.i18nPlaceholder);
  }
  el.langSelect.value = lang;
  updateActionLabels();
  el.pwToggle.textContent = el.password.type === 'password' ? t('show') : t('hide');
  if (!state.busy) renderResults();
}

function updateActionLabels() {
  el.runBtn.textContent = t(state.mode === 'encrypt' ? 'encryptAction' : 'decryptAction');
  el.runBtn.disabled = state.busy || state.files.length === 0;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function setStatus(text, isError = false) {
  if (!text) {
    el.status.hidden = true;
    el.status.textContent = '';
    el.status.classList.remove('error');
    return;
  }
  el.status.hidden = false;
  el.status.textContent = text;
  el.status.classList.toggle('error', isError);
}

function setBusy(busy) {
  state.busy = busy;
  el.spinner.hidden = !busy;
  el.clearBtn.disabled = busy;
  updateActionLabels();
}

function renderFiles() {
  el.fileList.textContent = '';
  state.files.forEach((file, index) => {
    const row = document.createElement('div');
    row.className = 'file-row';

    const meta = document.createElement('div');
    meta.className = 'meta';
    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = file.name;
    const size = document.createElement('span');
    size.className = 'size';
    size.textContent = formatSize(file.size);
    meta.append(name, size);

    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = t('remove');
    remove.addEventListener('click', () => {
      state.files.splice(index, 1);
      renderFiles();
      updateActionLabels();
    });

    row.append(meta, remove);
    el.fileList.append(row);
  });
  updateActionLabels();
}

function downloadBlob(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}

function renderResults() {
  el.results.textContent = '';
  if (!state.results.length) return;

  for (const item of state.results) {
    const row = document.createElement('div');
    row.className = 'result-row';

    const meta = document.createElement('div');
    meta.className = 'meta';

    if (item.error) {
      const name = document.createElement('span');
      name.className = 'name';
      name.textContent = item.source;
      const sub = document.createElement('span');
      sub.className = 'sub';
      sub.textContent = item.error;
      meta.append(name, sub);
      row.append(meta);
      el.results.append(row);
      continue;
    }

    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = item.name;
    const sub = document.createElement('span');
    sub.className = 'sub';
    const bits = [formatSize(item.size)];
    if (item.isDecoy) bits.push(t('decoyNote'));
    sub.textContent = bits.join(' · ');
    meta.append(name, sub);

    const get = document.createElement('button');
    get.type = 'button';
    get.className = 'get';
    get.textContent = t('download');
    get.addEventListener('click', () => downloadBlob(item.blob, item.name));

    row.append(meta, get);
    el.results.append(row);
  }

  const downloadable = state.results.filter((item) => item.blob);
  if (downloadable.length > 1) {
    const all = document.createElement('button');
    all.type = 'button';
    all.className = 'btn ghost all-download';
    all.textContent = t('downloadAll');
    all.addEventListener('click', async () => {
      for (const item of downloadable) {
        downloadBlob(item.blob, item.name);
        await new Promise((resolve) => setTimeout(resolve, 400));
      }
    });
    el.results.append(all);
  }
}

function errorMessage(error) {
  if (error instanceof VctError) {
    const key = `err${error.code}`;
    if (I18N[lang][key] || I18N.en[key]) return t(key);
  }
  return t('errGENERIC');
}

async function runEncrypt() {
  const password = el.password.value;
  if (passwordCharCount(password) < 8) {
    setStatus(t('errPASSWORD_TOO_SHORT'), true);
    return;
  }

  state.results = [];
  setBusy(true);
  for (const file of state.files) {
    setStatus(t('workingEncrypt'));
    if (file.size > MAX_FILE_BYTES) {
      state.results.push({ source: file.name, error: t('errFILE_TOO_LARGE') });
      continue;
    }
    try {
      const plain = new Uint8Array(await file.arrayBuffer());
      const out = await encryptBytes(file.name, plain, password);
      state.results.push({
        name: out.fileName,
        blob: new Blob([out.bytes], { type: 'application/octet-stream' }),
        size: out.bytes.length,
      });
    } catch (error) {
      state.results.push({ source: file.name, error: errorMessage(error) });
    }
  }
  setBusy(false);
  setStatus(t('resultTitle'));
  renderResults();
}

async function runDecrypt() {
  const password = el.password.value;
  state.results = [];
  setBusy(true);
  for (const file of state.files) {
    setStatus(t('workingDecrypt'));
    try {
      const encrypted = new Uint8Array(await file.arrayBuffer());
      const out = await decryptBytes(encrypted, password);
      state.results.push({
        name: out.name,
        blob: new Blob([out.data], { type: 'application/octet-stream' }),
        size: out.data.length,
        isDecoy: out.isDecoy,
      });
    } catch (error) {
      state.results.push({ source: file.name, error: errorMessage(error) });
    }
  }
  setBusy(false);
  setStatus(t('resultTitle'));
  renderResults();
}

function addFiles(fileList) {
  const incoming = Array.from(fileList);
  if (!incoming.length) return;
  state.files.push(...incoming);
  state.results = [];
  setStatus('');
  renderFiles();
  renderResults();
}

function setMode(mode) {
  state.mode = mode;
  state.files = [];
  state.results = [];
  setStatus('');
  for (const tab of el.tabs) {
    tab.classList.toggle('active', tab.dataset.mode === mode);
  }
  el.fileInput.accept = mode === 'decrypt' ? '.vct,.VCT' : '';
  renderFiles();
  renderResults();
  updateActionLabels();
}

function applyTheme(theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark');
  localStorage.setItem('vctweb.theme', theme);
  el.themeBtn.textContent = theme === 'dark' ? '☾' : '☼';
}

function boot() {
  el.langSelect = document.getElementById('langSelect');
  el.themeBtn = document.getElementById('themeBtn');
  el.tabs = Array.from(document.querySelectorAll('.tab'));
  el.dropzone = document.getElementById('dropzone');
  el.chooseBtn = document.getElementById('chooseBtn');
  el.fileInput = document.getElementById('fileInput');
  el.fileList = document.getElementById('fileList');
  el.password = document.getElementById('password');
  el.pwToggle = document.getElementById('pwToggle');
  el.runBtn = document.getElementById('runBtn');
  el.clearBtn = document.getElementById('clearBtn');
  el.spinner = document.getElementById('spinner');
  el.status = document.getElementById('status');
  el.results = document.getElementById('results');

  document.getElementById('versionLabel').textContent = VERSION;
  document.getElementById('footVersion').textContent = VERSION;

  const storedLang = localStorage.getItem('vctweb.lang');
  const browserLang = (navigator.language || 'zh').slice(0, 2);
  lang = storedLang || (I18N[browserLang] ? browserLang : 'en');

  const storedTheme = localStorage.getItem('vctweb.theme');
  const prefersDark = matchMedia('(prefers-color-scheme: dark)').matches;
  applyTheme(storedTheme || (prefersDark ? 'dark' : 'light'));

  el.langSelect.addEventListener('change', () => {
    lang = el.langSelect.value;
    localStorage.setItem('vctweb.lang', lang);
    applyLanguage();
    renderFiles();
  });

  el.themeBtn.addEventListener('click', () => {
    applyTheme(document.documentElement.classList.contains('dark') ? 'light' : 'dark');
  });

  for (const tab of el.tabs) {
    tab.addEventListener('click', () => setMode(tab.dataset.mode));
  }

  el.chooseBtn.addEventListener('click', (event) => {
    event.stopPropagation();
    el.fileInput.click();
  });
  el.dropzone.addEventListener('click', () => el.fileInput.click());
  el.dropzone.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      el.fileInput.click();
    }
  });
  el.fileInput.addEventListener('change', () => {
    addFiles(el.fileInput.files);
    el.fileInput.value = '';
  });

  for (const type of ['dragenter', 'dragover']) {
    el.dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      el.dropzone.classList.add('dragover');
    });
  }
  for (const type of ['dragleave', 'drop']) {
    el.dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      el.dropzone.classList.remove('dragover');
    });
  }
  el.dropzone.addEventListener('drop', (event) => {
    if (event.dataTransfer?.files?.length) addFiles(event.dataTransfer.files);
  });

  el.pwToggle.addEventListener('click', () => {
    el.password.type = el.password.type === 'password' ? 'text' : 'password';
    el.pwToggle.textContent = el.password.type === 'password' ? t('show') : t('hide');
  });

  el.runBtn.addEventListener('click', () => {
    if (!state.files.length) {
      setStatus(t('errNoFiles'), true);
      return;
    }
    if (state.mode === 'encrypt') runEncrypt();
    else runDecrypt();
  });

  el.clearBtn.addEventListener('click', () => {
    state.files = [];
    state.results = [];
    el.password.value = '';
    setStatus('');
    renderFiles();
    renderResults();
  });

  applyLanguage();
  setMode('encrypt');
}

boot();
