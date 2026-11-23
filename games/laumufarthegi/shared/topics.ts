// The topics: the 16-word grids in games/word-lists/data/topic-grids.json, bundled into the Worker at build time.
// The word list is its own folder, shared by several games; a change there reaches this game on its next build.
import data from "../../word-lists/data/topic-grids.json";
import type { Topic } from "./game";

export const TOPICS: Topic[] = (data as { efnisgrindur: Topic[] }).efnisgrindur.map((g) => ({
  efni: g.efni, ord: g.ord, barnvaent: g.barnvaent, erfidleiki: g.erfidleiki, flokkur: g.flokkur,
}));
