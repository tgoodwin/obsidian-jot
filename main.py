import os
from datetime import datetime
import rumps
from quickmachotkey import quickHotKey, mask
from quickmachotkey.constants import kVK_ANSI_J, cmdKey, optionKey, controlKey


NOTES_DIR = '/Users/tgoodwin/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian-vault/daily notes'

DAY_FMT = '%Y-%m-%d'

class JotStatusBarApp(rumps.App):
    def __init__(self):
        super(JotStatusBarApp, self).__init__("Jot", "📝")
        self.note_dir = NOTES_DIR
        self.day_fmt = DAY_FMT

    def save_preferences(self):
        pref_file = os.path.join(rumps.application_support("Jot"), 'settings.json')
        with open(pref_file, 'w') as f:
            f.write(json.dumps({'note_dir': self.note_dir, 'day_fmt': self.day_fmt}))

    @rumps.clicked("Preferences")
    def prefs(self, _):
        # TODO
        rumps.alert("Opening Preferences")
        print(rumps.application_support("Jot"))
        self.save_preferences()

    @rumps.clicked("Add to daily note")
    def open_note_input(self, _):
        window = rumps.Window(title="Obsidian Jot", message="Add to a daily note", cancel="Cancel")
        response = window.run()
        res = response.text

        # discard empty responses
        if len(res.strip()) > 0:
            self.write_text(res)


    def write_text(self, text):
        day_file = datetime.today().strftime(self.day_fmt) + '.md'
        note_path = os.path.join(self.note_dir, day_file)
        print(f"writing to {note_path}")
        with open(note_path, 'a') as f:
            f.write('\n' + text + '\n')


# TODO: make this configurable
@quickHotKey(virtualKey=kVK_ANSI_J, modifierMask=mask(cmdKey, optionKey, controlKey))
def handler():
    app.open_note_input(None)

if __name__ == '__main__':
    app = JotStatusBarApp()
    app.run()

    from AppKit import NSApplication
    from PyObjCTools import AppHelper
    NSApplication.sharedApplication()
    AppHelper.runEventLoop()
