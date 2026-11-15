# Art style guide (for AI image generators)

The game ships with code-drawn art. Every background can be replaced with a PNG, and the game picks
it up automatically. The rule that keeps everything consistent is simple: **one palette, one
resolution, one prompt template.**

## The rules

1. **Palette:** use only the 16 colours in `scripts/pal.gd`:
   `2a2230 3466c2 4c9a3c 3fb6c4 d6453d a24ab0 a8662c c9c6c0 6b6670 7fa8ff 8fd65a a6e4f2 ff7f6e ff8fd0 ffd84a fbfaf5`.
   Shading is a soft vertical gradient between two of them. Never use texture, noise or photo detail.
2. **Look:** flat 2D cartoon. Rounded shapes, dark ink outlines (`#2a2230`, about 3px at full
   size), chunky friendly proportions, and a little highlight on round things.
3. **Size:** 1280x680 for rooms and building fronts, 1280x600 for cutscenes. The game draws them
   into 640x340 / 640x300 logical units, rendered at 2x.
4. **View:** flat side view at eye level. The back wall or building front fills the top 75%, and the
   floor or parking lot is the bottom strip.
5. **Leave out** people, text, signs with words, and the front door of entry rooms. The game draws
   those on top, along with the disaster, Jim, the customers and the shop names.
6. **Clean it up after generating.** Run a palette-reduction pass so the colours stay on-model,
   for example `magick in.png -resize 1280x680! +dither -remap palette.png out.png`, where
   `palette.png` is a 16-pixel strip of the palette.

## The prompt template

> flat 2D cartoon illustration, side view background for a comedy adventure game, bold dark
> outlines, rounded chunky shapes, soft simple gradients, limited 16-colour palette, warm and
> friendly, no characters, no text, **[SUBJECT]**, small-town Wisconsin, slightly run-down and cosy

Negative prompt: `photo, realistic, 3d render, pixel art, noise, texture, people, text, letters, watermark`

## File names the game looks for

Put the files in `art/rooms/`, then open the project in the Godot editor once so it imports them.

| File | Subject for the prompt |
|---|---|
| `outside_shop.png` | small red-brick handyman workshop, roll-up door, flag pole, gravel lot |
| `outside_hardware.png` | brick hardware store front, display windows, parking lot |
| `outside_plumbing.png` | blue-sided plumbing supply store, pipes stacked outside |
| `outside_electric.png` | yellow electrical supply store, cable spools out front |
| `outside_lumber.png` | lumber yard with an open shed and stacked boards |
| `outside_farm.png` | red farm-and-feed store with a barn roof, feed bags, pallets |
| `outside_gas.png` | small-town gas station and convenience store, two pumps |
| `outside_bank.png` | stone small-town bank with columns and a flag pole |
| `outside_police.png` | one-storey brick police station, flag pole, chain-link fenced lot |
| `outside_tavern.png` | wood-sided corner tavern, neon beer sign shapes (no words) |
| `outside_house.png` | modest one-storey house with siding, front lawn, mailbox (used for every customer) |
| `room_living_room.png` | wood-panelled living room, couch, old TV, mounted deer head |
| `room_kitchen.png` | 1970s kitchen, avocado fridge, laminate counter, cabinets |
| `room_bathroom.png` | tiled bathroom, tub, sink, mirror (no toilet - the game draws it if needed) |
| `room_bedroom.png` | bedroom with striped wallpaper, bed, dresser |
| `room_basement.png` | unfinished basement, concrete, water heater, shelves of canned goods |
| `room_garage.png` | garage interior, workbench, pegboard tools |
| `room_attic.png` | attic with sloped roof beams, boxes |
| `room_back_deck.png`, `room_back_yard.png` | back yard with a white picket fence and an oak tree |
| `room_workshop.png` | Jim's workshop: pegboard wall of tools, workbench on the right |
| `room_bunkroom.png` | back room with a cot, a small TV, empty beer cans |
| `room_hardware.png` etc. | store interior, shelves on the left, counter on the right third |
| `room_bank.png`, `room_police.png`, `room_tavern.png`, `room_gas.png` | as above, counter on the right third |
| `cut_sleep.png`, `cut_tv.png`, `cut_fishfry.png`, `cut_bar.png`, `cut_fishing.png`, `cut_hunting.png`, `cut_broke.png`, `cut_arrest.png`, `cut_title.png` | the matching scene, 640x300 |

Anything you leave out keeps its code-drawn version, so you can replace the art one picture at a time.

## Layout coordinates (640x340 space)

- Coordinates are the logical 640x340 space (double them for the 1280x680 image).
- Floor line: y = 248. Jim's feet are at y = 318 indoors and y = 330 outside.
- The entry-room front door is at x = 150. The counter, or the disaster, is at x = 450 to 650.
- The doors to neighbouring rooms are the left and right 36 pixels. Keep those strips plain.
