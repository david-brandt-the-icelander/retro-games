// data/ord.txt is imported as a string (wrangler's default Text rule; esbuild's text loader in build.mjs).
declare module "*.txt" {
  const text: string;
  export default text;
}
