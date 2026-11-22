// The calendar: places the doors, runs the peel, poses the characters and plays the 24 scenes.
// Its own file so the page's Content-Security-Policy can forbid inline script.
(function(){
'use strict';
const ART=window.ADVENT_ART;
const $=id=>document.getElementById(id);
const TAU=Math.PI*2,PI=Math.PI,sin=Math.sin,cos=Math.cos,abs=Math.abs;
const lerp=(a,b,t)=>a+(b-a)*t,clamp=(v,a,b)=>Math.min(b==null?1:b,Math.max(a==null?0:a,v));
const easeOutBack=x=>{const c1=1.70158,c3=c1+1;return 1+c3*Math.pow(x-1,3)+c1*Math.pow(x-1,2)};
const easeInOut=x=>x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2;
function rng(s){s=s>>>0||1;return()=>(s=(Math.imul(s,1664525)+1013904223)>>>0)/4294967296}
const memo={};const M=(k,f)=>memo[k]||(memo[k]=f());
const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
const now=new Date();
$('yr').textContent='Yuletide '+now.getFullYear();
function glow(c,x,y,r,rgb,a){const g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba('+rgb+','+a+')');g.addColorStop(1,'rgba('+rgb+',0)');c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2)}
function rr(c,x,y,w,h,r){c.beginPath();c.moveTo(x+r,y);c.arcTo(x+w,y,x+w,y+h,r);c.arcTo(x+w,y+h,x,y+h,r);c.arcTo(x,y+h,x,y,r);c.arcTo(x,y,x+w,y,r);c.closePath()}

/* ======================================================================
   Art: sheets from assets/ (made by art/build.mjs). The house and doors
   load with the page; a scene's sheets load when its window is tapped.
   ====================================================================== */
const sheets={};
function sheet(name){return sheets[name]||(sheets[name]=new Promise((res,rej)=>{const m=ART[name];if(!m)return rej(new Error('no sheet '+name));const img=new Image();img.decoding='async';img.onload=()=>{const s={img:img,m:m,ready:true};sheets[name].v=s;res(s)};img.onerror=()=>{delete sheets[name];rej(new Error('could not load '+m.file))};img.src='assets/'+m.file}))}
const got=name=>sheets[name]&&sheets[name].v;
// draw sprite `id` of a loaded sheet with its pivot at the current origin
function spr(c,S,id,x,y,rot,sx,sy){if(!S)return;const p=S.m.sprites[id];if(!p)return;c.save();c.translate(x||0,y||0);if(rot)c.rotate(rot);if(sx!=null)c.scale(sx,sy==null?sx:sy);const k=p[6];c.drawImage(S.img,p[0],p[1],p[2],p[3],-p[4]/k,-p[5]/k,p[2]/k,p[3]/k);c.restore()}

/* ======================================================================
   Characters: painted parts posed by a rig. Pose P is the same as in the
   first, code-drawn version: arm angles aL/aR (0 down, PI up), head turn
   hr, look lx/ly, blink bl, mouth open mo, smile sm, ears, tail, nose.
   ====================================================================== */
function creature(c,A,P){
 const R=A.m.rig,S=R.S,F=R.face,E=R.ear,hw=S.hw,hh=S.hh;
 P=Object.assign({x:0,y:0,sx:1,sy:1,rot:0,hr:0,aL:.28,aR:.28,arm:1,lx:0,ly:0,bl:0,mo:0,sm:.8,tongue:0,ear:0,tail:0,nose:0,bells:0,happy:0},P);
 c.save();c.translate(P.x,P.y);c.scale(P.sx,P.sy);c.rotate(P.rot);
 if(R.tail)spr(c,A,'tail',R.tail.at[0],R.tail.at[1],R.tail.rot[0]+R.tail.rot[1]*P.tail);
 spr(c,A,'body');
 const ears=front=>{if(!E||E.front!==front)return;[-1,1].forEach(k=>{c.save();c.scale(k,1);spr(c,A,'ear',E.at[0],E.at[1],E.rot[0]+E.rot[1]*P.ear);c.restore()})};
 c.save();c.translate(0,R.hy);c.rotate(P.hr);
 spr(c,A,'antlers');ears(0);spr(c,A,'head');
 [-1,1].forEach(k=>{spr(c,A,'iris',k*F.ex,F.ey);const x=k*F.ex+P.lx*3.2,y=F.ey+P.ly*3;
  if(P.happy>.5||(P.bl>.9&&P.happy))spr(c,A,'eyeHappy',x,y);else spr(c,A,'eye',x,y,0,1,Math.max(.07,1-P.bl*.93))});
 if(A.m.sprites.beakT){const o=P.mo*7;if(o>1.2){c.fillStyle='#5a1f22';c.beginPath();c.moveTo(-7,F.ny+2);c.lineTo(7,F.ny+2);c.lineTo(0,F.ny+3+o);c.fill()}spr(c,A,'beakB',0,F.ny+3+o*.8);spr(c,A,'beakT',0,F.ny)}
 else{
  if(P.mo>.08)spr(c,A,'mouthOpen',0,F.my-1,0,(7+P.mo*5)/12,(4+P.mo*20)/24);else spr(c,A,'smile',0,F.my,0,1,Math.max(.25,P.sm));
  if(P.tongue>0)spr(c,A,'tongue',0,F.my+2+P.mo*6,0,1,P.tongue);
  if(P.nose&&A.m.sprites.noseLit){glow(c,0,F.ny,46,'255,60,50',.7);spr(c,A,'noseLit',0,F.ny)}else spr(c,A,'nose',0,F.ny);
 }
 spr(c,A,'stache',0,F.ny+(S.beard?5:hh*.1));
 ears(1);spr(c,A,'hat');
 c.restore();
 spr(c,A,'scarf',0,R.hy+hh*1.05);
 if(S.collar)[-1,0,1].forEach(k=>spr(c,A,'bell',k*hw*.45,R.hy+hh*1.05+6+sin((P.bells||0)+k)*2));
 [-1,1].forEach(k=>{const a=k>0?P.aR:P.aL;c.save();c.translate(k*S.bw*.78,-S.bh*1.5);c.scale(k,1);c.rotate(-a);c.scale(1,P.arm);spr(c,A,'arm');c.restore()});
 c.restore()}

/* ======================================================================
   Scenes: each friend does one thing, once, then holds still and keeps
   watching the child's finger.
   ====================================================================== */
const CW=360,CH=640;
const SC=[];const add=(t,m,sp,draw,top,extra)=>SC.push(Object.assign({t:t,m:m,sp:sp,draw:draw,top:top},extra||{}));
const blinkAt=t=>t>1.6?Math.max(0,1-abs(((t-1.6)%3.1)-.08)/.08):0;
function makeK(sc,t,ptr,A,C){const pos=sc.pos||{x:180,y:548,s:1.5},S=A&&A.m.rig.S;
 const K={t:t,S:S,A:A,C:C,pos:pos,ptr:ptr,fg:[]};
 K.win=(a,b,f)=>clamp((t-a)/(f||.3))*clamp((b-t)/(f||.3));
 K.ramp=(a,d)=>clamp((t-a)/d);
 K.P0=(delay)=>{const r=easeOutBack(clamp((t-(delay==null?.15:delay))/.95)),idle=t>1.2?sin(t*2.6)*.012:0;
  // a finger resting on the friend's face makes it beam
  const hy=pos.y+(-2*S.bh-S.hh*.4)*pos.s,near=ptr.on&&Math.hypot(ptr.cx-pos.x,ptr.cy-hy)<S.hw*pos.s*1.1&&t>1;
  return{x:0,y:(1-r)*270,sx:1-idle*.5,sy:1+idle,rot:0,hr:0,aL:.28,aR:.28,arm:1,lx:clamp(ptr.x*1.1,-1,1),ly:clamp(ptr.y*1.1,-1,1),bl:blinkAt(t),mo:0,sm:.8,tongue:0,ear:0,tail:0,nose:0,bells:0,happy:near?1:0}};
 K.cr=(P,A2,pos2)=>{const p=pos2||pos,c=K.c;if(!(A2||A))return;c.save();c.translate(p.x,p.y);c.scale(p.s,p.s);creature(c,A2||A,P);c.restore()};
 K.paw=(P,side,S2,pos2)=>{const s=S2||S,p=pos2||pos,a=side>0?P.aR:P.aL,L=s.arm*(P.arm||1);return{x:p.x+(P.x+side*s.bw*.78+side*sin(a)*L)*p.s,y:p.y+(P.y-s.bh*1.5+cos(a)*L)*p.s}};
 K.head=(P,S2,pos2)=>{const s=S2||S,p=pos2||pos;return{x:p.x+P.x*p.s,y:p.y+(P.y-2*s.bh-s.hh*.4)*p.s}};
 K.spr=(id,x,y,r,sx,sy)=>spr(K.c,C,id,x,y,r,sx,sy);
 K.bubble=(txt,x,y,a)=>{a=a==null?1:a;if(a<=0)return;K.fg.push(c=>{c.save();c.globalAlpha=clamp(a);c.font="700 30px 'Mountains of Christmas',Georgia,serif";c.textAlign='center';const w=c.measureText(txt).width+34,sc2=.85+.15*clamp(a*3);x=clamp(x,36+w/2*sc2+8,324-w/2*sc2-8);c.translate(x,y);c.scale(sc2,sc2);c.fillStyle='rgba(40,20,30,.22)';rr(c,-w/2+3,-22,w,48,22);c.fill();c.fillStyle='#fffdf6';rr(c,-w/2,-26,w,48,22);c.fill();c.beginPath();c.moveTo(-10,20);c.lineTo(-4,36);c.lineTo(8,20);c.fill();c.fillStyle='#b3243b';c.textBaseline='middle';c.fillText(txt,0,-1);c.restore()})};
 K.burst=(x,y,t0,n)=>{const c=K.c,age=t-t0;if(age<0||age>1.3)return;n=n||12;c.save();c.globalCompositeOperation='lighter';c.globalAlpha=1-age/1.3;for(let i=0;i<n;i++){const a=i/n*TAU+i,v=40+(i%3)*30,r=v*(1-Math.exp(-age*3));K.spr('sparkle',x+cos(a)*r,y+sin(a)*r,a,.6+(1-age/1.3)*.6)}c.restore()};
 K.hearts=(x,y,t0,n)=>{const c=K.c;for(let i=0;i<n;i++){const p=(t-t0-i*.35)/2.2;if(p<0||p>1)continue;c.globalAlpha=1-p*p;K.spr('heart',x+sin(i*2.1+p*5)*40+(i-n/2)*14,y-p*230,sin(p*6+i)*.2,.8+p*1.6);c.globalAlpha=1}};
 K.notes=(x,y,t0,t1)=>{const c=K.c;for(let i=0;i<9;i++){const s0=t0+i*.38;if(t<s0||s0>t1)continue;const p=(t-s0)/2;if(p>1)continue;c.globalAlpha=1-p;K.spr('note'+i%3,x+sin(i*1.7+p*4)*45+i%3*14-14,y-p*190,sin(p*5)*.3,1+p*1.1);c.globalAlpha=1}};
 return K}

add('Hello, Snowman!','He has stood perfectly still all night, just so he could be the first to say hello to you.','snowman',(c,t,K)=>{const P=K.P0(),w=K.win(1.2,4.8);P.aR=lerp(.3,2.5,w)+sin((t-1.2)*10)*.4*w;P.hr=.09*sin((t-1)*3)*w;P.sm=1;P.mo=w>.5?.5+.5*sin(t*9):0;K.cr(P);K.bubble('Hi!',270,250,K.win(1.4,4.6))});
add('Waddle, Waddle','He slid all the way down the hill to get here. Both flippers are for you.','penguin',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.8);P.aL=P.aR=lerp(.3,1.95,w)+sin(t*15)*.5*w;P.y-=abs(sin(t*6))*22*w;P.sy=1+abs(sin(t*6))*.04*w;P.mo=w>.3?.4+.4*sin(t*7):0;P.sm=1;K.cr(P);K.bubble('Hello!',90,250,K.win(1.3,4.6))});
add('Peek-a-Boo','Where did the fox go? Are you sure? Count to two and look again.','fox',(c,t,K)=>{const P=K.P0(),cov=K.win(.9,2.3,.25);P.aL=P.aR=lerp(.3,PI+.62,cov);P.arm=lerp(1,1.3,cov);P.bl=Math.max(P.bl,cov);if(t>=2.3){P.aL=P.aR=lerp(2.4,.3,K.ramp(3.6,.7));P.arm=1;P.mo=1;P.y-=sin(clamp((t-2.3)/.6)*PI)*34;P.bl=blinkAt(t);if(t>3.6)P.mo=0}P.sm=1;P.ear=t>2.3&&t<4?sin(t*14)*.4:0;P.tail=sin(t*3)*.5;K.cr(P);K.bubble('Boo!',180,250,K.win(2.3,4.4));K.burst(180,380,2.3,14)});
add('Bunny Bounce','Too excited to stay still. This one is also sending you some love.','bunny',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.3,.2),hop=abs(sin((t-1.1)*6.5))*w;P.y-=hop*58;P.sy=1+(hop>.1?.04:-.05*w);P.sx=2-P.sy;P.ear=sin((t-1.1)*6.5)*.5*w;P.aL=P.aR=.3+hop*1.4;P.sm=1;P.mo=hop>.3?.4:0;K.cr(P);const h=K.head(P);K.hearts(h.x,h.y-40,1.7,7)});
add('Wake Up, Hedgehog','Sleepy little thing. Give him a moment, he will be so glad it is you.','hedgehog',(c,t,K)=>{const P=K.P0(.1);P.bl=t<2.9?1:blinkAt(t+1);P.happy=t<2.9?0:P.happy;if(t>1.6&&t<2.9){const y=K.win(1.6,2.9,.3);P.mo=y;P.aL=P.aR=lerp(.3,2.6,y);P.sy=1+.05*y}else if(t>=2.9){P.aR=2.4+sin((t-2.9)*10)*.4*K.win(2.9,5,.3);P.sm=1}P.hr=t<1.6?.18:0;K.cr(P);const h=K.head(P);if(t<2.3){for(let i=0;i<3;i++){const p=((t*.5+i/3)%1);c.font="700 "+(18+p*20)+"px 'Mountains of Christmas',Georgia,serif";c.fillStyle='rgba(255,250,240,'+(1-p)+')';c.strokeStyle='rgba(90,50,110,'+(1-p)*.6+')';c.lineWidth=3;c.strokeText('z',h.x+40+i*10+p*20,h.y-30-p*90);c.fillText('z',h.x+40+i*10+p*20,h.y-30-p*90)}}K.bubble('Oh, hello!',260,250,K.win(3.1,5))});
add('Woof!','A very good dog who has been waiting by the window all day. Tail going nineteen to the dozen.','puppy',(c,t,K)=>{const P=K.P0(),w=K.win(1.2,5,.3);P.tail=sin(t*18)*(t>.9?1:0)*(1-K.ramp(5.5,1)*.8);P.rot=sin(t*14)*.04*w;P.aR=2.35+sin((t-1.6)*9)*.4*K.win(1.8,4.2,.3);P.aR=lerp(.3,P.aR,K.win(1.6,4.6,.3));P.mo=t>1.4&&t<2.1?.9:0;P.tongue=t>2.4&&t<5?K.win(2.4,5,.3):0;P.mo=Math.max(P.mo,P.tongue*.5);P.sm=1;P.y-=t>1.4&&t<1.7?12:0;K.cr(P);K.bubble('Woof!',270,250,K.win(1.4,3.2))});
add('The Swinging Bauble','Kitten has been staring at this one for ages. One paw, then another. Who will win?','kitten',(c,t,K)=>{const P=K.P0(),swat=K.win(1.6,2.3,.12),sw=t>1.9?Math.exp(-(t-1.9)*.55)*cos((t-1.9)*5.5):0,bx=250+sw*70,by0=300,depth=1+sw*.25;P.aR=lerp(.3,2.2,swat)+(t>1.9?.6*clamp(1-(t-1.9)*1.2):0);P.lx=clamp(sw*1.2,-1,1);P.ly=-.4;P.sm=1;P.hr=sw*.12;P.tail=sin(t*4)*.6;P.mo=t>2.2&&t<2.5?.6:0;
 c.strokeStyle='rgba(255,240,200,.85)';c.lineWidth=1.5;c.beginPath();c.moveTo(250,40);c.lineTo(bx,by0-30*depth);c.stroke();K.cr(P);K.spr('bauble',bx,by0,sw*.25,depth);if(t>1.9)K.bubble('Mew!',100,250,K.win(2.2,4))});
