import assert from 'node:assert/strict';
import {Game,LENGTH,START,LOOP_START,LOOP_END,frame,point,GAPS,CHECKPOINTS,formatTime} from '../dist/core.mjs';
let checks=0;const check=(name,fn)=>{fn();checks++;console.log('PASS',name);};
check('The full track frame is finite, unit length and orthogonal',()=>{
 for(let s=-40;s<LENGTH+60;s+=.35){const f=frame(s);for(const v of [f.p,f.f,f.n,f.r])for(const q of Object.values(v))assert(Number.isFinite(q));for(const v of [f.f,f.n,f.r])assert(Math.abs(Math.hypot(v.x,v.y,v.z)-1)<1e-10);assert(Math.abs(f.f.x*f.n.x+f.f.y*f.n.y+f.f.z*f.n.z)<1e-10);}
 for(const s of [LOOP_START,LOOP_END]){const a=point(s-.001),b=point(s+.001);assert(Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z)<.004);}
});
check('A normal jump leaves the ground and lands',()=>{const g=new Game();g.reset();g.jump();for(let i=0;i<20;i++)g.step(1/120,{});assert(g.h>2);assert(!g.grounded);for(let i=0;i<110;i++)g.step(1/120,{});assert.equal(g.h,0);assert(g.grounded);});
check('Steering accelerates predictably, releases and can fall off the path',()=>{const g=new Game();g.reset();for(let i=0;i<25;i++)g.step(1/120,{steer:1});assert(g.x>1&&g.x<2);for(let i=0;i<40;i++)g.step(1/120,{});assert(Math.abs(g.vx)<.3);for(let i=0;i<120;i++)g.step(1/120,{steer:1});assert(g.retries>0||g.status==='falling');});
check('Pause freezes time and distance, including when falling',()=>{const g=new Game();g.reset();g.step(1/60,{});g.pause();const a=g.snapshot();g.step(1/30,{boost:true});assert.deepEqual(g.snapshot(),a);g.resume();assert.equal(g.status,'running');g.fall();g.pause();g.resume();assert.equal(g.status,'falling');});
check('Ring damage protects briefly; damage without rings retries',()=>{const g=new Game();g.reset();g.ringCount=30;g.damage({});assert.equal(g.ringCount,0);assert(g.invulnerable>0);g.damage({});assert.equal(g.status,'running');g.invulnerable=0;g.damage({});assert.equal(g.status,'falling');for(let i=0;i<110;i++)g.step(1/120,{});assert.equal(g.retries,1);assert.equal(g.status,'running');});
check('Homing attack reaches the selected robot and bounces',()=>{const g=new Game();g.reset();g.s=672;g.h=3;g.grounded=false;g.coyote=0;const target=g.target();assert.equal(target.s,690);g.jump();assert.equal(g.homing,target);for(let i=0;i<24;i++)g.step(1/120,{});assert(target.dead);assert.equal(g.robots,1);assert(g.vy>0);});
check('Each spring clears its gap without input, at normal and boost speeds',()=>{
 for(const boost of [false,true])for(const [a,b] of GAPS){const g=new Game();g.reset();g.s=a-25;g.speed=boost?54:33;let maxHeight=0;for(let i=0;i<420&&g.s<b+8;i++){g.step(1/120,{boost});maxHeight=Math.max(maxHeight,g.h);assert.equal(g.retries,0);assert.equal(g.status,'running');}assert(g.s>b+6);assert(maxHeight>7);}
});
check('Checkpoint recovery preserves course progress and clears held motion',()=>{const g=new Game();g.reset();g.s=CHECKPOINTS[1];g.step(1/120,{});assert.equal(g.checkpointIndex,1);g.s+=40;g.x=5;g.vx=8;g.ringCount=22;g.retry();assert.equal(g.s,CHECKPOINTS[1]);assert.equal(g.x,0);assert.equal(g.vx,0);assert.equal(g.ringCount,0);assert.equal(g.retries,1);});
for(const rate of [30,60,120])check(`Complete the entire level at ${rate} simulation updates per second`,()=>{
 const g=new Game();g.reset();let steps=0,loopSeen=false;
 while(g.status!=='finished'&&steps<rate*160){
   const upcoming=g.objects.find(o=>!o.dead&&!o.hit&&o.type==='spikes'&&Math.abs(g.x-o.x)<2&&o.s>g.s&&o.s-g.s<18);
   if(upcoming&&g.grounded)g.jump();
   g.step(1/rate,{boost:true,steer:0});if(g.s>LOOP_START&&g.s<LOOP_END)loopSeen=true;steps++;
 }
 assert.equal(g.status,'finished');assert.equal(g.retries,0);assert(loopSeen);assert.equal(g.checkpointIndex,2);assert(g.ringCount>100);assert(g.robots>0);assert(g.elapsed<85);console.log(JSON.stringify(g.snapshot()));
});
check('Restart resets game state and score',()=>{const g=new Game();g.reset();g.s=2000;g.ringCount=99;g.retries=7;g.reset();assert.equal(g.s,START);assert.equal(g.ringCount,0);assert.equal(g.retries,0);assert(g.objects.every(o=>!o.dead&&!o.hit));});
check('Time display preserves minutes and hundredths',()=>{assert.equal(formatTime(62.75),'01:02.75');assert.equal(formatTime(0),'00:00.00');});
console.log(`${checks} checks passed.`);
