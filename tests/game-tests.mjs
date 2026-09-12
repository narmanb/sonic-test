import assert from 'node:assert/strict';
import {Game,LENGTH,START,LOOP_START,LOOP_END,LOOPS,frame,point,SPRING_GAPS,JUMP_GAPS,trackSpan,BOOST_SPEED,CHECKPOINTS,formatTime} from '../dist/core.mjs';
let checks=0;const check=(name,fn)=>{fn();checks++;console.log('PASS',name);};
check('The full track frame is finite, unit length and orthogonal',()=>{
 for(let s=-40;s<LENGTH+60;s+=.35){const f=frame(s);for(const v of [f.p,f.f,f.n,f.r])for(const q of Object.values(v))assert(Number.isFinite(q));for(const v of [f.f,f.n,f.r])assert(Math.abs(Math.hypot(v.x,v.y,v.z)-1)<1e-10);assert(Math.abs(f.f.x*f.n.x+f.f.y*f.n.y+f.f.z*f.n.z)<1e-10);}
 for(const s of LOOPS.flatMap(l=>[l.start,l.end])){const a=point(s-.001),b=point(s+.001);assert(Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z)<.004);}
});
check('A normal jump leaves the ground and lands',()=>{const g=new Game();g.reset();g.jump();for(let i=0;i<20;i++)g.step(1/120,{});assert(g.h>2);assert(!g.grounded);for(let i=0;i<110;i++)g.step(1/120,{});assert.equal(g.h,0);assert(g.grounded);});
check('Steering accelerates predictably, releases and can fall off the path',()=>{const g=new Game();g.reset();for(let i=0;i<25;i++)g.step(1/120,{steer:1});assert(g.x>1&&g.x<2);for(let i=0;i<40;i++)g.step(1/120,{});assert(Math.abs(g.vx)<.3);for(let i=0;i<120;i++)g.step(1/120,{steer:1});assert(g.retries>0||g.status==='falling');});
check('Pause freezes time and distance, including when falling',()=>{const g=new Game();g.reset();g.step(1/60,{});g.pause();const a=g.snapshot();g.step(1/30,{boost:true});assert.deepEqual(g.snapshot(),a);g.resume();assert.equal(g.status,'running');g.fall();g.pause();g.resume();assert.equal(g.status,'falling');});
check('Ring damage protects briefly; damage without rings retries',()=>{const g=new Game();g.reset();g.ringCount=30;g.damage({});assert.equal(g.ringCount,0);assert(g.invulnerable>0);g.damage({});assert.equal(g.status,'running');g.invulnerable=0;g.damage({});assert.equal(g.status,'falling');for(let i=0;i<110;i++)g.step(1/120,{});assert.equal(g.retries,1);assert.equal(g.status,'running');});
check('Homing attack reaches the selected robot and bounces',()=>{const g=new Game();g.reset();g.s=672;g.h=3;g.grounded=false;g.coyote=0;const target=g.target();assert.equal(target.s,690);g.jump();assert.equal(g.homing,target);for(let i=0;i<24;i++)g.step(1/120,{});assert(target.dead);assert.equal(g.robots,1);assert(g.vy>0);});
check('Each spring clears its gap without input, at normal and boost speeds',()=>{
 for(const boost of [false,true])for(const [a,b] of SPRING_GAPS){const g=new Game();g.reset();g.s=a-25;g.speed=boost?BOOST_SPEED:33;let maxHeight=0;for(let i=0;i<420&&g.s<b+8;i++){g.step(1/120,{boost});maxHeight=Math.max(maxHeight,g.h);assert.equal(g.retries,0);assert.equal(g.status,'running');}assert(g.s>b+6);assert(maxHeight>7);}
});
check('Checkpoint recovery preserves course progress and clears held motion',()=>{const g=new Game();g.reset();g.s=CHECKPOINTS[1];g.step(1/120,{});assert.equal(g.checkpointIndex,1);g.s+=40;g.x=5;g.vx=8;g.ringCount=22;g.retry();assert.equal(g.s,CHECKPOINTS[1]);assert.equal(g.x,0);assert.equal(g.vx,0);assert.equal(g.ringCount,0);assert.equal(g.retries,1);});
for(const rate of [30,60,120])check(`Complete the entire level at ${rate} simulation updates per second`,()=>{
 const g=new Game();g.reset();let steps=0,loopSeen=false;
 while(g.status!=='finished'&&steps<rate*160){
   const upcoming=g.objects.find(o=>!o.dead&&!o.hit&&['spikes','crate','robot'].includes(o.type)&&Math.abs(g.x-o.x)<2&&o.s>g.s&&o.s-g.s<17);
   const gap=JUMP_GAPS.some(([a])=>a>g.s&&a-g.s<14);
   if((upcoming||gap)&&g.grounded)g.jump();
   g.step(1/rate,{boost:g.energy>6&&!g.boostExhausted,steer:0});if(g.s>LOOP_START&&g.s<LOOP_END)loopSeen=true;steps++;
 }
 assert.equal(g.status,'finished');assert.equal(g.retries,0);assert(loopSeen);assert.equal(g.checkpointIndex,CHECKPOINTS.length-1);assert(g.ringCount>100);assert(g.elapsed<115);console.log(JSON.stringify(g.snapshot()));
});
check('Jump keeps its duration, a single peak and a short apex hold',()=>{
 const g=new Game();g.reset();g.s=35;g.jump();const samples=[];
 while(!g.grounded&&samples.length<180){g.step(1/120,{});samples.push({h:g.h,v:g.vy});}
 const time=samples.length/120,peak=Math.max(...samples.map(a=>a.h));
 assert(time>.85&&time<.94);assert(Math.abs(peak-3.6)<.02);
 const flat=samples.filter(a=>Math.abs(a.v)<1e-6);assert(flat.length>=9&&flat.length<=12);
 let descending=false;for(let i=1;i<samples.length;i++){if(samples[i].h<samples[i-1].h-.0001)descending=true;if(descending)assert(samples[i].h<=samples[i-1].h+.0001);}
 console.log('Jump profile:',{duration:time,peak,apexHold:flat.length/120});
});
check('A nontargeted air dash never restarts the vertical arc',()=>{
 const g=new Game();g.reset();g.s=35;g.jump();for(let i=0;i<68;i++)g.step(1/120,{});
 const velocity=g.vy;assert(velocity<0);g.jump();assert.equal(g.vy,velocity);g.step(1/120,{});assert(g.vy<velocity);
});
check('Homing works barely above ground, ascending, at the apex and descending',()=>{
 for(const [h,vy] of [[.001,18],[2,10],[3.6,0],[2,-10],[.001,-18]]){
  const g=new Game();g.reset();g.s=676;g.h=h;g.vy=vy;g.grounded=false;g.coyote=0;g.jumpKind='jump';
  const target=g.target();assert.equal(target.s,690);g.jump();assert.equal(g.homing,target);
  for(let i=0;i<45;i++)g.step(1/120,{});assert(target.dead);assert.equal(g.robots,1);
 }
});
check('A spring can be targeted high in a jump and just after passing it',()=>{
 for(const distance of [30,1,-3])for(const x of [-4,0,4]){
  const g=new Game();g.reset();const spring=g.objects.find(o=>o.type==='spring');
  g.s=spring.s-distance;g.x=x;g.h=8;g.vy=-4;g.grounded=false;g.coyote=0;g.jumpKind='jump';
  assert.equal(g.target(),spring);g.jump();for(let i=0;i<50&&!spring.hit;i++)g.step(1/120,{});
  assert(spring.hit);assert(g.vy>25);assert.equal(g.robots,0);assert.equal(g.jumpKind,'spring');assert(Math.abs(g.x-x)<.2);
  assert.equal(g.drainEvents().filter(e=>e.type==='spring').length,1);
 }
});
check('Homing is available immediately on a second press after takeoff',()=>{
 const g=new Game();g.reset();g.s=675;g.jump();assert(!g.grounded);g.jump();assert.equal(g.homing?.type,'robot');
});
check('Manual jump gaps require a jump and can be cleared at normal/boost speed',()=>{
 for(const [a,b] of JUMP_GAPS)for(const speed of [33,BOOST_SPEED]){
  const g=new Game();g.reset();g.s=a-13;g.speed=speed;g.x=trackSpan(g.s).center;g.jump();
  for(let i=0;i<240&&g.s<b+2;i++){g.step(1/120,{boost:speed===BOOST_SPEED});assert.equal(g.status,'running');assert.equal(g.retries,0);}
  assert(g.s>b);
  const missed=new Game();missed.reset();missed.s=a-1;missed.speed=speed;
  for(let i=0;i<100&&missed.status==='running';i++)missed.step(1/120,{boost:speed===BOOST_SPEED});assert.equal(missed.status,'falling');
 }
});
check('Boost is faster, drains in about 2.5 seconds without pickups, and re-arms on release',()=>{
 const g=new Game();g.reset();g.rings=[];g.objects=[];
 for(let i=0;i<240;i++)g.step(1/120,{boost:true});assert(g.speed>60);assert(g.energy<21&&g.energy>19);
 for(let i=0;i<70;i++)g.step(1/120,{boost:true});assert(g.boostExhausted);
 for(let i=0;i<130;i++)g.step(1/120,{});assert(!g.boostExhausted);g.step(1/120,{boost:true});assert(g.boosting);
});
check('Restart resets game state and score',()=>{const g=new Game();g.reset();g.s=2000;g.ringCount=99;g.retries=7;g.reset();assert.equal(g.s,START);assert.equal(g.ringCount,0);assert.equal(g.retries,0);assert(g.objects.every(o=>!o.dead&&!o.hit));});
check('Time display preserves minutes and hundredths',()=>{assert.equal(formatTime(62.75),'01:02.75');assert.equal(formatTime(0),'00:00.00');});
console.log(`${checks} checks passed.`);