add('Snowball!','He has been practising his throw all winter. Brace yourself. It is a gentle one.','polar',(c,t,K)=>{const P=K.P0(),wind=K.win(.9,1.85,.3),thr=K.ramp(1.85,.18);P.aR=t<1.85?lerp(.3,3.0,wind):lerp(3.0,.9,thr);P.rot=t<1.85?-.1*wind:lerp(-.1,.1,thr)*(1-K.ramp(2.6,.5));if(t>2.4){P.mo=.7;P.sm=1;P.happy=1;P.y-=abs(sin((t-2.4)*8))*12*K.win(2.4,4.2,.2)}K.cr(P);const pw=K.paw(P,1);if(t<1.85){K.spr('snowball',pw.x,pw.y-6)}else if(t<2.35){const p=(t-1.85)/.5,e=p*p;K.spr('snowball',lerp(pw.x,180,e),lerp(pw.y,300,p),p*3,lerp(1,8,e))}K.bubble('Gotcha!',100,250,K.win(2.5,4.5))},
 (c,t,K)=>{if(t<2.35)return;const age=t-2.35,fade=clamp(1-(age-3)/2.5);if(fade<=0)return;const dr=M('drip',()=>{const r=rng(23);return Array.from({length:6},()=>({x:100+r()*160,w:9+r()*8,l:30+r()*60,sp:10+r()*14,s:r()*60}))});c.save();c.globalAlpha=fade;const pop=easeOutBack(clamp(age*5));K.spr('splat',180,290,0,.4+pop*.75);c.fillStyle='#f6f9ff';dr.forEach(d=>{const l=Math.min(d.l,age*d.sp);rr(c,d.x-d.w/2,300+d.s*.3,d.w,l+20,d.w/2);c.fill()});c.restore()});
