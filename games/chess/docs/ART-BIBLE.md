# Gambit: art bible

The look of the 3D table and the pieces, the motion, and the sound. The screens around the table are in [UI-DESIGN.md](UI-DESIGN.md); the exact values for both are also in [design-tokens.json](design-tokens.json). Reference renders are in [screens/](screens/) (see [DESIGN.md](DESIGN.md) for how to compare against them).

**Mood:** a quiet, expensive chess table at night. A near-black room, one warm key light from the player's front left, a cool blue rim light from behind, a faint warm fill. Ivory pieces with a soft satin finish; black pieces like polished obsidian with sharp highlights. A slate-and-bone board in a black lacquered frame with a thin gold inlay. Nothing glows except the move hints and the check warning.

## World units

One board square is **1 unit**. The board's centre is the origin; up is +Y. Square *(file f, rank r)*, with f = 0 for the a-file and r = 0 for rank 1, has its centre at

```
x = f − 3.5      y = 0      z = 3.5 − r
```

so White's first rank is at +Z (towards the camera when playing White) and the a-file at −X.

## Environment

| Property | Value |
|---|---|
| Renderer | Godot Compatibility (WebGL 2) |
| Background | flat colour `#0B0C0F` (the sky below is used for light only, never seen) |
| Sky (for ambient and reflections) | procedural: top `#2A2F3A`, horizon `#5A5248`, ground horizon `#3A342E`, ground bottom `#0C0D10`, sun disc max angle 30° |
| Ambient light | from the sky, energy 0.55 |
| Reflections | from the sky |
| Tone mapping | Filmic, exposure 1.05 |
| Glow | on: intensity 0.5, bloom 0.04, HDR threshold 1.1 |
| Anti-aliasing | MSAA 4× on the 3D viewport |
| Shadows | directional shadow map 4096, soft shadow filter quality "high" (3) |

## Lights

All three lights sit in one **light rig** that turns about the Y axis with the camera (rig yaw = camera yaw). The table is therefore lit the same way whichever side the player sits on: the key light always comes from the player's front left.

| Light | Type | Position / rotation (rig space) | Colour | Energy | Other |
|---|---|---|---|---|---|
| Key | directional | rotation (−58°, −32°, 0°) | `#FFF1DC` | 1.15 | shadows on, blur 1.6, max distance 30, bias 0.03 |
| Rim | omni | (−6, 5, −7) | `#8FB3FF` | 1.4 | range 22 |
| Fill | omni | (7, 4, 6) | `#FFCF8A` | 0.7 | range 20 |

## The table

| Part | Geometry | Material (all PBR, Schlick-GGX specular) |
|---|---|---|
| Table top | plane 80 × 80 at y = −0.42 | albedo `#121317`, roughness 0.55 |
| Board frame | box 9.5 × 0.4 × 9.5, centre y = −0.22 (top face at −0.02) | black lacquer: albedo `#17181D`, roughness 0.16, metallic 0.2 |
| Gold inlay | four bars, 0.035 wide × 0.012 high, 8.32 long, centred 4.13 from the middle on each side, at y = −0.015 | albedo `#D9B26B`, roughness 0.3, metallic 1.0 |
| Squares | 64 boxes 1 × 0.04 × 1, top face at y = 0 | light (bone): `#B3AB9B`, roughness 0.55. Dark (slate): `#353A42`, roughness 0.26, metallic 0.15. a1 is **dark**: a square is light when (f + r) is odd |
| Coordinates | the letters a–h along both long edges at z = ±4.45, the numbers 1–8 along both side edges at x = ±4.45, lying flat 0.002 above the frame | Inter SemiBold, font size 48, pixel size 0.004 (≈ 0.19 units tall), colour `#D9B26B` at 75 % opacity. They always read upright from the player's side: turned 180° about Y when the camera is behind Black |

## Pieces

Two materials, one per side, applied to the whole piece:

| Side | Albedo | Roughness | Metallic |
|---|---|---|---|
| White ("ivory") | `#E0D8C6` | 0.30 | 0 |
| Black ("obsidian") | `#1D1E24` | 0.18 | 0.35 |

### Turned pieces

Pawn, rook, bishop, queen and king are surfaces of revolution: a profile of points *(radius, height)* in units, turned about the Y axis in **48 segments**. Normals are smooth, from the profile's slope; a point listed twice makes a crisp edge there (the normal on each side of it follows its own segment). The profile starts at the axis on the table (0, 0) and works upward.

**The foot**, shared by all, for a foot radius *R*:

```
(0, 0) (R, 0) (R, 0.035) (R−0.01, 0.055) (R−0.03, 0.07) (R−0.03, 0.07)* (R−0.05, 0.095) (R−0.07, 0.12)
```

`*` = repeated point (crisp edge). Each piece's profile is the foot followed by its own points. `arc(cy, r, a0→a1, n)` means n+1 points on a circle of radius r centred on the axis at height cy, from angle a0 to a1 in degrees (0° points outward, 90° straight up), i.e. *(r·cos a, cy + r·sin a)*.

