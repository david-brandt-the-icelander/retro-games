# Advent Calendar

A storybook Advent calendar for phones and desktop browsers. One file, no build step, no server.

A snowy timber house has 24 red shuttered windows. Tapping one peels the shutter open and the window grows into a framed card where a friend does one short animation: it waves, plays peek-a-boo, throws a snowball at the screen, sings. The animation plays once and the character then follows the finger with its eyes. Tapping the card closes the window, and tapping the window again replays it.

## Running it

Open `index.html` in a browser. Nothing is installed or fetched except the two Google Fonts.

## Dates

Window N opens on N December. Before December, and after it, the page starts in preview mode with every window open; the switch under the house turns real dates on. Opened windows and the switch are remembered in `localStorage`.

## How it is drawn

Everything is drawn in code on canvas: the house, the 24 scenes and the characters. `creature()` draws every character from a table of species (body, ears, nose, hat and so on) plus a pose. Each scene is a short function of time `t` that builds a pose and adds props. `?sheet=3.5` draws all 24 cards at 3.5 seconds into one image, for checking them.

It has no `package.json`, so the deploy workflow does not build or deploy it.