add('Hoo Lit the Candle','Wise old owl is in charge of the light tonight. He takes it very seriously.','owl',(c,t,K)=>{const P=K.P0(),turn=K.win(.9,2.4,.4);P.hr=.3*turn;P.lx=turn*.8;P.aR=lerp(.3,1.2,K.ramp(1.0,.5));P.mo=t>3.2&&t<3.9?.7+.3*sin(t*14):0;P.bl=t>2.2&&t<2.5?1:blinkAt(t);if(t>2.5)P.hr=.3*(1-K.ramp(2.5,.7));K.cr(P);const pw=K.paw(P,1),fl=K.ramp(1.9,.5);if(fl>0){const f=.85+.15*sin(t*13);glow(c,pw.x,pw.y-62,170*fl,'255,190,90',.5*fl*f)}K.spr('candle',pw.x,pw.y);if(fl>0){const f=.85+.15*sin(t*13);c.fillStyle='rgba(255,170,60,'+fl+')';c.beginPath();c.ellipse(pw.x,pw.y-64,6*fl,14*fl*f,0,0,TAU);c.fill();c.fillStyle='rgba(255,245,200,'+fl+')';c.beginPath();c.ellipse(pw.x,pw.y-62,3*fl,7*fl*f,0,0,TAU);c.fill()}K.bubble('Hoo!',100,250,K.win(3.2,4.8))});
add('A Present for You','Mouse wrapped it herself, with a lot of ribbon and a bit of nibbling.','mouse',(c,t,K)=>{const P=K.P0(),a=K.ramp(1.0,.5),lift=K.ramp(1.8,.8);P.aL=P.aR=lerp(.3,1.35,a)+lift*1.1;P.arm=lerp(1,.8,a);P.sm=1;P.y-=sin(clamp((t-3.3)/.5)*PI)*14;if(t>3.3)P.happy=1;K.cr(P);const m=K.pos,bx=m.x+P.x,by=m.y-(P.y+80)*m.s-lift*110,sz=lerp(1,1.7,lift),open=K.ramp(3.3,.5);if(t>.9){K.spr('giftBox',bx,by,0,sz);K.spr('giftLid',bx+open*30*sz,by-40*sz-open*70*sz,open*.6,sz);if(open>0){glow(c,bx,by-30*sz,90,'255,230,140',.7*open);K.spr('star',bx,by-50*sz-open*40,t,open*1.2)}}K.burst(bx,by-60,3.3,14)});
add('The Robin Sings','Only a small voice, but it carries a long way on a winter morning.','robin',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.8,.3);P.mo=w>.3?clamp(sin(t*11)*1.2,0,1):0;P.hr=-.18*w;P.ly=lerp(P.ly,-.5,w);P.lx=P.lx*(1-w);P.aL=P.aR=.3+.2*w;P.y-=abs(sin(t*11))*3*w;K.cr(P);const h=K.head(P);K.notes(h.x+30,h.y-30,1.4,4.4)});
add('Cookie Time','Squirrel found the very last cookie. Sharing is being considered.','squirrel',(c,t,K)=>{const P=K.P0(),a=K.ramp(1.0,.5),eat=K.win(1.5,3.7,.2),off=K.ramp(4.0,.6);P.aL=lerp(.3,2.1,a);P.aR=lerp(.3,2.1,a)-off*1.3;P.arm=lerp(1,.9,a);P.mo=eat>.2?clamp(sin(t*10)*.8+.3,0,.8):0;P.sm=1;P.hr=sin(t*10)*.04*eat;P.tail=sin(t*2)*.5;K.cr(P);const pw=K.paw(P,1),h=K.head(P),sz=lerp(1,.75,K.ramp(1.5,2.2));if(t>.9){K.spr(t>2.1?'cookieBit':'cookie',lerp(h.x+4,pw.x-6,off),lerp(h.y+30,pw.y-10,off),0,sz*(1+off*.4))}
 if(t>1.5&&t<3.8){for(let i=0;i<8;i++){const p=((t*1.4+i*.13)%1);c.fillStyle='rgba(217,164,90,'+(1-p)+')';c.beginPath();c.arc(h.x+(i-4)*5,h.y+40+p*80,2.4,0,TAU);c.fill()}}K.bubble('Yum!',270,250,K.win(2.2,3.8));K.bubble('For you!',100,250,K.win(4.3,6.5))});
