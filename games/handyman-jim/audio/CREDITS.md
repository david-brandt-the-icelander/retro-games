# Audio credits

`voice.wav` is 16 seconds of a LibriVox recording, muffled so the words cannot be made out. The game
plays random 150 ms slices of it, pitch-shifted per speaker, as the "bla-bla" while characters talk.

- **Source:** "Curried Cow" by Ambrose Bierce, read for LibriVox, from *Short Story Collection
  Vol. 046*: <https://archive.org/details/short_story_046_1010_librivox>, file
  `shortstory046_curriedcow_dl_64kb.mp3`, 1:15 to 1:31.
- **Licence:** public domain. LibriVox recordings are dedicated to the public domain, and the
  archive.org item carries the Public Domain Mark 1.0
  (<http://creativecommons.org/publicdomain/mark/1.0/>).
- **Processing:** mono, 22 050 Hz; high-pass at 140 Hz, two low-pass passes at 950 Hz (the
  muffling), compression and loudness normalisation, all with ffmpeg:
  `ffmpeg -ss 75 -t 16 -i in.mp3 -ac 1 -ar 22050 -af "highpass=f=140,lowpass=f=950,lowpass=f=950,acompressor=threshold=-24dB:ratio=4,loudnorm=I=-18" voice.wav`

The phone ring and the horn are synthesised in `scripts/sfx.gd` and have no source recording.
