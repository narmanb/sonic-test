import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import * as Three from '../dist/three.module.min.js';
import {Game,LOOPS,frame,point,worldAt} from '../dist/core.mjs';
const root=fileURLToPath(new URL('../',import.meta.url)),tmp=await fs.mkdtemp(path.join(os.tmpdir(),'sonic-geometry-'));
const engine=pathToFileURL(path.join(root,'dist/three.module.min.js')).href,core=pathToFileURL(path.join(root,'dist/core.mjs')).href;
const stub=`class RendererStub {constructor(){this.shadowMap={};}setClearColor(){}setPixelRatio(){}setSize(){}render(scene,camera){scene.updateMatrixWorld(true);camera.updateMatrixWorld(true);}}`;
let src=await fs.readFile(path.join(root,'dist/world.mjs'),'utf8');
src=src.replace("import * as T from './three.module.min.js';",`import * as RealT from '${engine}';${stub};const T={...RealT,WebGLRenderer:RendererStub};`).replace("from './core.mjs?v=2'",`from '${core}'`);
await fs.writeFile(path.join(tmp,'world.mjs'),src);
try{
 const {World}=await import(pathToFileURL(path.join(tmp,'world.mjs')).href);
 Object.assign(globalThis,{innerWidth:915,innerHeight:412,devicePixelRatio:2});
 const game=new Game(),world=new World({},game);world.render(1/60);
 const ray=new Three.Raycaster();let checks=0;
 for(const loop of LOOPS){
  let minimum=Infinity;
  for(let a=loop.start-40;a<loop.end+40;a+=2)for(let b=a+60;b<loop.end+40;b+=2){const p=point(a),q=point(b);minimum=Math.min(minimum,Math.hypot(p.x-q.x,p.y-q.y,p.z-q.z));}
  assert(minimum>17,`Loop at ${loop.start} intersects its approach/exit: ${minimum}`);
  const a=point(loop.start),b=point(loop.end);assert(Math.abs(Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z)-Math.abs(loop.shift))<.001);
  console.log('PASS separated loop geometry',{start:loop.start,minDistantSegmentClearance:minimum.toFixed(2)});
 }
 for(const [width,height] of [[915,412],[412,915]])for(const speed of [33,62])for(const loop of LOOPS){
  Object.assign(globalThis,{innerWidth:width,innerHeight:height});world.resize();world.cameraReady=false;game.status='running';game.grounded=true;game.h=0;game.x=0;
  let samples=0,nearestHit=Infinity,maxProjectedY=0;
  for(let s=loop.start-42;s<=loop.end+40;s+=speed/60){
   game.s=s;game.speed=speed;world.render(1/60);
   for(const y of [.35,1.35,2.7]){
    const a=worldAt(s,0,y),target=new Three.Vector3(a.x,a.y,a.z),dir=target.clone().sub(world.camera.position),distance=dir.length();
    ray.set(world.camera.position,dir.normalize());ray.near=.1;ray.far=distance-.12;
    const hits=ray.intersectObjects(world.trackMeshes,false);
    if(hits.length){nearestHit=Math.min(nearestHit,hits[0].distance);throw new Error(`Track hides Sonic: loop ${loop.start}, s=${s}, speed=${speed}, ${width}x${height}, bodyY=${y}, camera hit=${hits[0].distance}`);}
    const screen=target.project(world.camera);maxProjectedY=Math.max(maxProjectedY,Math.abs(screen.y));
    assert(Math.abs(screen.x)<.85&&Math.abs(screen.y)<.98,`Sonic left camera frame at s=${s}: ${screen.x},${screen.y}`);
   }
   samples++;
  }
  checks+=samples;console.log('PASS unobstructed camera through full loop',{loop:loop.start,speed,viewport:`${width}x${height}`,frames:samples,maxProjectedY:maxProjectedY.toFixed(2)});
 }
 // The ball center must not orbit the feet as its visual spin changes.
 game.s=80;game.h=3;game.grounded=false;game.status='running';game.vx=0;world.cameraReady=false;
 const expected=worldAt(80,0,3+1.35*1.05);
 for(let i=0;i<90;i++){world.render(1/60);const center=world.sonic.spin.children[0].getWorldPosition(new Three.Vector3());assert(center.distanceTo(new Three.Vector3(expected.x,expected.y,expected.z))<1e-5);}
 console.log('PASS spin stays centered throughout rotation.');
 for(const type of ['robot','spring']){
  const o=game.objects.find(o=>o.type===type);game.s=o.s-20;game.h=.02;game.grounded=false;game.coyote=0;world.cameraReady=false;world.render(1/60);
  assert.equal(world.targetScreen?.type,type);assert(world.targetScreen.x>0&&world.targetScreen.x<innerWidth);assert(world.targetScreen.y>0&&world.targetScreen.y<innerHeight);
 }
 console.log('PASS low-altitude robot and spring target projection.');
 console.log(`${checks} camera samples checked against actual track triangles. GPU rendering is stubbed; this is not a hardware FPS test.`);
}finally{await fs.rm(tmp,{recursive:true,force:true});}