add('Baa-Baa-Brilliant','Three jumps, a lot of fluff, and one very proud bleat.','lamb',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.2,.2),hop=abs(sin((t-1.1)*5.2))*w;P.y-=hop*64;P.sy=1+(hop>.1?.05:-.06*w);P.sx=2-P.sy;P.aL=P.aR=.3+hop*1.5;P.ear=hop*.8;P.sm=1;P.mo=t>2.2&&t<2.6?.8:0;K.cr(P);K.bubble('Baa!',90,250,K.win(2.2,3.8));[1.5,2.6,3.7].forEach(s=>K.burst(180,420,s+.4,8))});
add('Catch Me If You Can','Freshly baked, slightly sparkly, and very fast. He is spinning on purpose.','ginger',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.8,.3);P.rot=sin((t-1.1)*7)*.16*w;P.aL=lerp(.28,1.6+sin((t-1.1)*7)*.9,w);P.aR=lerp(.28,1.6-sin((t-1.1)*7)*.9,w);P.y-=abs(sin((t-1.1)*7))*16*w;P.sm=1;P.mo=w>.2?.4:0;if(t>2.6&&t<3.5)P.sx=Math.max(.12,abs(cos((t-2.6)/.9*TAU)));K.cr(P);K.bubble("Can't catch me!",180,250,K.win(1.4,4.2))});
add('Bear Hug','He has been saving this one. It is a big one. It goes on for as long as you like.','teddy',(c,t,K)=>{const P=K.P0(),o=K.ramp(1.1,.5),sq=K.ramp(2.1,.4);P.aL=P.aR=lerp(.3,1.95,o)-sq*2.6;P.arm=lerp(1,1.2,o)*(1-sq*.1);P.sy=1-.03*sq;P.sm=1;P.hr=sin(t*2)*.05*sq*K.win(2.1,5,.5);P.happy=sq>.5?1:P.happy;K.cr(P);const h=K.head(P);K.hearts(h.x,h.y-30,2.3,6)});
add('Jingle Time','One tiny bell is making a tremendous amount of noise. The elf is delighted.','elf',(c,t,K)=>{const P=K.P0(),w=K.win(1.1,4.6,.3),sw=sin((t-1.1)*14)*w;P.aR=lerp(.3,2.1+sw*.35,K.ramp(.9,.4));P.y-=abs(sin((t-1.1)*7))*14*w;P.ear=sw;P.mo=w>.3?.5:0;P.sm=1;K.cr(P);const pw=K.paw(P,1);K.spr('bell',pw.x,pw.y-4,sw*.7);K.bubble('Ding!',90,250,K.win(1.3,2.6));K.bubble('Ding-a-ling!',180,250,K.win(2.8,4.6));if(w>.3)for(let i=0;i<5;i++){const p=((t-1.2)*1.2+i*.2)%1;c.strokeStyle='rgba(255,220,130,'+(1-p)*.7+')';c.lineWidth=2;c.beginPath();c.arc(pw.x,pw.y-4,18+p*40,.1,PI*2-.1);c.stroke()}});
add('Red Nose Night','When the fog comes down, one very bright nose lights the way. Say hello, then follow it.','reindeer',(c,t,K)=>{const g=K.ramp(1.4,.9),pulse=.75+.25*sin(t*3.2),P=K.P0();P.nose=g>.05?1:0;P.ear=sin(t*8)*.4*K.win(2.4,4,.2);P.hr=-.1*K.win(1.0,2.2,.3);P.ly=lerp(P.ly,-.6,K.win(1.0,2.2,.3));P.bells=t*8;P.sm=1;if(g>0)glow(c,180,330,420*g,'255,60,60',.38*g*pulse);K.cr(P);K.bubble('Follow me!',180,250,K.win(2.8,5))});
add('Cocoa Break','Two paws, one mug, and absolutely nowhere else to be. Warm hands, warm heart.','panda',(c,t,K)=>{const P=K.P0(),a=K.ramp(1.0,.5),sip=K.win(1.8,3.6,.4);P.aL=P.aR=lerp(.3,-.55,a)-sip*.8;P.arm=lerp(1,.9,a);P.hr=-.1*sip;P.happy=t>3.4?1:P.happy;P.bl=Math.max(P.bl,K.ramp(3.4,.3)*.9);P.sm=1;P.y-=sip*3;K.cr(P);const pl=K.paw(P,-1),pr=K.paw(P,1),mx=(pl.x+pr.x)/2,my=(pl.y+pr.y)/2-10;if(t>.9)K.spr('mug',mx,my);
 for(let k=0;k<3;k++)for(let i=0;i<10;i++){const p=((t*.5+i/10+k*.3)%1),sx=mx-12+k*12+sin(p*7+k*2+t)*9*p;c.strokeStyle='rgba(255,255,255,'+.45*(1-p)+')';c.lineWidth=7*(1-p)+1;c.lineCap='round';c.beginPath();c.moveTo(sx,my-50-p*110);c.lineTo(sx,my-49-p*110);c.stroke()}K.bubble('Ahh!',270,250,K.win(3.4,5))});
