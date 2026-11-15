# Audio credits

`voice.wav` is 45 seconds of a LibriVox recording, stored backwards and heavily muffled, so it keeps a
real voice's tone and rhythm while no word can be understood. While a line of dialog types out, the
game plays it from the start of a random phrase, slowed and deepened to that speaker's pitch.

- **Source:** "Curried Cow" by Ambrose Bierce, read for LibriVox, from *Short Story Collection
  Vol. 046*: <https://archive.org/details/short_story_046_1010_librivox>, file
  `shortstory046_curriedcow_dl_64kb.mp3`, 1:15 to 2:00.
- **Licence:** public domain. LibriVox recordings are dedicated to the public domain, and the
  archive.org item carries the Public Domain Mark 1.0
  (<http://creativecommons.org/publicdomain/mark/1.0/>).
- **Processing:** mono, 22 050 Hz; reversed, high-pass at 100 Hz, two low-pass passes at 650 Hz
  (the muffling), compression and loudness normalisation, all with ffmpeg:
  `ffmpeg -ss 75 -t 45 -i in.mp3 -ac 1 -ar 22050 -af "areverse,highpass=f=100,lowpass=f=650,lowpass=f=650,acompressor=threshold=-24dB:ratio=4,loudnorm=I=-18" voice.wav`

The phone ring and the horn are synthesised in `scripts/sfx.gd` and have no source recording.
