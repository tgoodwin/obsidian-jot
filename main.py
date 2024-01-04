import os
from datetime import datetime
import rumps
from quickmachotkey import quickHotKey, mask
from quickmachotkey.constants import kVK_ANSI_J, cmdKey, optionKey, controlKey, shiftKey

NOTES_DIR = '/Users/tgoodwin/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian-vault/daily notes'

DAY_FMT = '%Y-%m-%d'

class JotStatusBarApp(rumps.App):
    @rumps.clicked("Preferences")
    def prefs(self, _):
        rumps.alert("Opening Preferences")

    @rumps.clicked("Add to daily note")
    def sayhi(self, _):
        window = rumps.Window(title="Jot", message="Add to a daily note", cancel="Cancel")
        response = window.run()
        res = response.text

        # discard empty responses
        if len(res.strip()) > 0:
            self.write_text(res)


    def write_text(self, text):
        day_file = datetime.today().strftime(DAY_FMT) + '.md'
        path = os.path.join(NOTES_DIR, day_file)
        print(f"writing to {path}")
        with open(path, 'a') as f:
            f.write('\n' + text + '\n')


@quickHotKey(virtualKey=kVK_ANSI_J, modifierMask=mask(cmdKey, optionKey, controlKey))
def handler():
    app.sayhi(None)

if __name__ == '__main__':
    app = JotStatusBarApp("Jot")
    app.run()

    from AppKit import NSApplication
    from PyObjCTools import AppHelper
    NSApplication.sharedApplication()
    AppHelper.runEventLoop()