add('Ready, Sir!','The nutcracker has been on duty since the first of December. He salutes. His jaw does the talking.','nut',(c,t,K)=>{const P=K.P0(),s=K.ramp(1.0,.4);P.aR=lerp(.3,2.75,s);P.arm=lerp(1,.9,s);P.mo=[1.6,2.2,2.8].some(x=>t>x&&t<x+.18)?.9:0;P.y-=t>3.4?abs(sin((t-3.4)*8))*8*K.win(3.4,5,.1):0;P.sm=.3;K.cr(P);K.bubble('Ready!',270,250,K.win(1.5,3.4));K.bubble('Attention!',180,250,K.win(3.5,5))});
add('Snowflake Catcher','He is trying very hard to catch one. He has caught a lot, as it turns out.','husky',(c,t,K)=>{const P=K.P0(),up=K.win(1.0,5,.4);P.hr=-.12*up;P.ly=lerp(P.ly,-1,up);P.lx=P.lx*(1-up);P.tongue=up*(1-K.ramp(3.8,.4));P.mo=P.tongue*.5;P.sm=1;P.tail=sin(t*12)*up;K.cr(P);const h=K.head(P),fl=M('hf',()=>{const q=rng(9);return Array.from({length:12},()=>({x:q()*220-110,s:q()*3}))});fl.forEach((f,i)=>{const p=(t-1.3-f.s*.4)/1.4;if(p<0||p>1)return;c.globalAlpha=1-p*.3;K.spr('flake',lerp(h.x+f.x,h.x+4,p*p),lerp(h.y-180,h.y+40,p),t*2+i,1.2-p*.4);c.globalAlpha=1});K.bubble('Yum!',270,250,K.win(3.9,5.4))});
add('Did You See That?','A shooting star went right over the roof. He saw it too. He is certain he heard you coming.','reindeer',(c,t,K)=>{const P=K.P0(),up=K.win(.9,3.2,.4);P.hr=-.14*up;P.ly=lerp(P.ly,-1,up);P.lx=lerp(P.lx,.4,up);P.ear=sin(t*9)*.3*K.win(3.2,4.6,.2);P.bells=t*9*(t>2.2?1:0);P.sm=1;P.mo=t>3.4&&t<3.9?.5:0;if(t>3.3)P.hr=sin((t-3.3)*7)*.07*K.win(3.3,5,.2);const pr=clamp((t-1.2)/1.1),sx=lerp(340,150,pr),sy=lerp(190,270,pr);if(t>1.2&&t<2.6){c.save();c.globalCompositeOperation='lighter';for(let k=0;k<20;k++){c.fillStyle='rgba(255,246,200,'+(1-k/20)*(1-clamp(pr-.6)*2.5)*.8+')';c.beginPath();c.arc(sx+k*5,sy-k*3.4,5-k*.2,0,TAU);c.fill()}K.spr('sparkle',sx,sy,t*6,1.4);c.restore()}K.cr(P);K.bubble('Wow!',270,250,K.win(1.9,3.2));K.bubble('Merry Christmas!',180,250,K.win(3.6,5.2))});
add('Lantern Light','White cat carries the light for anyone who is out late. She is not going to say where from.','whitecat',(c,t,K)=>{const P=K.P0(),r=K.ramp(1.0,.5),ig=K.ramp(1.8,.6);P.aR=lerp(.3,1.5,r);P.arm=lerp(1,.9,r);P.ly=lerp(P.ly,-.3,.5);P.sm=1;P.tail=sin(t*2.4)*.7;if(t>3.4){P.happy=1;P.hr=.1}K.cr(P);const pw=K.paw(P,1),fl=.92+.08*sin(t*11);if(t>.9){if(ig>0){glow(c,pw.x,pw.y+14,200*ig,'255,200,110',.55*ig*fl);c.fillStyle='rgba(255,226,150,'+(.6*ig)+')';c.fillRect(pw.x-13,pw.y-4,26,32);c.fillStyle='rgba(255,170,60,'+ig+')';c.beginPath();c.ellipse(pw.x,pw.y+16,5,10*fl,0,0,TAU);c.fill()}K.spr('lantern',pw.x,pw.y)}
 const h=K.head(P);K.hearts(h.x,h.y-30,3.6,3);K.bubble('Purrr...',90,250,K.win(3.5,5.2))});
add('Ho Ho Ho!','He is not meant to be seen until tomorrow, but he could not resist. Do not tell.','santa',(c,t,K)=>{const P=K.P0(),hs=[1.4,2.2,3.0],i=hs.findIndex(x=>t>x&&t<x+.6),bel=i>=0?sin(clamp((t-hs[i])/.6)*PI):0;P.sy=1+bel*.05;P.sx=1-bel*.025;P.aL=P.aR=lerp(.3,.9,K.ramp(1.2,.3))-bel*.2;P.mo=bel>.1?.9:0;P.happy=bel>.3?1:P.happy;P.sm=1;if(t>3.8)P.aR=2.5+sin((t-3.8)*9)*.4*K.win(3.8,5.4,.3);if(t>5.4)P.aR=lerp(2.5,.9,K.ramp(5.4,.5));K.cr(P);K.bubble('Ho!',90,250,i===0?1:0);K.bubble('Ho!',180,250,i===1?1:0);K.bubble('Ho!',270,250,i===2?1:0)});
add('Merry Christmas!','They all came to wish you a Merry Christmas. Look at that banner. They made it themselves.','snowman',(c,t,K)=>{const defs=[['puppy',{x:92,y:558,s:1.0},.55],['bunny',{x:268,y:558,s:1.0},.9],['snowman',{x:180,y:560,s:1.2},.2]];defs.forEach((d,i)=>{const A=got('sp-'+d[0]);if(!A)return;const sub=makeK({pos:d[1]},t,K.ptr,A,K.C);sub.c=c;const P=sub.P0(d[2]),w=sub.win(2.0+i*.15,5.2,.3);P.aR=lerp(.3,2.5,w)+sin((t-2)*10+i)*.4*w;P.aL=i===1?lerp(.3,2.5,w)-sin((t-2)*10)*.4*w:.3;P.tail=sin(t*16)*(1-K.ramp(5.5,1));P.mo=w>.5?.6:0;P.sm=1;P.ear=sin(t*8)*.2*w;sub.cr(P)});
 const u=K.ramp(1.6,.8);if(u>0){c.save();c.globalAlpha=u;c.translate(180,226-(1-easeOutBack(u))*40);c.rotate(sin(t*1.6)*.015*(1-K.ramp(6,1)));K.spr('banner',0,0);c.fillStyle='#f6d36a';c.strokeStyle='rgba(90,20,20,.5)';c.lineWidth=4;c.font="700 31px 'Mountains of Christmas',Georgia,serif";c.textAlign='center';c.textBaseline='middle';c.strokeText('Merry Christmas',0,1);c.fillText('Merry Christmas',0,1);c.restore()}
 if(t>2.2){const cf=M('cf',()=>{const q=rng(88);return Array.from({length:60},()=>({x:q()*360,s:q()*3,v:50+q()*70,p:q()*TAU,h:q()*360}))});cf.forEach(o=>{const a=t-2.2-o.s;if(a<0)return;const y=-10+a*o.v;if(y>640)return;c.save();c.translate(o.x+sin(a*2+o.p)*20,y);c.rotate(a*3+o.p);c.scale(1,abs(cos(a*3+o.p)));c.fillStyle='hsl('+o.h+',85%,60%)';c.fillRect(-4,-2,8,4);c.restore()})}},null,{also:['puppy','bunny']});

