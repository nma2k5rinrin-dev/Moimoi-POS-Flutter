import urllib.request
import os

os.makedirs('assets/sounds', exist_ok=True)

# Download high quality free notification sounds (from free/open domains)
url_bell = "https://raw.githubusercontent.com/google/material-design-icons/master/sounds/navigation/navigation_transition-left.ogg" 
url_chime = "https://raw.githubusercontent.com/google/material-design-icons/master/sounds/navigation/navigation_transition-right.ogg"

# Actually wait, audioplayers supports .wav and .mp3. Let's get generic wavs or mp3s.
# To be safe, let's use some reliable raw URLs:
url1 = "https://actions.google.com/sounds/v1/alarms/beep_short.ogg"
url2 = "https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg"

# Wait, OGG might not be fully supported by all browsers for AudioPlayers. 
# Let's download a small MP3 or WAV. 
# Another approach: create an empty AudioContext buffer in JS?
# Let's just download some sample wav files:
url_bell_wav = "https://cdn.freesound.org/previews/337/337049_3232293-hq.mp3"
url_chime_wav = "https://cdn.freesound.org/previews/415/415510_5121236-hq.mp3"

import urllib.error

try:
    urllib.request.urlretrieve(url_bell_wav, "assets/sounds/bell.wav")
    urllib.request.urlretrieve(url_chime_wav, "assets/sounds/chime.wav")
    print("Downloaded real sounds.")
except Exception as e:
    print(f"Error: {e}")
