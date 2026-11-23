// data/*.txt is bundled as a string (wrangler's Text rule; esbuild's text loader in the tests).
declare module "*.txt" {
  const text: string;
  export default text;
}