/* ---------- card renderer (virtual 360x640) ---------- */
const ARCH=new Path2D(ART.common.arch);
// sheets one scene needs
const needs=d=>{const sc=SC[d-1];return['common','bg-'+String(d).padStart(2,'0'),'sp-'+sc.sp].concat((sc.also||[]).map(s=>'sp-'+s))};
const loadScene=d=>Promise.all(needs(d).map(sheet));
function ambient(c,bg,t){const m=bg.m;c.save();c.globalCompositeOperation='lighter';m.lights.forEach((l,i)=>{const on=.5+.5*sin(t*2.2-i*.9);glow(c,l[0],l[1],10+on*6,lightRGB(l[2]),.25+.35*on)});c.restore();
 const n=m.snow?40:14,sn=M('csn',()=>{const q=rng(3);return Array.from({length:40},()=>({x:q()*CW,y:q()*CH,r:q()*2+.8,v:q()*.6+.5,p:q()*TAU}))});
 c.fillStyle=m.snow?'rgba(255,255,255,.8)':'rgba(255,236,190,.55)';for(let i=0;i<n;i++){const p=sn[i],x=(p.x+sin(t*.7+p.p)*12+CW)%CW,y=m.snow?(p.y+t*22*p.v)%CH:(p.y-t*6*p.v+CH)%CH;c.globalAlpha=m.snow?1:.4+.4*sin(t*1.3+p.p);c.beginPath();c.arc(x,y,m.snow?p.r:p.r*.7,0,TAU);c.fill()}c.globalAlpha=1}
function renderCard(c,d,t,ptr){const sc=SC[d-1],C=got('common'),bg=got(needs(d)[1]),A=got('sp-'+sc.sp);
 c.clearRect(0,0,CW,CH);c.fillStyle='#2a1408';c.fillRect(0,0,CW,CH);
 c.save();c.clip(ARCH);
 if(bg){c.drawImage(bg.img,0,0,CW,CH);ambient(c,bg,t)}else{const g=c.createRadialGradient(180,360,10,180,360,320);g.addColorStop(0,'#ffe6a8');g.addColorStop(1,'#c0641f');c.fillStyle=g;c.fillRect(0,0,CW,CH)}
 const K=makeK(sc,t,ptr,A,C);K.c=c;
 if(A&&C)sc.draw(c,t,K);
 c.restore();
 if(C){spr(c,C,'frame');spr(c,C,'ledge')}
 if(sc.top&&C)sc.top(c,t,K);
 c.font="600 40px Fredoka,'DM Sans',sans-serif";c.textAlign='center';c.textBaseline='middle';c.lineWidth=6;c.strokeStyle='#fffaf0';c.strokeText(String(d),180,64);c.fillStyle='#b3243b';c.fillText(String(d),180,64);
 K.fg.forEach(f=>f(c));
 c.textAlign='left';c.textBaseline='alphabetic'}

/* ======================================================================
   The house
   ====================================================================== */
const stage=$('stage'),fx=$('fx'),H=ART.house,HW=390,HH=960,WIN=H.win;
function winBox(i){return{x:WIN.x0+(i%4)*WIN.dx,y:WIN.y0+Math.floor(i/4)*WIN.dy,w:WIN.w,h:WIN.h}}
function lightRGB(h){return M('lc'+h,()=>{const a=h/60,x=1-abs(a%2-1),s=[[1,x,0],[x,1,0],[0,1,x],[0,x,1],[x,0,1],[1,0,x]][Math.floor(a)%6];return s.map(v=>Math.round(120+v*135)).join(',')})}
function layout(){const w=stage.clientWidth,h=stage.clientHeight,dpr=Math.min(window.devicePixelRatio||1,2);fx.width=Math.round(w*dpr);fx.height=Math.round(h*dpr)}
const flakes=Array.from({length:70},(_,i)=>{const q=rng(i*9+4);return{x:q()*HW,y:q()*HH,r:q()*1.6+.6,v:q()*.6+.5,p:q()*TAU}});
const puffs=[];// snow knocked off a window ledge as its door swings open
function puff(i){const b=winBox(i),q=rng(i*31+(performance.now()|0));for(let k=0;k<14;k++)puffs.push({x:b.x+q()*b.w,y:b.y-2+q()*4,vx:(q()-.5)*30,vy:-10-q()*30,r:.8+q()*1.8,t0:performance.now()/1000})}
let fxOn=true,fxRaf=0;
function fxFrame(ts){const c=fx.getContext('2d'),t=ts/1000;c.setTransform(fx.width/HW,0,0,fx.height/HH,0,0);c.clearRect(0,0,HW,HH);
 c.globalCompositeOperation='lighter';
 H.twinkle.forEach(s=>{const a=clamp(sin(t*1.5+s[3]));if(a<=0)return;c.fillStyle='rgba(255,250,220,'+a*.8+')';c.beginPath();for(let i=0;i<8;i++){const an=s[3]+i*PI/4,q=i%2?s[2]*.8*a:s[2]*3.4*a+1;c[i?'lineTo':'moveTo'](s[0]+cos(an)*q,s[1]+sin(an)*q)}c.fill()});
 H.lights.forEach((l,i)=>{const on=.5+.5*sin(t*2.4-i*.55);glow(c,l[0],l[1],11,lightRGB(l[2]),.15+.5*on)});
 H.glows.forEach((g,i)=>glow(c,g[0],g[1],g[2],'255,190,90',.16+.05*sin(t*7+i)));c.globalCompositeOperation='source-over';
 for(let i=0;i<8;i++){const p=(t*.18+i/8)%1;c.fillStyle='rgba(225,230,245,'+.4*(1-p)+')';c.beginPath();c.arc(H.smoke[0]+sin(p*5+i)*8*p+p*18,H.smoke[1]-p*80,4+p*13,0,TAU);c.fill()}
 c.fillStyle='#fff';flakes.forEach(f=>{const y=(f.y+t*26*f.v)%(HH+10)-5,x=(f.x+sin(t*.8*f.v+f.p)*14+HW)%HW;c.globalAlpha=.5+.4*f.v;c.beginPath();c.arc(x,y,f.r,0,TAU);c.fill()});
 for(let i=puffs.length-1;i>=0;i--){const p=puffs[i],a=t-p.t0;if(a>1.4){puffs.splice(i,1);continue}c.globalAlpha=1-a/1.4;c.beginPath();c.arc(p.x+p.vx*a,p.y+p.vy*a+60*a*a,p.r,0,TAU);c.fill()}
 c.globalAlpha=1;
 if(fxOn&&!reduce)fxRaf=requestAnimationFrame(fxFrame)}
