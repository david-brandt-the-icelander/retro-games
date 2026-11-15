// Each event: sign = registry code, hz = hazard drawing, spd = start speed (mph),
// c = [correct scream, target mph], w = [wrong scream, target mph, what happens], good, late, fx.
// The third option is always irrelevant small talk drawn from SMALL.
const EV = [];
const E = (o) => EV.push(o);
E({ id: "sheep", sign: "A11.37", hz: "sheep", spd: 60, scene: "A flock of sheep has strolled onto the road. In Iceland they have right of way, and they know it.",
  c: ["BRAKE, YOU MORON! SHEEP!", 5], w: ["THEY'RE JUST CLOUDS, YOU GOOSE! DRIVE!", 60, "Clouds do not go baa. The ram has opinions about your bumper, and so does your insurance."],
  good: "The driver stops. A hundred sheep cross with the confidence of animals who own the road. Which, in Iceland, they do.", late: "BAAAA-THUMP. The sheep wins. Your bumper does not, and neither does the farmer's mood.", fx: "f4f1ea" });
E({ id: "horse", sign: "A11.32", hz: "horse", spd: 55, scene: "Three horses ride the shoulder like they pay the road tax. One of them looks at your car and sighs.",
  c: ["SLOW DOWN, YOU IDIOT! HORSES!", 10], w: ["HONK AT THEM, YOU GENIUS!", 55, "Horses hate honking. One leaves through your windscreen. A horse is five hundred kilos of regret."],
  good: "The driver crawls past. A horse looks you up and down and decides you are not worth biting.", late: "The horse leaves by the windscreen and enters by the back seat. It makes itself comfortable.", fx: "8a5a2b" });
E({ id: "cow", sign: "A11.36", hz: "cow", spd: 50, scene: "A cow stands in the road chewing. The cow has been there since the 1990s.",
  c: ["BRAKE, MORON! COWS!", 5], w: ["MOO AT THEM! THEY'LL MOVE!", 50, "The cows moo back. Louder. They have been practising. They are not moving."],
  good: "The cows cross. One stops to stare at you. Nobody argues with a cow.", late: "The cow has right of way, a ribcage like a bus and no insurance.", fx: "e8e4dc" });
E({ id: "reindeer", sign: "A11.38", hz: "deer", spd: 60, scene: "Two glowing eyes in the dusk at the roadside. Then four. Then they step out, antlers first.",
  c: ["SLOW DOWN, YOU MORON! REINDEER!", 10], w: ["FLASH THE HIGH BEAMS, GENIUS!", 60, "Reindeer freeze when you flash lights. It is the entire thing they do. The car and the reindeer are now one."],
  good: "The driver brakes. A stag pauses, locks eyes with you, then wanders off with deep disdain.", late: "BANG. Your bonnet has an antler now. The reindeer is on the roof, looking at you like you owe it money.", fx: "8a5a2b" });
E({ id: "ducks", sign: "146", hz: "ducks", spd: 50, scene: "The sign says animals. A flock of ducks waddles across, in no hurry whatsoever.",
  c: ["BRAKE, YOU MORON! DUCKS!", 5], w: ["AWW, LOOK AT THE DUCKS, YOU GOOSE!", 45, "The driver looks. The ducks look back. Briefly. Then there are feathers. So many feathers."],
  good: "The driver brakes. The ducks cross in a tiny, smug parade. The last one nods at you. You will carry that nod forever.", late: "Nobody said anything useful. The ducks said quack, and then nothing at all. The wipers are on paté setting.", fx: "f4f0dc" });
E({ id: "gator", sign: "146", hz: "gator", spd: 45, scene: "The sign says animals. Nobody explains why a gator is sunbathing across both lanes in Iceland.",
  c: ["BRAKE, YOU MORON! THAT'S A GATOR!", 8], w: ["IT'S A LOG, YOU COWARD! RUN IT OVER!", 45, "It was not a log. The log now has your whole arm and a strong opinion about your elbow."],
  good: "The driver slows. The gator ambles across and gives you a long, assessing stare. You were not the snack. This time.", late: "The gator takes your silence as an order for takeout. Compliments to the chef. The chef is you.", fx: "4a8f3a" });
