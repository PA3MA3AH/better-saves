/*:
 * @plugindesc v1.1 Better Save System for The Coffin of Andy and Leyley
 * @author YanMod
 *
 * @param language
 * @text Language / Язык
 * @desc EN = English, RU = Russian
 * @type select
 * @option RU
 * @option EN
 * @default RU
 *
 * @param showMapId
 * @text Show mapId (debug)
 * @desc Show mapId number on save slots
 * @type boolean
 * @default true
 *
 * @help
 * BetterSaves v1.1
 * - 50 save slots
 * - Episode label (auto-detected from save data)
 * - Notes per slot (add/edit without overwriting)
 * - Copy / Delete saves
 * - Language: RU / EN (change in Options menu)
 * - Bug report button
 */

(function() {

'use strict';

// ─── PARAMETERS ──────────────────────────────────────────────────────
var params     = PluginManager.parameters('BetterSaves');
var LANG       = (params['language'] || 'RU').trim().toUpperCase();
var SHOW_MAPID = (params['showMapId'] !== 'false');

// ─── LOCALIZATION ─────────────────────────────────────────────────────
var T = {
    RU: {
        ep1:           "Эпизод 1",
        ep2:           "Эпизод 2",
        ep3a:          "Эпизод 3 (ч.1)",
        ep4:           "Эпизод 4",
        unknown:       "???",
        notePrompt:    "Заметка (макс. 40 символов):",
        copyPrompt:    "Скопировать в слот (1-50):",
        deleteConfirm: "Удалить сохранение в слоте ",
        reportCopied:  "Скопировано в буфер:\n",
        cmdLoad:       "Загрузить",
        cmdCopy:       "Копировать",
        cmdDelete:     "Удалить",
        cmdEdit:       "Изм. заметку",
        cmdReport:     "Репорт ошибки",
        cmdCancel:     "Отмена",
        langLabel:     "Язык мода сейвов",
    },
    EN: {
        ep1:           "Episode 1",
        ep2:           "Episode 2",
        ep3a:          "Episode 3 (pt.1)",
        ep4:           "Episode 4",
        unknown:       "???",
        notePrompt:    "Note (max 40 chars):",
        copyPrompt:    "Copy to slot (1-50):",
        deleteConfirm: "Delete save in slot ",
        reportCopied:  "Copied to clipboard:\n",
        cmdLoad:       "Load",
        cmdCopy:       "Copy",
        cmdDelete:     "Delete",
        cmdEdit:       "Edit note",
        cmdReport:     "Report bug",
        cmdCancel:     "Cancel",
        langLabel:     "Save mod language",
    }
};

function t(key) {
    return (LANG === 'EN' ? T.EN[key] : T.RU[key]) || key;
}

// ─── EPISODE DETECTION ───────────────────────────────────────────────
function detectEpisode(mapId) {
    mapId = parseInt(mapId) || 0;
    if (mapId >= 3   && mapId <= 18)  return t('ep1');
    if (mapId === 221)                return t('ep4');
    if (mapId === 261)                return t('ep2');
    if (mapId >= 19  && mapId <= 107) return t('ep2');
    if (mapId >= 1   && mapId <= 2)   return t('ep3a');
    if (mapId >= 108)                 return t('ep3a');
    return t('unknown');
}

// ─── 50 СЛОТОВ ───────────────────────────────────────────────────────
DataManager.maxSavefiles = function() { return 50; };

// ─── AUTO-FIX EPISODES ON STARTUP ────────────────────────────────────
var BetterSaves = {};

BetterSaves.fixGlobalInfo = function() {
    try {
        var globalInfo = DataManager.loadGlobalInfo();
        if (!globalInfo) return;
        var changed = false;
        for (var i = 1; i <= DataManager.maxSavefiles(); i++) {
            if (!globalInfo[i]) continue;
            if (!globalInfo[i].mapId || !globalInfo[i].chapter || globalInfo[i].chapter === '???') {
                try {
                    var json = StorageManager.load(i);
                    if (json) {
                        var data = JSON.parse(json);
                        var mapId = data && data.map && data.map._mapId;
                        if (mapId) {
                            globalInfo[i].mapId   = mapId;
                            globalInfo[i].chapter = detectEpisode(mapId);
                            changed = true;
                        }
                    }
                } catch(e) {}
            }
            if (globalInfo[i].mapId) {
                var expected = detectEpisode(globalInfo[i].mapId);
                if (globalInfo[i].chapter !== expected) {
                    globalInfo[i].chapter = expected;
                    changed = true;
                }
            }
        }
        if (changed) DataManager.saveGlobalInfo(globalInfo);
    } catch(e) {
        console.warn('BetterSaves.fixGlobalInfo error:', e);
    }
};

var _DataManager_loadDatabase = DataManager.loadDatabase;
DataManager.loadDatabase = function() {
    _DataManager_loadDatabase.call(this);
    BetterSaves.fixGlobalInfo();
};

// ─── SAVE: EPISODE + mapId + NOTE ────────────────────────────────────
var _makeSavefileInfo = DataManager.makeSavefileInfo;
DataManager.makeSavefileInfo = function() {
    var info = _makeSavefileInfo.call(this);
    var mapId = $gameMap ? $gameMap.mapId() : 0;
    info.mapId   = mapId;
    info.chapter = detectEpisode(mapId);
    info.note    = (DataManager._pendingNote !== undefined && DataManager._pendingNote !== null)
                   ? DataManager._pendingNote
                   : (info.note || "");
    DataManager._pendingNote = null;
    return info;
};

// ─── NOTE PROMPT ON SAVE ─────────────────────────────────────────────
var _Scene_Save_onSavefileOk = Scene_Save.prototype.onSavefileOk;
Scene_Save.prototype.onSavefileOk = function() {
    var index = this.savefileId();
    var existingNote = "";
    var info = DataManager.loadSavefileInfo(index);
    if (info && info.note) existingNote = info.note;
    var note = window.prompt(t('notePrompt'), existingNote);
    if (note === null) { this.activateListWindow(); return; }
    DataManager._pendingNote = note.substring(0, 40);
    _Scene_Save_onSavefileOk.call(this);
};

// ─── SLOT DISPLAY ────────────────────────────────────────────────────
Window_SavefileList.prototype.drawGameTitle = function(info, x, y, width) {
    var episode = info.chapter || t('unknown');
    var note    = info.note    ? "  \u2014  " + info.note : "";
    var mapId   = (SHOW_MAPID && info.mapId) ? " [" + info.mapId + "]" : "";
    this.changeTextColor(this.normalColor());
    this.drawText("[" + episode + "]" + note, x, y, width - 70);
    this.changeTextColor(this.textColor(8));
    this.drawText(mapId, x + width - 70, y, 70, "right");
    this.changeTextColor(this.normalColor());
};

// ─── LOAD MENU POPUP ─────────────────────────────────────────────────
var _Scene_Load_create = Scene_Load.prototype.create;
Scene_Load.prototype.create = function() {
    _Scene_Load_create.call(this);
    this._actionWindow = new Window_SaveAction(0, 0);
    this._actionWindow.hide();
    this._actionWindow.deactivate();
    this._actionWindow.setHandler("load",   this.onActionLoad.bind(this));
    this._actionWindow.setHandler("copy",   this.onActionCopy.bind(this));
    this._actionWindow.setHandler("delete", this.onActionDelete.bind(this));
    this._actionWindow.setHandler("edit",   this.onActionEdit.bind(this));
    this._actionWindow.setHandler("report", this.onActionReport.bind(this));
    this._actionWindow.setHandler("cancel", this.onActionCancel.bind(this));
    this.addWindow(this._actionWindow);
};

var _Scene_Load_onSavefileOk = Scene_Load.prototype.onSavefileOk;
Scene_Load.prototype.onSavefileOk = function() {
    var id = this.savefileId();
    if (DataManager.isThisGameFile(id)) {
        this._listWindow.deactivate();
        var rect = this._listWindow.itemRect(this._listWindow.index());
        var ax = Math.min(rect.x + rect.width / 2, Graphics.width - this._actionWindow.width);
        var ay = Math.min(Math.max(rect.y, 0), Graphics.height - this._actionWindow.height);
        this._actionWindow.x = ax;
        this._actionWindow.y = ay;
        this._actionWindow.show();
        this._actionWindow.activate();
        this._actionWindow.select(0);
    } else {
        this.onActionCancel();
    }
};

Scene_Load.prototype.onActionLoad = function() {
    this._actionWindow.hide();
    _Scene_Load_onSavefileOk.call(this);
};

Scene_Load.prototype.onActionEdit = function() {
    var id = this.savefileId();
    var info = DataManager.loadSavefileInfo(id);
    var existingNote = (info && info.note) ? info.note : "";
    var note = window.prompt(t('notePrompt'), existingNote);
    if (note !== null) {
        var globalInfo = DataManager.loadGlobalInfo() || [];
        if (globalInfo[id]) {
            globalInfo[id].note = note.substring(0, 40);
            DataManager.saveGlobalInfo(globalInfo);
            this._listWindow.refresh();
        }
    }
    this._actionWindow.hide();
    this._listWindow.activate();
};

Scene_Load.prototype.onActionCopy = function() {
    var srcId = this.savefileId();
    var dest = window.prompt(t('copyPrompt'));
    if (dest !== null) {
        dest = parseInt(dest);
        if (!isNaN(dest) && dest >= 1 && dest <= 50 && dest !== srcId) {
            var srcData = StorageManager.load(srcId);
            if (srcData) {
                StorageManager.save(dest, srcData);
                var globalInfo = DataManager.loadGlobalInfo() || [];
                var srcInfo = DataManager.loadSavefileInfo(srcId);
                globalInfo[dest] = JsonEx.makeDeepCopy(srcInfo);
                DataManager.saveGlobalInfo(globalInfo);
                SoundManager.playSave();
                this._listWindow.refresh();
            }
        }
    }
    this._actionWindow.hide();
    this._listWindow.activate();
};

Scene_Load.prototype.onActionDelete = function() {
    var id = this.savefileId();
    if (window.confirm(t('deleteConfirm') + id + "?")) {
        StorageManager.remove(id);
        var globalInfo = DataManager.loadGlobalInfo() || [];
        globalInfo[id] = null;
        DataManager.saveGlobalInfo(globalInfo);
        SoundManager.playLoad();
        this._listWindow.refresh();
    }
    this._actionWindow.hide();
    this._listWindow.activate();
};

Scene_Load.prototype.onActionReport = function() {
    var id = this.savefileId();
    var info = DataManager.loadSavefileInfo(id);
    var mapId   = info && info.mapId   ? info.mapId   : "?";
    var episode = info && info.chapter ? info.chapter : "?";
    var text = "Slot: " + id + " | mapId: " + mapId + " | Episode: " + episode;
    if (window.nw && nw.Clipboard) {
        nw.Clipboard.get().set(text, 'text');
        window.alert(t('reportCopied') + text);
    } else {
        window.prompt(t('reportCopied'), text);
    }
    this._actionWindow.hide();
    this._listWindow.activate();
};

Scene_Load.prototype.onActionCancel = function() {
    this._actionWindow.hide();
    this._listWindow.activate();
};

// ─── POPUP WINDOW ────────────────────────────────────────────────────
function Window_SaveAction() { this.initialize.apply(this, arguments); }
Window_SaveAction.prototype = Object.create(Window_Command.prototype);
Window_SaveAction.prototype.constructor = Window_SaveAction;
Window_SaveAction.prototype.initialize = function(x, y) {
    Window_Command.prototype.initialize.call(this, x, y);
    this.openness = 255;
};
Window_SaveAction.prototype.windowWidth    = function() { return 220; };
Window_SaveAction.prototype.numVisibleRows = function() { return 6; };
Window_SaveAction.prototype.makeCommandList = function() {
    this.addCommand(t('cmdLoad'),   "load");
    this.addCommand(t('cmdCopy'),   "copy");
    this.addCommand(t('cmdDelete'), "delete");
    this.addCommand(t('cmdEdit'),   "edit");
    this.addCommand(t('cmdReport'), "report");
    this.addCommand(t('cmdCancel'), "cancel");
};

// ─── LANGUAGE OPTION IN GAME OPTIONS MENU ────────────────────────────
var _Window_Options_addGeneralOptions = Window_Options.prototype.addGeneralOptions;
Window_Options.prototype.addGeneralOptions = function() {
    _Window_Options_addGeneralOptions.call(this);
    this.addCommand(t('langLabel'), 'betterSavesLang');
};

var _Window_Options_statusText = Window_Options.prototype.statusText;
Window_Options.prototype.statusText = function(index) {
    if (this.commandSymbol(index) === 'betterSavesLang') return LANG;
    return _Window_Options_statusText.call(this, index);
};

var _Window_Options_processOk = Window_Options.prototype.processOk;
Window_Options.prototype.processOk = function() {
    if (this.commandSymbol(this.index()) === 'betterSavesLang') {
        this.toggleLang(); return;
    }
    _Window_Options_processOk.call(this);
};

var _Window_Options_cursorRight = Window_Options.prototype.cursorRight;
Window_Options.prototype.cursorRight = function(wrap) {
    if (this.commandSymbol(this.index()) === 'betterSavesLang') { this.toggleLang(); return; }
    _Window_Options_cursorRight.call(this, wrap);
};

var _Window_Options_cursorLeft = Window_Options.prototype.cursorLeft;
Window_Options.prototype.cursorLeft = function(wrap) {
    if (this.commandSymbol(this.index()) === 'betterSavesLang') { this.toggleLang(); return; }
    _Window_Options_cursorLeft.call(this, wrap);
};

Window_Options.prototype.toggleLang = function() {
    LANG = (LANG === 'RU') ? 'EN' : 'RU';
    ConfigManager['betterSavesLang'] = LANG;
    ConfigManager.save();
    BetterSaves.fixGlobalInfo();
    this.redrawItem(this.index());
    SoundManager.playCursor();
};

var _ConfigManager_makeData = ConfigManager.makeData;
ConfigManager.makeData = function() {
    var config = _ConfigManager_makeData.call(this);
    config.betterSavesLang = LANG;
    return config;
};

var _ConfigManager_applyData = ConfigManager.applyData;
ConfigManager.applyData = function(config) {
    _ConfigManager_applyData.call(this, config);
    if (config.betterSavesLang) LANG = config.betterSavesLang;
};

})();