function startFx(){fxOn=true;cancelAnimationFrame(fxRaf);fxRaf=requestAnimationFrame(fxFrame)}
function stopFx(){fxOn=false;cancelAnimationFrame(fxRaf)}
layout();startFx();addEventListener('resize',()=>{layout();if(reduce)fxFrame(2000)});
const viewer={on:false,d:0,win:null,t0:0,started:false,raf:0,busy:false,frozen:null,ready:false};
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopFx();else if(!viewer.on)startFx()});

/* ---------- doors: five strips, each hinged on the one before, so the door curls as it opens ---------- */
const NS=5,DM=ART.doors,DS=DM.sprites;
// CSS background maths: show one sprite of the doors atlas across a door-sized box
const atlasW=DM.aw,atlasH=DM.ah;
function doorBg(id){const p=DS[id],k=p[6],W=WIN.w*k,Hh=WIN.h*k,ox=p[0]+p[4],oy=p[1]+p[5];return{size:(atlasW/W*100)+'% '+(atlasH/Hh*100)+'%',pos:(ox/(atlasW-W)*100)+'% '+(oy/(atlasH-Hh)*100)+'%'}}
function buildDoor(d,v){let html='';for(let i=NS-1;i>=0;i--){html='<span class="strip"><span class="face"><span class="full" style="left:'+(-i*100)+'%">'+'<b class="n" aria-hidden="true">'+d+'</b></span></span><span class="back"><span class="full" style="left:'+(-(NS-1-i)*100)+'%"></span></span>'+html+'</span>'}return html}
// p: 0 shut, 1 open. bend: how much the free edge curls (+ towards you)
function setDoor(el,p,bend){const strips=el.querySelectorAll('.strip');const A0=125*easeInOut(clamp((p-.08)/.92));let cum=0;
 strips.forEach((s,i)=>{const b=i===0?A0:bend*48*Math.pow(i/(NS-1),1.3);cum+=b;s.style.transform='rotateY('+(-b).toFixed(2)+'deg)';
  const front=cos(cum*PI/180);s.style.setProperty('--sh',(front>0?(1-front)*.55:.25+(1+front)*.4).toFixed(3))})}
function animateDoor(el,open){return new Promise(res=>{if(el._anim)cancelAnimationFrame(el._anim);if(reduce){setDoor(el,open?1:0,0);return res()}
 const T=open?900:700,t0=performance.now();
 const step=ts=>{const q=clamp((ts-t0)/T);let p,bend;
  if(open){p=q;bend=sin(PI*clamp(q/.85))}
  else{p=q<.8?1-easeInOut(q/.8):-.05*sin(PI*(q-.8)/.2);bend=-.55*sin(PI*clamp(q/.8))}
  setDoor(el,p,bend);if(q<1)el._anim=requestAnimationFrame(step);else{el._anim=0;res()}};
 el._anim=requestAnimationFrame(step)})}

/* ---------- windows ---------- */
const store={get(k,d){try{const v=localStorage.getItem(k);return v==null?d:JSON.parse(v)}catch(e){return d}},set(k,v){try{localStorage.setItem(k,JSON.stringify(v))}catch(e){}}};
let seen=new Set(store.get('adv2-seen',[]));const inDec=now.getMonth()===11;let preview=store.get('adv2-preview',!inDec);
const pv=$('preview');pv.checked=preview;const pvText=()=>{$('pvlabel').textContent=preview?'Preview mode: every window opens':'Real dates: window 1 opens on 1 December'};pvText();
const canOpen=d=>preview||(inDec&&d<=now.getDate());
const ORDER=[14,3,21,8,17,1,23,6,11,19,4,13,24,9,2,16,7,20,12,5,22,10,18,15];
const front=doorBg('door0'),back=doorBg('back');
stage.style.setProperty('--atlas','url("assets/'+DM.file+'")');
ORDER.forEach((d,i)=>{const b=winBox(i),el=document.createElement('div'),v=d%DM.variants,fb=doorBg('door'+v);el.className='win';el.dataset.d=d;el.dataset.i=i;
 el.style.cssText='left:'+(b.x/HW*100)+'%;top:'+(b.y/HH*100)+'%;width:'+(b.w/HW*100)+'%;height:'+(b.h/HH*100)+'%;--bs:'+fb.size+';--bp:'+fb.pos+';--bpb:'+back.pos;
 el.innerHTML='<div class="glass"></div><button class="door" type="button" aria-label="Open window '+d+'">'+buildDoor(d,v)+'</button><i class="badge"></i>';stage.appendChild(el)});
function refresh(){const today=inDec&&!preview?now.getDate():0;stage.querySelectorAll('.win').forEach(w=>{const d=+w.dataset.d;w.classList.toggle('seen',seen.has(d));w.classList.toggle('lock',!canOpen(d));w.classList.toggle('today',d===today&&!seen.has(d))})}refresh();
let toastT;function toast(m){const e=$('toast');e.textContent=m;e.classList.add('on');clearTimeout(toastT);toastT=setTimeout(()=>e.classList.remove('on'),2200)}
pv.addEventListener('change',()=>{preview=pv.checked;store.set('adv2-preview',preview);pvText();refresh()});
$('reset').addEventListener('click',()=>{seen=new Set();store.set('adv2-seen',[]);refresh();toast('All windows closed')});

/* ---------- opened window ---------- */
const veil=$('veil'),wrap=$('wrap'),card=$('card'),cap=$('cap'),cv=$('scene'),cx=cv.getContext('2d');
// ptr: where the child's finger or mouse is. x,y: -1..1 across the card, for the eyes; cx,cy: card units
const ptr={x:0,y:0,cx:180,cy:300,on:false},ptrT={x:0,y:0,cx:180,cy:300};let lastMove=0;
function sizeCanvas(){const dp=Math.min(window.devicePixelRatio||1,2),w=card.clientWidth;cv.width=Math.round(w*dp);cv.height=Math.round(w*dp*16/9)}
function aimAt(clientX,clientY){const r=card.getBoundingClientRect();ptrT.x=((clientX-r.left)/r.width-.5)*2;ptrT.y=((clientY-r.top)/r.height-.42)*2;ptrT.cx=(clientX-r.left)/r.width*CW;ptrT.cy=(clientY-r.top)/r.height*CH;lastMove=performance.now()}
function vframe(ts){if(!viewer.on)return;
 // after a while with no pointer the friend looks back at the child
 if(ts-lastMove>1800){ptrT.x*=.97;ptrT.y=ptrT.y*.97+.05*.03;ptr.on=false}
 ptr.x+=(ptrT.x-ptr.x)*.12;ptr.y+=(ptrT.y-ptr.y)*.12;ptr.cx+=(ptrT.cx-ptr.cx)*.3;ptr.cy+=(ptrT.cy-ptr.cy)*.3;
 if(!viewer.started&&viewer.ready&&viewer.shown){viewer.started=true;viewer.t0=ts}
 const t=viewer.frozen!=null?viewer.frozen:viewer.started?(reduce?9:(ts-viewer.t0)/1000):0,k=cv.width/CW;
 cx.setTransform(k,0,0,k,0,0);cx.save();try{renderCard(cx,viewer.d,t,ptr)}catch(e){console.error(e)}cx.restore();cx.globalAlpha=1;cx.globalCompositeOperation='source-over';
 viewer.raf=requestAnimationFrame(vframe)}
