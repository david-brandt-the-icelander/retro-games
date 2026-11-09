//! Random numbers: the main generator every rule draws from (RULES C.2.1), and the separate
//! cosmetic generator the picture draws from (RULES, deliberate difference 3).
//!
//! Both are deterministic. Nothing in the sim may use any other source of randomness.

/// The result of one draw from a byte generator.
///
/// `a` is the new random byte. `x` is the previous value of the second state byte, which,
/// unless the generator was reseeded in between, equals the `a` of the draw before. Some rules
/// use both halves, so the correlation between them is part of the rules.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Draw {
    pub a: u8,
    pub x: u8,
}

/// The state shared by both generators: four bytes and a carry bit.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct ByteState {
    s0: u8,
    s1: u8,
    s2: u8,
    s3: u8,
    carry: bool,
}

impl ByteState {
    /// One draw, as RULES C.2.1 describes it, with `carry_in` as the carry into the first step.
    fn step(&mut self, carry_in: bool) -> Draw {
        let shifted = (u16::from(self.s0) << 1) + u16::from(carry_in);
        let t = (shifted & 0xFF) as u8;
        let high = self.s0 >= 0x80;

        let sum0 = u16::from(t) + u16::from(self.s2) + u16::from(high);
        let carry0 = sum0 > 0xFF;
        self.s0 = (sum0 & 0xFF) as u8;
        self.s2 = t;

        let previous = self.s1;
        let sum1 = u16::from(self.s1) + u16::from(self.s3) + u16::from(carry0);
        self.carry = sum1 > 0xFF;
        self.s1 = (sum1 & 0xFF) as u8;
        self.s3 = previous;

        Draw { a: self.s1, x: previous }
    }
}

/// The main generator. Every draw a rule makes comes from here, in the order RULES gives.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MainGenerator {
    state: ByteState,
}

impl MainGenerator {
    /// The state at game start: s0..s3 = 0x12, 0x34, 0x56, 0x78 and a clear carry.
    pub const fn new() -> Self {
        Self::with_seed([0x12, 0x34, 0x56, 0x78])
    }

    /// A generator with the four state bytes given and a clear carry. Tests use this.
    pub const fn with_seed(seed: [u8; 4]) -> Self {
        Self {
            state: ByteState { s0: seed[0], s1: seed[1], s2: seed[2], s3: seed[3], carry: false },
        }
    }

    /// Replaces the four state bytes and keeps the carry, as reseeding does in RULES C.2.1.
    pub fn reseed(&mut self, seed: [u8; 4]) {
        let carry = self.state.carry;
        self.state = ByteState { s0: seed[0], s1: seed[1], s2: seed[2], s3: seed[3], carry };
    }

    /// One normal draw.
    pub fn draw(&mut self) -> Draw {
        let carry = self.state.carry;
        self.state.step(carry)
    }

    /// Clears the carry, then draws.
    pub fn draw_carry_cleared(&mut self) -> Draw {
        self.state.carry = false;
        self.state.step(false)
    }

    /// One draw, keeping only the random byte.
    pub fn byte(&mut self) -> u8 {
        self.draw().a
    }

    /// Takes `count` draws and throws them away, so the stream keeps its length where a rule
    /// draws for something LodeStar shows differently (RULES, deliberate difference 3).
    pub fn discard(&mut self, count: usize) {
        for _ in 0..count {
            self.draw();
        }
    }

    /// The carry the last draw left, which feeds the next one. One rule reads it: the benign
    /// spawn's x offset (RULES B.4.1, B.10.8, C.16.5).
    pub fn carry(&self) -> bool {
        self.state.carry
    }
}

impl Default for MainGenerator {
    fn default() -> Self {
        Self::new()
    }
}

/// The cosmetic generator: everything drawn only for the picture (stardust, the sun's edge,
/// beam lines) comes from here and never from the main generator, so what the camera shows
/// can never change the game (RULES, deliberate difference 3).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CosmeticGenerator {
    state: ByteState,
}

impl CosmeticGenerator {
    /// A cosmetic generator with its own fixed seed, unrelated to the main generator's.
    pub const fn new() -> Self {
        Self { state: ByteState { s0: 0xC3, s1: 0x5E, s2: 0x91, s3: 0x27, carry: false } }
    }

    /// One byte for the picture.
    pub fn byte(&mut self) -> u8 {
        let carry = self.state.carry;
        self.state.step(carry).a
    }

    /// A value in 0.0..1.0 for the picture.
    pub fn unit(&mut self) -> f64 {
        let high = f64::from(self.byte());
        let low = f64::from(self.byte());
        (high * 256.0 + low) / 65536.0
    }
}

impl Default for CosmeticGenerator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_two_draws_from_the_starting_state() {
        // Worked by hand from RULES C.2.1 for s = 12 34 56 78, carry clear.
        let mut g = MainGenerator::new();
        assert_eq!(g.draw(), Draw { a: 0xAC, x: 0x34 });
        assert_eq!(g.draw(), Draw { a: 0xE1, x: 0xAC });
    }

    #[test]
    fn x_is_the_previous_a_until_reseeded() {
        let mut g = MainGenerator::new();
        let mut last = g.draw().a;
        for _ in 0..1000 {
            let d = g.draw();
            assert_eq!(d.x, last);
            last = d.a;
        }
    }

    #[test]
    fn carry_survives_reseeding_and_is_cleared_on_request() {
        // Find a draw that leaves the carry set.
        let mut g = MainGenerator::new();
        while !g.state.carry {
            g.draw();
        }
        g.reseed([1, 2, 3, 4]);
        assert!(g.state.carry, "reseeding keeps the carry");

        let mut with_carry = g;
        let mut cleared = g;
        let normal = with_carry.draw();
        let fresh = cleared.draw_carry_cleared();
        // The carry feeds only the first step, so the byte drawn now is the same, and the
        // difference shows in the state, and so in later draws.
        assert_eq!(normal.a, fresh.a);
        assert_ne!(with_carry, cleared, "the carry feeds the first step");
        let mut reference = MainGenerator::with_seed([1, 2, 3, 4]);
        assert_eq!(fresh, reference.draw());
        assert_eq!(cleared, reference);
    }

    #[test]
    fn discard_advances_the_stream_exactly() {
        let mut a = MainGenerator::new();
        let mut b = MainGenerator::new();
        a.discard(54);
        for _ in 0..54 {
            b.draw();
        }
        assert_eq!(a, b);
    }

    #[test]
    fn cosmetic_draws_never_touch_the_main_generator() {
        let mut main = MainGenerator::new();
        let before = main;
        let mut cosmetic = CosmeticGenerator::new();
        for _ in 0..500 {
            cosmetic.byte();
        }
        assert_eq!(main, before);
        let u = cosmetic.unit();
        assert!((0.0..1.0).contains(&u));
        main.draw();
    }
}
