/*:
 * @plugindesc v1.7.16 Better Save System
 * @author PA3MA3AH
 *
 * @param language
 * @text Language / Язык
 * @desc EN = English, RU = Russian
 * @type select
 * @option RU
 * @option EN
 * @default EN
 *
 * @param showMapId
 * @text Show mapId (debug)
 * @desc Show mapId number on save slots
 * @type boolean
 * @default false
 *
 * @help
 * BetterSaves v1.7.16
 * - Episode label (auto-detected from save data)
 * - Notes per slot (in-game text input, real-time display)
 * - Copy / Delete saves (in-game confirm windows)
 * - Full metadata copy
 * - Language: RU / EN
 */

(function() {

'use strict';

var params     = PluginManager.parameters('BetterSaves');
var LANG       = (params['language'] || 'RU').trim().toUpperCase();
var SHOW_MAPID = (params['showMapId'] === 'true');

var NOTE_MAX_LEN = 40;

var T = {
    RU: {
        ep1:           "Эпизод 1",
        ep2:           "Эпизод 2",
        ep3a:          "Эпизод 3 (ч.1)",
        ep4:           "Эпизод 4",
        unknown:       "???",
        cmdLoad:       "Загрузить",
        cmdCopy:       "Копировать",
        cmdDelete:     "Удалить",
        cmdEdit:       "Изм. заметку",
        cmdCancel:     "Отмена",
        langLabel:     "Язык мода сейвов",
        copyOverwrite: "Слот занят. Перезаписать?",
        copyYes:       "Да",
        copyNo:        "Нет",
        deleteQuestion:"Вы уверены, что хотите удалить слот {0}?"
    },
    EN: {
        ep1:           "Episode 1",
        ep2:           "Episode 2",
        ep3a:          "Episode 3 (pt.1)",
        ep4:           "Episode 4",
        unknown:       "???",
        cmdLoad:       "Load",
        cmdCopy:       "Copy",
        cmdDelete:     "Delete",
        cmdEdit:       "Edit note",
        cmdCancel:     "Cancel",
        langLabel:     "Save mod language",
        copyOverwrite: "Slot is occupied. Overwrite?",
        copyYes:       "Yes",
        copyNo:        "No",
        deleteQuestion:"Are you sure to delete slot {0}?"
    }
};

function t(key) {
    return (LANG === 'EN' ? T.EN[key] : T.RU[key]) || key;
}

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

DataManager.maxSavefiles = function() { return 50; };

var _DataManager_makeSaveContents = DataManager.makeSaveContents;
DataManager.makeSaveContents = function() {
    var contents = _DataManager_makeSaveContents.call(this);
    if (DataManager._pendingNote) {
        contents.note = DataManager._pendingNote;
    } else {
        var globalInfo = DataManager.loadGlobalInfo();
        var id = DataManager._lastAccessedSavefileId;
        if (globalInfo && globalInfo[id] && globalInfo[id].note) {
            contents.note = globalInfo[id].note;
        }
    }
    DataManager._pendingNote = null;
    return contents;
};

var _DataManager_extractSaveContents = DataManager.extractSaveContents;
DataManager.extractSaveContents = function(contents) {
    _DataManager_extractSaveContents.call(this, contents);
    if (contents.note) {
        var id = DataManager._lastAccessedSavefileId;
        if (id) {
            var globalInfo = DataManager.loadGlobalInfo() || [];
            if (!globalInfo[id]) globalInfo[id] = {};
            globalInfo[id].note = contents.note;
            DataManager.saveGlobalInfo(globalInfo);
        }
    }
};

var _DataManager_loadDatabase = DataManager.loadDatabase;
DataManager.loadDatabase = function() {
    _DataManager_loadDatabase.call(this);
    BetterSaves.fixGlobalInfo();
};

var BetterSaves = {};

BetterSaves.noteInputMode   = false;
BetterSaves.noteInputText   = "";
BetterSaves.noteInputSlotId = 0;
BetterSaves.noteInputScene  = null;

BetterSaves.startNoteInput = function(scene, slotId) {
    var globalInfo = DataManager.loadGlobalInfo();
    var existingNote = (globalInfo && globalInfo[slotId] && globalInfo[slotId].note) ? globalInfo[slotId].note : "";

    BetterSaves.noteInputMode   = true;
    BetterSaves.noteInputText   = existingNote;
    BetterSaves.noteInputSlotId = slotId;
    BetterSaves.noteInputScene  = scene;

    if (scene._listWindow) {
        scene._listWindow.deactivate();
        scene._listWindow.refresh();
    }
};

BetterSaves.commitNoteInput = function() {
    var slotId = BetterSaves.noteInputSlotId;
    var note = BetterSaves.noteInputText.substring(0, NOTE_MAX_LEN);

    var globalInfo = DataManager.loadGlobalInfo() || [];
    if (!globalInfo[slotId]) globalInfo[slotId] = {};
    globalInfo[slotId].note = note;
    DataManager.saveGlobalInfo(globalInfo);

    BetterSaves.endNoteInput();
};

BetterSaves.cancelNoteInput = function() {
    BetterSaves.endNoteInput();
};

BetterSaves.endNoteInput = function() {
    var scene = BetterSaves.noteInputScene;
    BetterSaves.noteInputMode   = false;
    BetterSaves.noteInputText   = "";
    BetterSaves.noteInputSlotId = 0;
    BetterSaves.noteInputScene  = null;

    Input.clear();

    if (scene && scene._listWindow) {
        scene._listWindow.refresh();
        scene._listWindow.activate();
    }
};

BetterSaves.refreshNoteInput = function() {
    if (BetterSaves.noteInputScene && BetterSaves.noteInputScene._listWindow) {
        BetterSaves.noteInputScene._listWindow.refresh();
    }
};

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

var _makeSavefileInfo = DataManager.makeSavefileInfo;
DataManager.makeSavefileInfo = function() {
    var info = _makeSavefileInfo.call(this);
    var mapId = $gameMap ? $gameMap.mapId() : 0;
    info.mapId   = mapId;
    info.chapter = detectEpisode(mapId);

    var id = DataManager._lastAccessedSavefileId;
    if (id) {
        var globalInfo = DataManager.loadGlobalInfo();
        if (globalInfo && globalInfo[id] && globalInfo[id].note) {
            info.note = globalInfo[id].note;
        }
    }

    return info;
};

Window_SavefileList.prototype.savefileId = function() {
    return this.index();
};

var _Scene_Save_onSavefileOk = Scene_Save.prototype.onSavefileOk;
Scene_Save.prototype.onSavefileOk = function() {
    var index = this.savefileId();
    DataManager._lastAccessedSavefileId = index;
    DataManager._pendingNote = null;
    _Scene_Save_onSavefileOk.call(this);
};

var _Scene_Save_executeSave = Scene_Save.prototype.executeSave;
Scene_Save.prototype.executeSave = function(savefileId) {
    _Scene_Save_executeSave.call(this, savefileId);
    BetterSaves.startNoteInput(this, savefileId);
};

Window_SavefileList.prototype.drawGameTitle = function(info, x, y, width) {
    var episode = info.chapter || t('unknown');
    var mapId = (SHOW_MAPID && info.mapId) ? " [" + info.mapId + "]" : "";

    var currentSlotId = this._bsCurrentSavefileId;
    var isEditingThisSlot = BetterSaves.noteInputMode && currentSlotId === BetterSaves.noteInputSlotId;

    this.changeTextColor(this.normalColor());

    if (isEditingThisSlot) {
        var prefix = "[" + episode + "]" + "  —  ";
        this.drawText(prefix, x, y, width - 70);
        var prefixWidth = this.textWidth(prefix);
        this.changeTextColor(this.textColor(3));
        this.drawText(BetterSaves.noteInputText + "_", x + prefixWidth, y, width - 70 - prefixWidth);
        this.changeTextColor(this.normalColor());
    } else {
        var note = (info.note && info.note.trim()) ? "  —  " + info.note : "";
        this.drawText("[" + episode + "]" + note, x, y, width - 70);
    }

    this.changeTextColor(this.textColor(8));
    this.drawText(mapId, x + width - 70, y, 70, "right");
    this.changeTextColor(this.normalColor());
};

var _BS_Window_drawItem = Window_SavefileList.prototype.drawItem;
Window_SavefileList.prototype.drawItem = function(index) {
    this._bsCurrentSavefileId = index;
    _BS_Window_drawItem.call(this, index);
};

function Window_Confirm() {
    this.initialize.apply(this, arguments);
}
Window_Confirm.prototype = Object.create(Window_Command.prototype);
Window_Confirm.prototype.constructor = Window_Confirm;
Window_Confirm.prototype.initialize = function(x, y) {
    Window_Command.prototype.initialize.call(this, x, y);
    this._text = "";
    this._callbackYes = null;
    this._callbackNo = null;
    this.openness = 0;
};
Window_Confirm.prototype.windowWidth = function() { return 300; };
Window_Confirm.prototype.windowHeight = function() { return this.fittingHeight(3); };
Window_Confirm.prototype.numVisibleRows = function() { return 3; };
Window_Confirm.prototype.maxCommands = function() { return 3; };
Window_Confirm.prototype.makeCommandList = function() {
    this.addCommand(" ", 'text');
    this.addCommand(t('copyYes'), 'yes');
    this.addCommand(t('copyNo'),  'no');
};
Window_Confirm.prototype.setup = function(text, callbackYes, callbackNo) {
    this._text = text;
    this._callbackYes = callbackYes;
    this._callbackNo = callbackNo;
    this.select(1);
    this.refresh();
};
Window_Confirm.prototype.drawItem = function(index) {
    var rect = this.itemRectForText(index);
    this.changeTextColor(this.normalColor());
    if (index === 0) {
        this.changeTextColor(this.textColor(0));
        this.drawText(this._text, rect.x, rect.y, rect.width, 'center');
        this.changeTextColor(this.normalColor());
    } else {
        var symbol = this.commandSymbol(index);
        var name = (symbol === 'yes') ? t('copyYes') : t('copyNo');
        this.drawText(name, rect.x, rect.y, rect.width, 'center');
    }
};
Window_Confirm.prototype.isCommandEnabled = function(index) {
    return index !== 0;
};
Window_Confirm.prototype.processOk = function() {
    var symbol = this.currentSymbol();
    if (symbol === 'yes') {
        if (this._callbackYes) this._callbackYes();
        this.closeWindow();
    } else if (symbol === 'no') {
        if (this._callbackNo) this._callbackNo();
        this.closeWindow();
    }
};
Window_Confirm.prototype.closeWindow = function() {
    this.close();
    this.deactivate();
    var scene = SceneManager._scene;
    if (scene && scene._listWindow) {
        scene._listWindow.activate();
        scene._listWindow.refresh();
    }
};
Window_Confirm.prototype.update = function() {
    Window_Command.prototype.update.call(this);
    if (Input.isTriggered('cancel')) {
        if (this._callbackNo) this._callbackNo();
        this.closeWindow();
        Input.clear();
        TouchInput.clear();
    }
};

BetterSaves.copyMode = false;
BetterSaves.copySourceId = 0;
BetterSaves.copyDestinationId = 0;
BetterSaves.copyScene = null;
BetterSaves._copyPending = false;

BetterSaves.startCopy = function(scene, sourceId) {
    BetterSaves.copyMode = true;
    BetterSaves.copySourceId = sourceId;
    BetterSaves.copyDestinationId = 0;
    BetterSaves.copyScene = scene;
    BetterSaves._copyPending = false;

    Input.clear();
    TouchInput.clear();

    if (scene._actionWindow) {
        scene._actionWindow.hide();
        scene._actionWindow.deactivate();
    }

    if (scene._listWindow) {
        scene._listWindow.refresh();
        scene._listWindow.activate();
    }
};

BetterSaves.cancelCopy = function() {
    BetterSaves.copyMode = false;
    BetterSaves.copySourceId = 0;
    BetterSaves.copyDestinationId = 0;
    BetterSaves._copyPending = false;
    var scene = BetterSaves.copyScene;
    BetterSaves.copyScene = null;
    if (scene && scene._listWindow) {
        scene._listWindow.refresh();
        scene._listWindow.activate();
    }
    Input.clear();
    TouchInput.clear();
};

BetterSaves.tryCopyToSlot = function(destId) {
    if (!BetterSaves.copyMode) return;
    if (BetterSaves._copyPending) return;

    var srcId = BetterSaves.copySourceId;
    if (destId === srcId) {
        return;
    }

    BetterSaves._copyPending = true;

    var globalInfo = DataManager.loadGlobalInfo() || [];
    var occupied = !!globalInfo[destId] && globalInfo[destId].hasOwnProperty('mapId');

    if (!occupied) {
        BetterSaves.performCopy(srcId, destId);
        BetterSaves.cancelCopy();
        BetterSaves._copyPending = false;
        return;
    } else {
        BetterSaves.copyDestinationId = destId;
        if (BetterSaves.copyScene && BetterSaves.copyScene._confirmWindow) {
            BetterSaves.copyScene._confirmWindow.setup(
                t('copyOverwrite'),
                function() {
                    var src = BetterSaves.copySourceId;
                    var dest = BetterSaves.copyDestinationId;
                    BetterSaves.performCopy(src, dest);
                    BetterSaves.cancelCopy();
                    BetterSaves._copyPending = false;
                },
                function() {
                    BetterSaves.copyDestinationId = 0;
                    BetterSaves._copyPending = false;
                    if (BetterSaves.copyScene && BetterSaves.copyScene._listWindow) {
                        BetterSaves.copyScene._listWindow.refresh();
                    }
                }
            );
            BetterSaves.copyScene._confirmWindow.show();
            BetterSaves.copyScene._confirmWindow.open();
            BetterSaves.copyScene._confirmWindow.activate();
            if (BetterSaves.copyScene._listWindow) BetterSaves.copyScene._listWindow.deactivate();
        }
        BetterSaves._copyPending = false;
    }
};

BetterSaves.performCopy = function(srcId, destId) {
    var srcData = StorageManager.load(srcId);
    if (srcData) {
        StorageManager.save(destId, srcData);
        var globalInfo = DataManager.loadGlobalInfo() || [];
        if (globalInfo[srcId]) {
            globalInfo[destId] = JsonEx.makeDeepCopy(globalInfo[srcId]);
        } else {
            try {
                var data = JSON.parse(srcData);
                var mapId = data.map ? data.map._mapId : 0;
                var chapter = detectEpisode(mapId);
                var note = data.note || '';
                globalInfo[destId] = {
                    mapId: mapId,
                    chapter: chapter,
                    note: note,
                    timestamp: data.timestamp || Date.now()
                };
            } catch(e) {
                var srcInfo = DataManager.loadSavefileInfo(srcId);
                globalInfo[destId] = JsonEx.makeDeepCopy(srcInfo);
            }
        }
        DataManager.saveGlobalInfo(globalInfo);
        SoundManager.playSave();
        if (BetterSaves.copyScene && BetterSaves.copyScene._listWindow) {
            BetterSaves.copyScene._listWindow.refresh();
        }
    } else {
        console.warn('BetterSaves: cannot load source save file', srcId);
    }
};

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
    this._actionWindow.setHandler("cancel", this.onActionCancel.bind(this));
    this.addWindow(this._actionWindow);

    this._confirmWindow = new Window_Confirm(0, 0);
    this._confirmWindow.x = (Graphics.width - this._confirmWindow.windowWidth()) / 2;
    this._confirmWindow.y = (Graphics.height - this._confirmWindow.windowHeight()) / 2;
    this._confirmWindow.openness = 0;
    this.addWindow(this._confirmWindow);
};

var _Scene_Load_terminate = Scene_Load.prototype.terminate;
Scene_Load.prototype.terminate = function() {

    if (BetterSaves.copyMode) {
        BetterSaves.cancelCopy();
    }

    if (BetterSaves.noteInputMode) {
        BetterSaves.cancelNoteInput();
    }

    _Scene_Load_terminate.call(this);
};

var _Scene_Load_update = Scene_Load.prototype.update;
Scene_Load.prototype.update = function() {
    _Scene_Load_update.call(this);

    if (this._confirmWindow && this._confirmWindow.active) {
        return;
    }

    if (BetterSaves.copyMode) {
        if (Input.isTriggered('cancel')) {
            BetterSaves.cancelCopy();
            Input.clear();
            TouchInput.clear();
            return;
        }
        if (this._listWindow) this._listWindow.refresh();
        return;
    }

    if (BetterSaves.noteInputMode) {
        Input.clear();
        if (this._listWindow) this._listWindow.refresh();
        return;
    }
};

var _orig_onSavefileOk = Scene_Load.prototype.onSavefileOk;
Scene_Load.prototype.onSavefileOk = function() {
    if (BetterSaves.copyMode) {
        var id = this.savefileId();
        if (id !== BetterSaves.copySourceId) {
            BetterSaves.tryCopyToSlot(id);
        }
        return;
    }

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

Scene_Load.prototype.onActionCopy = function() {
    var id = this.savefileId();
    this._actionWindow.hide();
    BetterSaves.startCopy(this, id);
};

Scene_Load.prototype.onActionDelete = function() {
    var id = this.savefileId();
    this._actionWindow.hide();
    var self = this;
    if (this._confirmWindow) {
        this._confirmWindow.setup(
            t('deleteQuestion').replace('{0}', id),
            function() {
                StorageManager.remove(id);
                var globalInfo = DataManager.loadGlobalInfo() || [];
                globalInfo[id] = null;
                DataManager.saveGlobalInfo(globalInfo);
                SoundManager.playLoad();
                if (self._listWindow) self._listWindow.refresh();
                self._listWindow.activate();
            },
            function() {
                self._listWindow.activate();
            }
        );
        this._confirmWindow.show();
        this._confirmWindow.open();
        this._confirmWindow.activate();
        if (this._listWindow) this._listWindow.deactivate();
    }
};

Scene_Load.prototype.onActionLoad = function() {
    var id = this.savefileId();
    DataManager._lastAccessedSavefileId = id;
    this._actionWindow.hide();
    if (_orig_onSavefileOk) {
        _orig_onSavefileOk.call(this);
    } else {
        DataManager.loadGame(id);
        SoundManager.playLoad();
        this.fadeOutAll();
        SceneManager.goto(Scene_Map);
    }
};

Scene_Load.prototype.onActionEdit = function() {
    var id = this.savefileId();
    this._actionWindow.hide();
    BetterSaves.startNoteInput(this, id);
};

Scene_Load.prototype.onActionCancel = function() {
    this._actionWindow.hide();
    this._listWindow.activate();
};

function Window_SaveAction() { this.initialize.apply(this, arguments); }
Window_SaveAction.prototype = Object.create(Window_Command.prototype);
Window_SaveAction.prototype.constructor = Window_SaveAction;
Window_SaveAction.prototype.initialize = function(x, y) {
    Window_Command.prototype.initialize.call(this, x, y);
    this.openness = 255;
};
Window_SaveAction.prototype.windowWidth    = function() { return 220; };
Window_SaveAction.prototype.numVisibleRows = function() { return 5; };
Window_SaveAction.prototype.makeCommandList = function() {
    this.addCommand(t('cmdLoad'),   "load");
    this.addCommand(t('cmdCopy'),   "copy");
    this.addCommand(t('cmdDelete'), "delete");
    this.addCommand(t('cmdEdit'),   "edit");
    this.addCommand(t('cmdCancel'), "cancel");
};

var _Window_Options_addGeneralOptions = Window_Options.prototype.addGeneralOptions;
Window_Options.prototype.addGeneralOptions = function() {
    _Window_Options_addGeneralOptions.call(this);
    this.addCommand(t('langLabel'), 'betterSavesLang');
};

var _Window_Options_statusText = Window_Options.prototype.statusText;
Window_Options.prototype.statusText = function(index) {
    var symbol = this.commandSymbol(index);
    if (symbol === 'betterSavesLang') {
        return LANG;
    }
    return _Window_Options_statusText.call(this, index);
};

var _Window_Options_processOk = Window_Options.prototype.processOk;
Window_Options.prototype.processOk = function() {
    var index = this.index();
    var symbol = this.commandSymbol(index);
    if (symbol === 'betterSavesLang') {
        this.toggleLang();
        return;
    }
    _Window_Options_processOk.call(this);
};

var _Window_Options_cursorRight = Window_Options.prototype.cursorRight;
Window_Options.prototype.cursorRight = function(wrap) {
    var symbol = this.commandSymbol(this.index());
    if (symbol === 'betterSavesLang') { this.toggleLang(); return; }
    _Window_Options_cursorRight.call(this, wrap);
};

var _Window_Options_cursorLeft = Window_Options.prototype.cursorLeft;
Window_Options.prototype.cursorLeft = function(wrap) {
    var symbol = this.commandSymbol(this.index());
    if (symbol === 'betterSavesLang') { this.toggleLang(); return; }
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
    if (config.betterSavesLang) {
        LANG = config.betterSavesLang;
    }
};

document.addEventListener('keydown', function(e) {
    if (!BetterSaves.noteInputMode) return;

    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();

    if (e.key === "Escape") {
        BetterSaves.cancelNoteInput();
        return;
    }

    if (e.key === "Enter") {
        BetterSaves.commitNoteInput();
        return;
    }

    if (e.key === "Backspace") {
        BetterSaves.noteInputText = BetterSaves.noteInputText.slice(0, -1);
        var scene = BetterSaves.noteInputScene;
        if (scene && scene._listWindow) {
            scene._listWindow.refresh();
        }
        return;
    }

    if (e.key.length === 1 && BetterSaves.noteInputText.length < NOTE_MAX_LEN) {
        BetterSaves.noteInputText += e.key;
        var scene = BetterSaves.noteInputScene;
        if (scene && scene._listWindow) {
            scene._listWindow.refresh();
        }
    }
}, true);

})();