let down=null;
card.addEventListener('pointerdown',e=>{down={x:e.clientX,y:e.clientY,moved:false};ptr.on=true;aimAt(e.clientX,e.clientY)});
card.addEventListener('pointermove',e=>{if(down&&Math.hypot(e.clientX-down.x,e.clientY-down.y)>12)down.moved=true;ptr.on=e.pointerType==='mouse'||!!down;aimAt(e.clientX,e.clientY)});
card.addEventListener('pointerleave',()=>{ptr.on=false});
addEventListener('pointerup',()=>{setTimeout(()=>{down=null},0);if(!matchMedia('(hover:hover)').matches)ptr.on=false});
function openWin(el){if(viewer.busy||viewer.on)return;const d=+el.dataset.d;if(!canOpen(d)){el.classList.remove('shake');void el.offsetWidth;el.classList.add('shake');toast('Window '+d+' opens on '+d+' December');return}
 viewer.busy=true;viewer.d=d;viewer.win=el;viewer.started=false;viewer.shown=false;viewer.ready=false;
 loadScene(d).then(()=>{if(viewer.d===d)viewer.ready=true},()=>{if(viewer.d===d){viewer.ready=true;toast('Some of the pictures did not load')}});
 // the friend first glances at where the finger was
 const wr=el.getBoundingClientRect();
 el.classList.remove('closing');el.classList.add('open');puff(+el.dataset.i);seen.add(d);store.set('adv2-seen',[...seen]);
 $('vt').textContent=SC[d-1].t;$('vm').textContent=SC[d-1].m;
 animateDoor(el.querySelector('.door'),true);
 setTimeout(()=>expand(el,wr),reduce?0:620)}
function expand(el,wr){stopFx();veil.classList.add('on');wrap.classList.add('on');document.body.classList.add('lock');card.style.transition='none';card.style.opacity='0';card.style.transform='none';sizeCanvas();
 aimAt(wr.left+wr.width/2,wr.top+wr.height/2);ptr.x=ptrT.x;ptr.y=ptrT.y;ptr.on=false;
 const cr=card.getBoundingClientRect();card.style.transform='translate('+(wr.left-cr.left)+'px,'+(wr.top-cr.top)+'px) scale('+(wr.width/cr.width)+','+(wr.height/cr.height)+')';void card.offsetWidth;
 viewer.on=true;cancelAnimationFrame(viewer.raf);viewer.raf=requestAnimationFrame(vframe);
 card.style.transition=reduce?'none':'transform .55s cubic-bezier(.2,.8,.2,1),opacity .25s';card.style.opacity='1';card.style.transform='none';
 setTimeout(()=>{viewer.shown=true;cap.classList.add('on');viewer.busy=false;try{card.focus({preventScroll:true})}catch(e){}},reduce?0:600)}
function closeWin(){if(!viewer.on||viewer.busy)return;viewer.busy=true;cap.classList.remove('on');veil.classList.remove('on');
 const el=viewer.win,wr=el.getBoundingClientRect(),cr=card.getBoundingClientRect();card.style.transition=reduce?'none':'transform .45s cubic-bezier(.5,0,.3,1),opacity .3s .15s';
 card.style.transform='translate('+(wr.left-cr.left)+'px,'+(wr.top-cr.top)+'px) scale('+(wr.width/cr.width)+','+(wr.height/cr.height)+')';card.style.opacity='0';
 setTimeout(()=>{viewer.on=false;cancelAnimationFrame(viewer.raf);wrap.classList.remove('on');document.body.classList.remove('lock');el.classList.remove('open');el.classList.add('closing');refresh();startFx();
  animateDoor(el.querySelector('.door'),false).then(()=>{el.classList.remove('closing');viewer.busy=false})},reduce?0:480)}
stage.addEventListener('click',e=>{const b=e.target.closest('.door');if(b)openWin(b.parentNode)});
// warm the scene's pictures while the finger is still going down
stage.addEventListener('pointerdown',e=>{const w=e.target.closest('.win');if(w&&canOpen(+w.dataset.d))loadScene(+w.dataset.d).catch(()=>{})});
card.addEventListener('click',()=>{if(down&&down.moved)return;closeWin()});veil.addEventListener('click',closeWin);
card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();closeWin()}});
addEventListener('keydown',e=>{if(e.key==='Escape')closeWin()});
// the shared props are wanted by every window, so fetch them once the house is up
addEventListener('load',()=>setTimeout(()=>sheet('common').catch(()=>{}),400));

/* test hooks: ?sheet=SECONDS draws every card at that moment into a grid; ?open=N&t=SECONDS opens window N held at that moment */
const qs=new URLSearchParams(location.search);
window.advent={SC:SC,loadScene:loadScene,renderCard:renderCard,viewer:viewer,open:d=>openWin(stage.querySelector('.win[data-d="'+d+'"]')),close:closeWin};
if(qs.get('sheet')){const ts=qs.get('sheet').split(',').map(Number),cols=6,sw=270,sh=480;Promise.all(SC.map((_,i)=>loadScene(i+1))).then(()=>document.fonts.ready).then(()=>{const s=document.createElement('canvas');s.width=sw*cols;s.height=sh*4*ts.length;s.style.cssText='position:absolute;left:0;top:0;z-index:999;background:#000;width:'+(s.width/2)+'px';document.body.appendChild(s);const g=s.getContext('2d');ts.forEach((t,j)=>SC.forEach((x,i)=>{const o=document.createElement('canvas');o.width=CW*1.5;o.height=CH*1.5;const c=o.getContext('2d');c.scale(1.5,1.5);renderCard(c,i+1,t,{x:0,y:0,cx:180,cy:300,on:false});g.drawImage(o,(i%cols)*sw,(Math.floor(i/cols)+j*4)*sh,sw,sh)}));window.sheetDone=true})}
if(qs.get('open')){const d=+qs.get('open');viewer.frozen=qs.get('t')!=null?+qs.get('t'):null;preview=true;refresh();addEventListener('load',()=>advent.open(d))}
})();