| Piece | R | Profile after the foot | Extras |
|---|---|---|---|
| Pawn | 0.32 | (0.22,0.15) (0.15,0.2) (0.11,0.3) (0.09,0.4) (0.15,0.43) (0.16,0.455) (0.15,0.475) (0.08,0.49), then arc(0.6, 0.135, −55°→90°, 12) | — |
| Rook | 0.36 | (0.26,0.15) (0.21,0.2) (0.19,0.3) (0.185,0.55) (0.21,0.58) (0.255,0.6)* (0.255,0.74)* (0.17,0.74)* (0.17,0.71) (0,0.71) | six merlons: flat-shaded boxes 0.085 (radial) × 0.1 (high) × 0.13 (tangential), centred at radius 0.212, height 0.79, at angles 0°, 60° … 300° |
| Bishop | 0.34 | (0.24,0.15) (0.15,0.22) (0.11,0.35) (0.095,0.52) (0.17,0.56) (0.175,0.585) (0.16,0.6) (0.1,0.615) (0.135,0.66) (0.158,0.72) (0.15,0.79) (0.12,0.86) (0.075,0.915) (0.035,0.94), then arc(0.975, 0.045, −50°→90°, 8) | — |
| Queen | 0.37 | (0.27,0.15) (0.17,0.24) (0.125,0.4) (0.11,0.62) (0.19,0.67) (0.2,0.7) (0.185,0.72) (0.115,0.74) (0.13,0.82) (0.2,0.96) (0.215,0.99) (0.2,1.0) (0.15,0.99) (0.1,1.03) (0.05,1.05), then arc(1.09, 0.05, −50°→90°, 8) | a crown of nine spheres, radius 0.03, at radius 0.2, height 1.015, every 40° |
| King | 0.38 | (0.28,0.15) (0.18,0.25) (0.13,0.42) (0.115,0.68) (0.2,0.73) (0.21,0.76) (0.195,0.78) (0.12,0.8) (0.135,0.88) (0.19,1.04)* (0.19,1.07)* (0.15,1.1) (0.08,1.13) (0,1.14) | a cross of two flat-shaded boxes: upright 0.06 × 0.24 × 0.06 centred at height 1.25; bar 0.17 × 0.06 × 0.06 centred at 1.27 |

Heights, for orientation: pawn ≈ 0.74, bishop ≈ 1.02, rook 0.84, queen ≈ 1.14, king ≈ 1.39, knight ≈ 1.0.

### The knight

A turned base, then a horse's head built by sweeping ovals along a curved spine. The head faces **+X** in its own space.

