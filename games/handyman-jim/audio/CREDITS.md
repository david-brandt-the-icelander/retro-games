# Audio credits

`voice.wav` is 45 seconds of a LibriVox recording, muffled so the words cannot be made out. While a
character's line types out, the game plays it from the start of a random phrase, as whole words,
slowed and deepened to that speaker's pitch, so it sounds like people talking behind a wall.

- **Source:** "Curried Cow" by Ambrose Bierce, read for LibriVox, from *Short Story Collection
  Vol. 046*: <https://archive.org/details/short_story_046_1010_librivox>, file
  `shortstory046_curriedcow_dl_64kb.mp3`, 1:15 to 2:00.
- **Licence:** public domain. LibriVox recordings are dedicated to the public domain, and the
  archive.org item carries the Public Domain Mark 1.0
  (<http://creativecommons.org/publicdomain/mark/1.0/>).
- **Processing:** mono, 22 050 Hz; high-pass at 120 Hz, two low-pass passes at 900 Hz (the
  muffling), compression and loudness normalisation, all with ffmpeg:
  `ffmpeg -ss 75 -t 45 -i in.mp3 -ac 1 -ar 22050 -af "highpass=f=120,lowpass=f=900,lowpass=f=900,acompressor=threshold=-24dB:ratio=4,loudnorm=I=-18" voice.wav`

The phone ring and the horn are synthesised in `scripts/sfx.gd` and have no source recording.
