import os
from datetime import datetime
import rumps

NOTES_DIR = '/Users/tgoodwin/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian-vault/daily notes'

DAY_FMT = '%Y-%m-%d'

class JotStatusBarApp(rumps.App):
    @rumps.clicked("Preferences")
    def prefs(self, _):
        rumps.alert("Opening Preferences")

    @rumps.clicked("Add to daily note")
    def sayhi(self, _):
        window = rumps.Window(title="Jot", message="Add to a daily note")
        response = window.run()
        res = response.text
        self.write_text(res)


    def write_text(self, text):
        day_file = datetime.today().strftime(DAY_FMT) + '.md'
        path = os.path.join(NOTES_DIR, day_file)
        print(f"writing to {path}")
        with open(path, 'a') as f:
            f.write('\n' + text + '\n')

if __name__ == '__main__':
    JotStatusBarApp("Jot").run()