- **Base:** the foot with R = 0.36, then (0.27, 0.15) (0.24, 0.19) (0, 0.19).
- **Spine:** a cubic Bézier in the XY plane (side view) through P0 (0, 0.17), P1 (−0.09, 0.6), P2 (0, 0.92), P3 (0.36, 0.66): up the neck, over the poll, forward and down to the muzzle. Sample it at 27 points (t = 0 … 1 in 26 steps).
- **Cross-sections:** at each sample, an ellipse of 28 points in the plane perpendicular to the spine. Its half-axis in the side view (front to back) is *depth(t)*, perpendicular to the side view (the head's half-width) is *width(t)*:

  ```
  depth(t) = 0.20 + 0.05·exp(−((t − 0.12) / 0.12)²) − 0.11·smoothstep(0.35, 1.0, t)
  width(t) = 0.135 − 0.05·smoothstep(0.3, 1.0, t)
  ```
  The bump at t ≈ 0.12 is the chest. Normals are the ellipse's: (n·cos θ / depth, sin θ / width), normalised, where n is the in-profile perpendicular to the spine.
- **Muzzle:** closed with a fan to a point 0.05 beyond the last sample along the spine's tangent.
- **Ears:** two cones, base radius 0.035, 10 segments, set 0.05 behind and 0.06 above the spine at sample 18 (t ≈ 0.69), at z = ±0.045, each pointing along (−0.04, 0.14, ±0.015) (up, slightly back and outward).
- **Mane:** fourteen flat-shaded boxes 0.05 × 0.035 × 0.05 along the back of the neck, at samples 3 … 16, each sitting on the surface (at depth(t) − 0.012 behind the spine).

**Facing on the board:** knights look ahead and in towards the centre, so their profile shows. Rotation about Y: a white knight on files a–d gets **+38°**, on files e–h **180° − 38° = 142°**; a black knight on files a–d **−38°**, on e–h **180° + 38°**. (Facing is set when the piece is placed; a knight keeps its facing as it moves.)

Reference: [screens/23-pieces.png](screens/23-pieces.png).

## Marks on the board

All marks are unshaded, transparent, double-sided, drawn just above the squares.

| Mark | Shape | Colour | Height |
|---|---|---|---|
| Last move | the from and to squares, planes 1 × 1 | gold `#D9B26B` at 22 % | y = 0.003 |
| Selected piece | its square, plane 0.98 × 0.98 | gold at 55 % | y = 0.004 |
| A move to an empty square | disc: cylinder radius 0.11, height 0.01 | gold at 75 %, emissive | y = 0.01 |
| A capture | ring: torus inner radius 0.36, outer 0.44, 32 rings | gold at 75 %, emissive | y = 0.01 |
| King in check | its square, plane 0.96 × 0.96 | `#FF3B4E`, opacity pulsing 0.35 ± 0.2 (sine, 5 rad/s) | y = 0.004 |

Reference: [screens/14-game-piece-selected.png](screens/14-game-piece-selected.png) (dots), [screens/13-game-check.png](screens/13-game-check.png) (check, last move).

## Camera

A camera on a pivot at the origin. The pivot turns about Y (*yaw*); the camera sits at distance *d* and pitch *p* above the board, looking at the origin:

```
camera position (pivot space) = (0, sin p · d, cos p · d)      look at (0, 0, 0)
```

| Property | Value |
|---|---|
| Field of view | 34° (vertical) |
| Pitch | 52° (the player may drag it within 28°–82°) |
| Yaw | 0 behind White, 180° behind Black; turns the short way round |
| Horizontal offset | the camera's h_offset = *s · d · 0.62*: positive moves the board left on screen |
| Distance and offset per screen | game and replay: d = 15, s = 0.2 · title screen: d = 15.5, s = −0.2 (board to the right of the title) · other screens: d = 14, s = 0 |
| Title screen | the yaw turns slowly, +0.08 rad/s, forever |
| Smoothing | each frame yaw moves towards its target by 1 − e^(−5Δt), distance by 1 − e^(−6Δt); offset changes tween over 0.6 s (cubic) |
| Player control | right-drag or drag on the empty table: yaw −0.006 rad and pitch +0.004 rad per pixel; wheel: distance ∓0.6, within 8–18 |

## Motion

| What | How |
|---|---|
| A move | the piece glides from square to square in 0.38 s, eased with `ease(t, −2.2)` (in-out), rising in an arc *sin(πt) · 0.55* on the way. In castling the rook glides at the same time with an arc of 0.15 |
| A capture | the captured piece waits 0.18 s, then sinks to y = −0.9 over 0.5 s (cubic ease-in) while fading to transparent over 0.45 s (from 0.2 s), then is removed |
| Selecting a piece | it lifts to y = 0.14 in 0.12 s (quadratic); deselecting lowers it in 0.12 s |
| Dragging a piece | it follows the pointer at y = 0.34, kept within the board (±4.3); dropped off a legal square, it glides back |
| Turning the board | the yaw eases round (see Smoothing) |
| Changing screens | the veil over the table fades over 0.4 s; the camera's offset over 0.6 s |

## Sound

All sounds are synthesised at start-up (44.1 kHz, 16-bit mono); there are no sound files. Each ends with a 20 ms linear fade. *t* is time in seconds.

```
tock(t, f, k)  = 0 for t < 0, else ½ · ( sin(2πft + 3·e^(−60t)) · e^(−kt)  +  noise · e^(−400t) · 0.6 )      noise uniform in [−1, 1]
bell(t, f)     = 0 for t < 0, else ( sin(2πft) + 0.3 · sin(4πft) · e^(−6t) ) · (1 − e^(−300t)) · e^(−4.5t) · 0.14
```

| Sound | Length | Signal | When |
|---|---|---|---|
| move | 0.16 s | 0.9 · tock(t, 190, 34) | a piece lands (no capture) |
| capture | 0.30 s | tock(t, 150, 22) + 0.8 · tock(t − 0.07, 120, 26) | a capture |
| select | 0.06 s | sin(2π·1450t) · e^(−90t) · 0.18 | picking up a piece |
| illegal | 0.20 s | sin(2π·95t) · e^(−18t) · 0.4 | dropping on, or clicking, a square that isn't a move |
| notify | 0.60 s | bell(t, 659.3) + bell(t − 0.12, 987.8) | invitation sent or accepted; a draw offer arrives |
| chat | 0.25 s | 0.6 · bell(t, 1174.7) | the opponent's message arrives |
| win | 1.40 s | bell(t, 523.3) + bell(t−0.13, 659.3) + bell(t−0.26, 784) + 1.2 · bell(t−0.39, 1046.5) | the player wins |
| lose | 1.30 s | bell(t, 392) + bell(t−0.2, 311.1) + bell(t−0.4, 261.6) | the player loses |
| draw | 1.00 s | bell(t, 440) + 0.8 · bell(t−0.18, 554.4) | a draw |

At most four sounds play at once; a fifth replaces the oldest. **Sound on / Sound off** in the top bar mutes everything.
