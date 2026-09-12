export const LENGTH = 2820;
export const START = 22;
export const HALF_WIDTH = 6.7;
export const LOOPS = [
  {start:850,length:176,radius:28,shift:30,name:'SKYLINE LOOP'},
  {start:2250,length:202,radius:32,shift:-32,name:'HORIZON LOOP'}
].map(loop=>({...loop,end:loop.start+loop.length}));
export const LOOP_START = LOOPS[0].start;
export const LOOP_LENGTH = LOOPS[0].length;
export const LOOP_END = LOOPS[0].end;
export const SPRING_GAPS = [[470,496],[1390,1416],[1920,1945]];
export const JUMP_GAPS = [[1580,1592],[2570,2582],[2640,2652]];
export const GAPS = [...SPRING_GAPS,...JUMP_GAPS].sort((a,b)=>a[0]-b[0]);
export const CHECKPOINTS = [620,1235,1730,2505];
export const BOOST_SPEED = 62;
export const BOOST_DRAIN = 40;
export const JUMP_SPEED = 18;
export const JUMP_GRAVITY = 45;
export const APEX_HOLD = .085;
export const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const sin = Math.sin, cos = Math.cos;
const TAU = Math.PI * 2;
const smooth = u => (u=clamp(u,0,1),u*u*(3-2*u));
export const loopAt = (s,padding=0) => LOOPS.find(loop=>s>=loop.start-padding&&s<=loop.end+padding);
export const isLoop = s => !!loopAt(s);
export const isGap = s => GAPS.some(([a,b]) => s > a && s < b);
export const baseX = w => sin(w*.006)*32 + sin(w*.014)*9;
export const baseY = w => 9 + sin(w*.008)*3.5 + sin(w*.003)*7;
const norm = v => {const n=Math.hypot(v.x,v.y,v.z);return {x:v.x/n,y:v.y/n,z:v.z/n};};
const cross = (a,b) => ({x:a.y*b.z-a.z*b.y,y:a.z*b.x-a.x*b.z,z:a.x*b.y-a.y*b.x});
function baseFrame(w) {
  const dx=cos(w*.006)*.192+cos(w*.014)*.126,dy=cos(w*.008)*.028+cos(w*.003)*.021;
  const f=norm({x:dx,y:dy,z:-1}),r=norm({x:1,y:0,z:dx});
  return {f,r,n:norm(cross(r,f))};
}
// Each loop advances sideways by more than two road widths. Entry and exit
// stay parallel and separate; there is no returning ribbon across the approach.
export function point(s) {
  let removed=0,offset={x:0,y:0,z:0};
  for(const loop of LOOPS){
    if(s<loop.start)break;
    const w=loop.start-removed,{f,r,n}=baseFrame(w);
    if(s<=loop.end){
      const u=(s-loop.start)/loop.length,a=u*TAU,forward=loop.radius*sin(a),up=loop.radius*(1-cos(a)),side=loop.shift*smooth(u);
      return {x:baseX(w)+offset.x+f.x*forward+n.x*up+r.x*side,y:baseY(w)+offset.y+f.y*forward+n.y*up+r.y*side,z:-w+offset.z+f.z*forward+n.z*up+r.z*side};
    }
    offset.x+=r.x*loop.shift;offset.y+=r.y*loop.shift;offset.z+=r.z*loop.shift;removed+=loop.length;
  }
  const w=s-removed;
  return {x:baseX(w)+offset.x,y:baseY(w)+offset.y,z:-w+offset.z};
}
export function frame(s) {
  const p=point(s), a=point(s-.05), b=point(s+.05);
  const f=norm({x:b.x-a.x,y:b.y-a.y,z:b.z-a.z});
  let w=s;for(const loop of LOOPS){if(s<loop.start)break;if(s<=loop.end){w=loop.start-(s-w);break;}w-=loop.length;}
  let r=baseFrame(w).r;
  const dot=r.x*f.x+r.y*f.y+r.z*f.z;
  r=norm({x:r.x-dot*f.x,y:r.y-dot*f.y,z:r.z-dot*f.z});
  const n=norm(cross(r,f));
  return {p,f,r,n};
}
export function trackSpan(s) {
  const narrow=s>=2515&&s<=2730?smooth((s-2515)/22)*smooth((2730-s)/22):0;
  return {center:narrow*sin((s-2515)/215*TAU)*2.2,halfWidth:HALF_WIDTH-narrow*3.45};
}
export function targetX(object,playerX) {
  if(object.type!=='spring'||!object.wide)return object.x;
  return [-4.1,0,4.1].reduce((a,b)=>Math.abs(b-playerX)<Math.abs(a-playerX)?b:a);
}
export function worldAt(s,x=0,y=0) {
  const {p,r,n}=frame(s);
  return {x:p.x+r.x*x+n.x*y,y:p.y+r.y*x+n.y*y,z:p.z+r.z*x+n.z*y};
}
export function makeLevel() {
  const rings=[], objects=[];
  const obj=(type,s,x=0,extra={})=>objects.push({type,s,x,dead:false,hit:false,...extra});
  // A readable, generous first stretch teaches steering and ring collection.
  for(let s=38;s<LENGTH-30;s+=5) {
    const span=trackSpan(s);
    let x=s>=2515?span.center:sin(s*.014)*2.65, y=1.35;
    if(isLoop(s)) x=0;
    const jump=SPRING_GAPS.find(([a,b])=>s>a-12 && s<b+12);
    if(jump) {
      x=0;
      const t=(s-(jump[0]-14))/37;
      y=1.35+Math.max(0,29*t-19*t*t);
    }
    const hop=JUMP_GAPS.find(([a,b])=>s>a-12&&s<b+7);
    if(hop){const t=clamp((s-(hop[0]-12))/32,0,1);y=1.35+3.6*4*t*(1-t);}
    rings.push({s,x,y,collected:false});
  }
  for(const s0 of [100,310,570,1080,1500,1780,2080])
    for(let i=0;i<7;i++) for(const x of [-3.5,3.5]) rings.push({s:s0+i*4,x,y:1.35,collected:false});
  obj('spikes',187,-3.5); obj('spikes',243,1.9);
  obj('crate',325,0); obj('crate',328,-3.5);
  obj('robot',380,2.5); obj('robot',586,-1.8);
  obj('robot',690,0); obj('robot',716,2); obj('robot',745,-1.7);
  obj('spikes',789,-3.1);
  obj('crate',1110,-3.5); obj('crate',1110,0); obj('robot',1165,2.3);
  obj('spikes',1295,2.9); obj('spikes',1330,-2.8);
  obj('robot',1495,0); obj('robot',1520,-2.5); obj('robot',1545,2.5);
  obj('crate',1608,2.8); obj('crate',1644,-2.8);
  obj('spikes',1686,0); obj('spikes',1820,-3.1); obj('robot',1858,2.4);
  obj('crate',2010,-3.3); obj('crate',2010,3.3);
  obj('robot',2070,0); obj('robot',2100,2.5); obj('robot',2140,-2.5);
  obj('robot',2200,1.6);obj('crate',2482,-3.3);obj('robot',2765,0);
  for(const s of [105,552,823,1070,1260,1460,1750,1975,2180]) obj('dash',s,0);
  for(const [a] of SPRING_GAPS) obj('spring',a-14,0,{wide:true});
  for(const [a] of JUMP_GAPS) obj('jumpmark',a-14,trackSpan(a-14).center);
  return {rings,objects};
}
export class Game {
  constructor() {this.reset();this.status='ready';}
  reset() {
    const data=makeLevel();this.rings=data.rings;this.objects=data.objects;
    this.s=START;this.x=0;this.h=0;this.vy=0;this.vx=0;this.speed=0;this.energy=100;
    this.ringCount=0;this.ringsCollected=0;this.robots=0;this.retries=0;this.elapsed=0;
    this.checkpoint=START;this.checkpointIndex=-1;this.invulnerable=0;this.dash=0;
    this.grounded=true;this.airAction=false;this.boosting=false;this.homing=null;this.homingFlight=null;
    this.jumpKind=null;this.apexAvailable=false;this.apexTime=0;this.boostExhausted=false;
    this.fallTime=0;this.jumpBuffer=0;this.coyote=.12;this.events=[];this.status='running';
  }
  emit(type,data={}) {this.events.push({type,...data});}
  drainEvents(){const e=this.events;this.events=[];return e;}
  pause(){if(this.status==='running'||this.status==='falling'){this.beforePause=this.status;this.status='paused';}}
  resume(){if(this.status==='paused')this.status=this.beforePause||'running';}
  retry() {
    this.retries++;this.s=this.checkpoint;this.x=0;this.h=0;this.vy=0;this.vx=0;
    this.speed=22;this.energy=Math.max(this.energy,65);this.ringCount=0;
    this.invulnerable=2.5;this.dash=0;this.homing=null;this.homingFlight=null;this.grounded=true;
    this.jumpKind=null;this.apexAvailable=false;this.apexTime=0;this.boostExhausted=false;
    this.airAction=false;this.boosting=false;this.coyote=.12;this.jumpBuffer=0;this.fallTime=0;
    for(const o of this.objects) if(o.s>=this.checkpoint){o.hit=false;o.dead=false;}
    for(const r of this.rings) if(r.s>=this.checkpoint) r.collected=false;
    this.status='running';this.emit('retry');
  }
  target() {
    if(this.status!=='running'||this.grounded||isLoop(this.s))return null;
    if(this.homing)return this.homing;
    let nearest=null,best=Infinity;
    for(const o of this.objects) {
      if(o.dead||(o.type!=='robot'&&o.type!=='spring')||(o.type==='spring'&&o.hit))continue;
      const d=o.s-this.s,dx=targetX(o,this.x)-this.x;
      const min=o.type==='spring'?-5:-1,max=o.type==='spring'?42:35;
      if(d<min||d>max||Math.abs(dx)>7)continue;
      // A spring just underneath/behind the player remains rescuable mid-jump.
      const score=Math.hypot(d,dx*1.6,(this.h-1)*.55);
      if(score<best){nearest=o;best=score;}
    }
    return nearest;
  }
  jump() {
    if(this.status!=='running'||isLoop(this.s))return;
    if(this.grounded){this.launchJump();return;}
    if(this.homing)return;
    const t=this.target();
    if(t){
      this.homing=t;this.airAction=true;this.apexTime=0;this.apexAvailable=false;
      const x=targetX(t,this.x),h=t.type==='spring'?.2:1.1;
      this.homingFlight={s:this.s,x:this.x,h:this.h,toX:x,toH:h,time:0,duration:clamp(Math.hypot(t.s-this.s,x-this.x,h-this.h)/125,.07,.32)};
      this.emit('homing');
    }else if(this.coyote>0){this.launchJump();}
    else if(!this.airAction){this.airAction=true;this.dash=Math.max(this.dash,.22);this.emit('airdash');}
  }
  launchJump(){
    this.vy=JUMP_SPEED;this.grounded=false;this.jumpBuffer=0;this.coyote=0;
    this.airAction=false;this.jumpKind='jump';this.apexAvailable=true;this.apexTime=0;this.emit('jump');
  }
  launchSpring(o){
    o.hit=true;this.homing=null;this.homingFlight=null;this.vy=29;this.h=.2;
    this.grounded=false;this.coyote=0;this.jumpKind='spring';this.apexAvailable=false;this.apexTime=0;
    this.airAction=false;this.dash=Math.max(this.dash,1.4);this.emit('spring');
  }
  damage(o) {
    if(this.invulnerable>0)return;
    o.hit=true;
    if(this.ringCount>0){
      const lost=this.ringCount;this.ringCount=0;this.invulnerable=2.3;
      this.speed=18;this.dash=0;this.energy=Math.max(0,this.energy-12);this.emit('hurt',{lost});
    } else {this.fall('hit');}
  }
  fall(reason='fall') {
    if(this.status!=='running')return;
    this.status='falling';this.fallTime=0;this.boosting=false;this.homing=null;this.homingFlight=null;
    this.vy=-6;this.emit('fall',{reason});
  }
  step(dt,input={}) {
    dt=clamp(dt,0,1/30);
    if(this.status!=='running'&&this.status!=='falling')return;
    this.elapsed+=dt;
    if(this.status==='falling') {
      this.fallTime+=dt;this.vy-=30*dt;this.h+=this.vy*dt;
      if(this.fallTime>.85)this.retry();
      return;
    }
    const prev=this.s;
    this.invulnerable=Math.max(0,this.invulnerable-dt);
    this.dash=Math.max(0,this.dash-dt);this.jumpBuffer=Math.max(0,this.jumpBuffer-dt);
    const loop=isLoop(this.s);
    if(!input.boost&&this.energy>=5)this.boostExhausted=false;
    this.boosting=!!input.boost&&!this.boostExhausted&&this.energy>0;
    if(this.boosting){this.energy=Math.max(0,this.energy-BOOST_DRAIN*dt);if(this.energy===0)this.boostExhausted=true;}
    else this.energy=Math.min(100,this.energy+4.5*dt);
    let targetSpeed=this.boosting?BOOST_SPEED:this.dash>0?49:33;
    if(input.brake)targetSpeed=18;
    if(loop)targetSpeed=Math.max(targetSpeed,39);
    this.speed+=(targetSpeed-this.speed)*(1-Math.exp(-2.8*dt));
    if(this.homing) {
      const t=this.homing,a=this.homingFlight;a.time+=dt;const u=clamp(a.time/a.duration,0,1);
      this.s=a.s+(t.s-a.s)*u;this.x=a.x+(a.toX-a.x)*u;this.h=a.h+(a.toH-a.h)*u;
      if(u>=1){
        if(t.type==='spring')this.launchSpring(t);
        else {
          t.dead=true;this.robots++;this.homing=null;this.homingFlight=null;this.vy=13;this.h=1.4;
          this.jumpKind='bounce';this.apexAvailable=false;this.apexTime=0;
          this.grounded=false;this.airAction=false;this.energy=Math.min(100,this.energy+12);
          this.emit('destroy',{object:t});
        }
      }
    }else {
      this.s+=this.speed*dt;
      const steer=clamp(input.steer||0,-1,1);
      const want=loop?-this.x*3:steer*(this.grounded?11:9);
      this.vx+=(want-this.vx)*(1-Math.exp(-12*dt));
      this.x+=this.vx*dt;
      if(loop) {this.h=0;this.vy=0;this.grounded=true;this.airAction=false;this.jumpKind=null;this.apexAvailable=false;this.apexTime=0;}
      else {
        if(this.grounded)this.coyote=.1;else this.coyote=Math.max(0,this.coyote-dt);
        if(this.jumpBuffer>0&&(this.grounded||this.coyote>0)) {
          this.launchJump();
        }
        const previousHeight=this.h;
        if(this.grounded&&isGap(this.s)){this.grounded=false;this.jumpKind='drop';this.vy=0;}
        if(!this.grounded){
          let moveTime=dt;
          if(this.apexTime>0){const hold=Math.min(moveTime,this.apexTime);this.apexTime-=hold;moveTime-=hold;}
          if(moveTime>0){
            const gravity=this.jumpKind==='spring'?38:JUMP_GRAVITY;
            if(this.apexAvailable&&this.vy>0&&this.vy-gravity*moveTime<=0){
              const ascentTime=this.vy/gravity;
              this.h+=this.vy*ascentTime-.5*gravity*ascentTime*ascentTime;
              this.vy=0;this.apexAvailable=false;this.apexTime=APEX_HOLD-(moveTime-ascentTime);
            }else{this.h+=this.vy*moveTime-.5*gravity*moveTime*moveTime;this.vy-=gravity*moveTime;}
          }
        }
        if(this.h<=0) {
          if(isGap(this.s)){if(this.h< -1.6){this.fall();return;}}
          else if(previousHeight<-.12){this.fall();return;}
          else {
            if(!this.grounded)this.emit('land');
            this.h=0;this.vy=0;this.grounded=true;this.airAction=false;this.jumpKind=null;this.apexTime=0;
          }
        }
      }
    }
    const span=trackSpan(this.s);
    if(Math.abs(this.x-span.center)>span.halfWidth+.35&&this.h<.5){this.fall();return;}
    if(Math.abs(this.x)>HALF_WIDTH+2.2){this.fall();return;}
    for(const o of this.objects) {
      if(o.dead||o.hit||o===this.homing||o.s<prev-1.7||o.s>this.s+1.7)continue;
      const dx=Math.abs(this.x-o.x);
      if(o.type==='spring' && dx<HALF_WIDTH+.2 && this.h<2.8) {
        this.launchSpring(o);continue;
      }
      if(o.type==='dash' && dx<2.35 && this.h<1.2) {
        o.hit=true;this.dash=1.25;this.energy=Math.min(100,this.energy+12);this.emit('dash');continue;
      }
      if(o.type==='robot' && dx<1.55 && this.h<2.6) {
        if(this.boosting||!this.grounded) {
          o.dead=true;this.robots++;this.energy=Math.min(100,this.energy+12);
          if(!this.grounded){this.vy=13;this.airAction=false;this.jumpKind='bounce';this.apexTime=0;this.apexAvailable=false;}
          this.emit('destroy',{object:o});
        } else this.damage(o);
      }
      if(o.type==='crate' && dx<1.8 && this.h<2.1) {
        if(this.boosting || (!this.grounded&&this.vy<0&&this.h>1.2)) {o.dead=true;this.emit('destroy',{object:o});this.energy=Math.min(100,this.energy+6);}
        else this.damage(o);
      }
      if(o.type==='spikes'&&dx<1.65&&this.h<1.3)this.damage(o);
      if(this.status!=='running')return;
    }
    for(const r of this.rings){
      if(r.collected||r.s<prev-1.6||r.s>this.s+1.6)continue;
      if(Math.abs(this.x-r.x)<(this.boosting?2.7:1.45)&&Math.abs(this.h+1.35-r.y)<1.65){
        r.collected=true;this.ringCount++;this.ringsCollected++;this.energy=Math.min(100,this.energy+1.8);
        this.emit('ring',{ring:r});
      }
    }
    for(let i=this.checkpointIndex+1;i<CHECKPOINTS.length;i++)if(this.s>=CHECKPOINTS[i]) {
      this.checkpoint=CHECKPOINTS[i];this.checkpointIndex=i;this.emit('checkpoint');
    }
    for(const entry of LOOPS)if(prev<entry.start&&this.s>=entry.start)this.emit('loop');
    if(this.s>=LENGTH){this.s=LENGTH;this.status='finished';this.boosting=false;this.emit('finish');}
  }
  snapshot(){return {status:this.status,distance:Math.round(this.s-START),length:LENGTH-START,rings:this.ringCount,time:this.elapsed,boost:Math.round(this.energy),checkpoint:this.checkpointIndex+1,retries:this.retries};}
}
export function formatTime(seconds) {
  const min=Math.floor(seconds/60), sec=Math.floor(seconds%60), hundredths=Math.floor(seconds*100)%100;
  return `${String(min).padStart(2,'0')}:${String(sec).padStart(2,'0')}.${String(hundredths).padStart(2,'0')}`;
}