E({ id: "pedx", sign: "A11.22", hz: "walker", spd: 35, scene: "A very elderly man with a walker has started crossing. He has all day. You do not.",
  c: ["STOP, YOU MANIAC! LET HIM CROSS!", 0], w: ["HE'LL MAKE IT, GRANDMA! KEEP GOING!", 35, "He did not make it. The walker made it. It is now a bonnet ornament and, honestly, a fairly nice one."],
  good: "The driver stops. Eleven minutes later, the man reaches the far side, tips his hat and calls you sweetheart.", late: "A walker flies past the passenger window. Silently. Like a very sad bird.", fx: "c0c4cc" });
E({ id: "children", sign: "A11.11", hz: "kids", spd: 40, scene: "A ball bounces into the road. A small child is already running after it.",
  c: ["BRAKE, YOU IDIOT! A KID!", 0], w: ["IT'S JUST A BALL, YOU WIMP!", 40, "It was a ball. Then it was not just a ball. The driver says nothing for forty miles. Neither do you."],
  good: "Tires scream. The kid grabs the ball, waves, and calls the driver a word you did not know a six-year-old knew. Worth it.", late: "Thud. Silence. 'That was a ball, right?' the driver asks, very small. You both decide to believe it was a ball.", fx: "e8453c" });
E({ id: "cyclist", sign: "A11.41", hz: "cyclist", spd: 45, scene: "A cyclist in neon lycra is crossing the road, fast, with the calm of someone who has right of way and a helmet.",
  c: ["BRAKE, MORON! CYCLIST CROSSING!", 5], w: ["RACE HIM, YOU TURTLE! FASTER!", 60, "You race him. You lose. By the time the driver stops, he has uploaded the whole thing to the internet."],
  good: "The driver brakes. The cyclist crosses, clips out of one pedal, salutes with two fingers, and pedals off like a rocket.", late: "A bicycle bell. A shriek. A neon blur over the bonnet. He lands in a bush with the dignity of a cat.", fx: "3cd0a0" });
E({ id: "curve", sign: "A01.11", hz: "curve", spd: 65, scene: "A hairpin to the right. A wall on one side. A nice view of the valley, from above and then from below, on the other.",
  c: ["TOO FAST, YOU MANIAC! CURVE!", 15], w: ["DRIFT IT, TURTLE! FASTER!", 85, "The drift is magnificent. The landing is not. You get excellent views of the valley for four whole seconds."],
  good: "The driver slows. The car hugs the curve like an old friend. Far below, a wrecked car whispers: tell my story.", late: "The tires scream. The car sails off the cliff in slow motion. The driver says, 'Huh.' It is the last thing anyone says.", fx: "ffb000" });
E({ id: "descent", sign: "A18", hz: "steep", spd: 70, scene: "A twelve percent descent. The driver is in neutral 'to save petrol'. The brakes are already smelling.",
  c: ["SHIFT DOWN, YOU MORON! BRAKE GENTLY!", 30], w: ["COAST, GENIUS! SAVE THE FUEL!", 105, "Downhill in neutral is a roller coaster with a wallet attached. The brakes smell like a barbecue. It is not a good barbecue."],
  good: "The driver drops a gear and the engine growls like a happy dog. The descent ends with brakes that are merely warm.", late: "The needle climbs and so does the driver's voice. The runaway lane does not exist. The ditch does.", fx: "9a9aa2" });
E({ id: "ascent", sign: "A19", hz: "steep", spd: 30, scene: "A steep climb. The driver is doing 30 in fifth gear and the engine is crying quietly.",
  c: ["SHIFT DOWN, YOU MORON! GO GO GO!", 55], w: ["STOP AND ADMIRE THE VIEW, SNAIL!", 0, "The car stops. The car rolls backwards. Slowly. Then not slowly. The handbrake files a complaint."],
  good: "The driver drops a gear and the little engine finds courage. At the top, the whole country spreads out below.", late: "The engine coughs, the car stalls, and a long line of locals behind you remembers every word of Icelandic profanity.", fx: "9a9aa2" });
