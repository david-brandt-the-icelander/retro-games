import { Game, botAction, meldOf, card } from '../public/engine.js';
// meld sanity
const mk=(s,r,c=0)=>s*12+r*2+c;
const run=[5,4,3,2,1].map(r=>mk(1,r));
console.log('run+nothing', meldOf([...run, mk(1,0)],1).total, '(expect 16)');
console.log('aces around', meldOf([0,1,2,3].map(s=>mk(s,5)),0).total, '(expect 10)');
console.log('pinochle', meldOf([mk(3,1),mk(0,2)],2).total, '(expect 4)');
let games=0, hands=0, made=0, stuck=0, scores=[], t0=Date.now();
for(let n=0;n<2000;n++){
  const g=new Game(); games++;
  let guard=0;
  while(g.s.phase!=='over'){
    if(++guard>20000) throw new Error('stall '+g.s.phase+' hand '+g.s.handNo+' scores '+g.s.scores);
    const s=g.s;
    if(s.pending){g.resolveTrick();continue;}
    if(['meld','hand','over'].includes(s.phase)){ if(s.phase==='hand'){hands++; if(s.result.made)made++;} for(let i=0;i<4;i++)g.act(i,{type:'ready'}); continue;}
    const a=botAction(g,s.turn); const r=g.act(s.turn,a);
    if(!r.ok) throw new Error('bot illegal '+JSON.stringify([s.phase,a,r]));
  }
  hands++; if(g.s.result.made)made++; scores.push(g.s.handNo);
}
console.log({games,hands,madeRate:(made/hands).toFixed(2),avgHandsPerGame:(scores.reduce((a,b)=>a+b)/games).toFixed(1),ms:Date.now()-t0});
