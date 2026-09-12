import * as T from './three.module.min.js';
import {LENGTH,START,HALF_WIDTH,LOOPS,loopAt,GAPS,JUMP_GAPS,CHECKPOINTS,frame,point,worldAt,isGap,isLoop,trackSpan,targetX,clamp} from './core.mjs';
const UP=new T.Vector3(0,1,0), V=(p)=>new T.Vector3(p.x,p.y,p.z);
const palette={blue:0x0965e6,navy:0x064cb1,skin:0xf4c296,white:0xffffff,red:0xf33c3e,grass:0x70cd3a,grassDark:0x309655,sand:0xf6d68b,stone:0xc87e49,gold:0xffd12c};
const materials=new Map();
function mat(color,roughness=.7,metalness=0){const key=[color,roughness,metalness].join();if(!materials.has(key))materials.set(key,new T.MeshStandardMaterial({color,roughness,metalness}));return materials.get(key);}
const geos={box:new T.BoxGeometry(1,1,1),ball:new T.SphereGeometry(1,16,12),lowball:new T.IcosahedronGeometry(1,1),cylinder:new T.CylinderGeometry(1,1,1,8),cone:new T.ConeGeometry(1,1,9),ring:new T.TorusGeometry(.48,.095,6,16)};
const dummy=new T.Object3D(), tempMatrix=new T.Matrix4(), tempQ=new T.Quaternion();
function mesh(g,m,parent,pos=[0,0,0],scale=[1,1,1]){const o=new T.Mesh(g,m);o.position.set(...pos);o.scale.set(...scale);if(parent)parent.add(o);return o;}
function ball(parent,color,pos,scale){return mesh(geos.ball,mat(color),parent,pos,scale);}
function bar(parent,a,b,radius,color){const pa=new T.Vector3(...a),pb=new T.Vector3(...b),d=pb.clone().sub(pa);const o=mesh(geos.cylinder,mat(color),parent,pa.add(pb).multiplyScalar(.5).toArray(),[radius,d.length(),radius]);o.quaternion.setFromUnitVectors(UP,d.normalize());return o;}
function coneBetween(parent,a,b,radius,color){const pa=new T.Vector3(...a),pb=new T.Vector3(...b),d=pb.clone().sub(pa);const o=mesh(geos.cone,mat(color),parent,pa.add(pb).multiplyScalar(.5).toArray(),[radius,d.length(),radius]);o.quaternion.setFromUnitVectors(UP,d.normalize());return o;}
function atFrame(object,s,x=0,y=0){const fr=frame(s);object.position.copy(V(fr.p)).addScaledVector(V(fr.r),x).addScaledVector(V(fr.n),y);object.quaternion.setFromRotationMatrix(tempMatrix.makeBasis(V(fr.r),V(fr.n),V(fr.f).negate()));return object;}
function seeded(seed=2026){return ()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;};}
class Instances {
  constructor(scene){this.scene=scene;this.groups=new Map();}
  add(key,geo,material,pos,scale=[1,1,1],rotation=[0,0,0]){
    let group=this.groups.get(key);if(!group){group={geo,material,matrices:[]};this.groups.set(key,group);}
    dummy.position.copy(pos instanceof T.Vector3?pos:V(pos));dummy.scale.set(...scale);
    if(rotation instanceof T.Quaternion)dummy.quaternion.copy(rotation);else dummy.rotation.set(...rotation);
    dummy.updateMatrix();group.matrices.push(dummy.matrix.clone());
  }
  finish(){for(const g of this.groups.values()){const obj=new T.InstancedMesh(g.geo,g.material,g.matrices.length);g.matrices.forEach((m,i)=>obj.setMatrixAt(i,m));obj.computeBoundingSphere();this.scene.add(obj);}this.groups.clear();}
}
function makeSonic(){
  const root=new T.Group(), body=new T.Group();root.add(body);
  ball(body,palette.blue,[0,1.32,.1],[.47,.64,.42]);
  ball(body,palette.skin,[0,1.32,-.29],[.31,.46,.145]);
  ball(body,palette.blue,[0,2.22,-.035],[.73,.7,.63]);
  // Hand-modelled silhouette: swept head quills and two smaller back quills.
  for(const [a,b,r] of [
    [[-.46,2.51,.16],[-.94,2.3,.95],.36],[[.46,2.51,.16],[.94,2.3,.95],.36],
    [[-.49,2.12,.24],[-.87,1.64,1.06],.4],[[.49,2.12,.24],[.87,1.64,1.06],.4],
    [[0,2.58,.3],[0,2.46,1.33],.46],[[0,2.07,.36],[0,1.33,1.2],.43],
    [[-.19,1.37,.37],[-.44,.98,.99],.26],[[.19,1.37,.37],[.44,.98,.99],.26]
  ]) coneBetween(body,a,b,r,palette.blue);
  for(const x of [-.43,.43]) {
    coneBetween(body,[x,2.65,-.02],[x*1.18,3.16,-.09],.25,palette.blue);
    const inner=mesh(new T.ConeGeometry(.135,.33,3),mat(palette.skin),body,[x*1.11,2.96,-.163]);inner.rotation.y=Math.PI;
    ball(body,palette.white,[x*.53,2.33,-.549],[.28,.36,.14]);
    ball(body,0x24aa55,[x*.49,2.32,-.677],[.073,.192,.044]);
    ball(body,0x052b37,[x*.49,2.32,-.711],[.032,.13,.018]);
    ball(body,palette.white,[x*.49-.015,2.39,-.73],[.018,.045,.01]);
  }
  ball(body,palette.skin,[-.2,1.98,-.568],[.37,.22,.23]);ball(body,palette.skin,[.2,1.98,-.568],[.37,.22,.23]);
  ball(body,0x0a1830,[0,2.1,-.816],[.15,.13,.14]);
  const smileCurve=new T.CatmullRomCurve3([new T.Vector3(.21,1.954,-.772),new T.Vector3(.34,1.945,-.73),new T.Vector3(.415,1.994,-.683)]);
  mesh(new T.TubeGeometry(smileCurve,8,.015,4,false),mat(0x82492e),body);
  const legs=[],arms=[];
  for(const side of [-1,1]){
    const leg=new T.Group();leg.position.set(side*.28,.91,.09);body.add(leg);legs.push(leg);
    bar(leg,[0,0,0],[side*.02,-.65,.05],.108,palette.blue);
    ball(leg,palette.white,[side*.02,-.6,.025],[.19,.16,.19]);
    ball(leg,palette.red,[side*.025,-.76,-.21],[.25,.22,.52]);
    ball(leg,palette.white,[side*.025,-.9,-.2],[.26,.075,.53]);
    const strap=mesh(geos.box,mat(palette.white),leg,[side*.025,-.72,-.21],[.51,.14,.16]);strap.rotation.x=-.12;
    mesh(geos.box,mat(palette.gold,.4,.3),leg,[side*.275,-.74,-.2],[.04,.15,.14]);
    const arm=new T.Group();arm.position.set(side*.43,1.65,.04);body.add(arm);arms.push(arm);
    bar(arm,[0,0,0],[side*.19,-.46,.1],.083,palette.skin);
    bar(arm,[side*.19,-.46,.1],[side*.18,-.67,-.11],.087,palette.skin);
    ball(arm,palette.white,[side*.18,-.63,-.09],[.17,.14,.17]);
    ball(arm,palette.white,[side*.18,-.81,-.15],[.205,.23,.2]);
    ball(arm,palette.white,[side*.02,-.77,-.235],[.11,.15,.12]);
  }
  const spin=new T.Group();root.add(spin);spin.visible=false;
  ball(spin,palette.blue,[0,1.35,0],[.9,.9,.9]);
  for(let i=0;i<6;i++){const a=i*Math.PI/3;coneBetween(spin,[sin(a)*.5,1.35+cos(a)*.5,0],[sin(a+.4)*1.04,1.35+cos(a+.4)*1.04,.25],.28,palette.navy);}
  for(let i=0;i<2;i++){const streak=mesh(new T.TorusGeometry(.79,.06,5,32,3.3),mat(0x82dfff,.4),spin,[0,1.35,0]);streak.rotation.set(.6+i*1.1,.4+i,.5);}
  // Rotate the curled-up body about its center, not the character's feet.
  spin.position.y=1.35;for(const child of spin.children)child.position.y-=1.35;
  root.traverse(o=>{if(o.isMesh)o.castShadow=true;});
  return {root,body,legs,arms,spin};
}
const sin=Math.sin,cos=Math.cos;
function addQuad(data,a,b,c,d,color){const cl=new T.Color(color);for(const v of [a,b,c,a,c,d]){data.p.push(v.x,v.y,v.z);data.c.push(cl.r,cl.g,cl.b);}}
function finishGeometry(data){const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(data.p,3));g.setAttribute('color',new T.Float32BufferAttribute(data.c,3));g.computeVertexNormals();g.computeBoundingSphere();return g;}
function terrain(scene){
  const trackMat=new T.MeshStandardMaterial({vertexColors:true,roughness:.93,side:T.DoubleSide});
  const inst=new Instances(scene),surfaces=[];
  for(let chunk=-40;chunk<LENGTH+65;chunk+=40){
    const data={p:[],c:[]};
    for(let s=chunk;s<Math.min(chunk+40,LENGTH+65);s+=2){
      if(isGap(s+1))continue;
      const a=trackSpan(s),b=trackSpan(s+2);
      const A=(x,y)=>worldAt(s,a.center+x*a.halfWidth/HALF_WIDTH,y), B=(x,y)=>worldAt(s+2,b.center+x*b.halfWidth/HALF_WIDTH,y);
      const road=(Math.floor(s/8)%2===0)?0xf6d792:0xf2d18a;
      addQuad(data,A(-5.05,0),B(-5.05,0),B(5.05,0),A(5.05,0),road);
      for(const side of [-1,1]){
        addQuad(data,A(side*5.05,0),B(side*5.05,0),B(side*HALF_WIDTH,0),A(side*HALF_WIDTH,0),Math.floor(s/4)%2?0x79d646:0x81db4d);
        addQuad(data,A(side*5.05,.014),B(side*5.05,.014),B(side*5.19,.014),A(side*5.19,.014),0xeefac7);
        addQuad(data,A(side*(HALF_WIDTH-.13),.04),B(side*(HALF_WIDTH-.13),.04),B(side*HALF_WIDTH,.04),A(side*HALF_WIDTH,.04),0xdaf285);
        for(let row=0;row<3;row++)addQuad(data,A(side*HALF_WIDTH,-row*1.23),B(side*HALF_WIDTH,-row*1.23),B(side*HALF_WIDTH,-(row+1)*1.23),A(side*HALF_WIDTH,-(row+1)*1.23),(Math.floor(s/4)+row)%2?0xc2854b:0xebb97a);
      }
      addQuad(data,A(-HALF_WIDTH,-3.69),A(HALF_WIDTH,-3.69),B(HALF_WIDTH,-3.69),B(-HALF_WIDTH,-3.69),0x9c754d);
    }
    if(data.p.length){const o=mesh(finishGeometry(data),trackMat,scene);o.receiveShadow=true;o.userData.trackFrom=chunk;o.userData.trackTo=chunk+40;surfaces.push(o);}
  }
  // End caps and high-contrast lips make real jumps readable before takeoff.
  for(const [a,b] of GAPS)for(const s of [a,b]){
    const span=trackSpan(s),fr=frame(s),q=new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(V(fr.r),V(fr.n),V(fr.f).negate()));
    inst.add('gap-caps',geos.box,mat(0xe6b37a),worldAt(s,span.center,-1.8),[span.halfWidth*2,3.6,.12],q);
    inst.add('gap-lips',geos.box,mat(JUMP_GAPS.some(g=>g[0]===a)?0x47e6ed:0xffd855),worldAt(s,span.center,.04),[span.halfWidth*2,.1,.45],q);
  }
  // Regular columns beneath the suspended path create a readable silhouette.
  for(let s=0;s<LENGTH;s+=56){
    if(isGap(s)||loopAt(s,32))continue;const p=point(s),span=trackSpan(s);
    inst.add('columns',geos.cylinder,mat(0xc39366),{x:p.x,y:(p.y-8)/2-2,z:p.z},[2.5,(p.y+8)-4,2.5]);
    inst.add('capstones',geos.box,mat(0xe9b879),worldAt(s,span.center,-3.6),[Math.min(9,span.halfWidth*1.4),.7,4]);
  }
  // Gateways, stone ruins, and low guard lines around the elevated loop.
  for(const s of [12,...CHECKPOINTS.map(s=>s-1),LENGTH+2]) {
    const fr=frame(s), q=new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(V(fr.r),V(fr.n),V(fr.f).negate()));
    for(const x of [-7.9,7.9]){
      inst.add('gate-stone',geos.box,mat(0xf2d19a),worldAt(s,x,4.4),[1.7,11,1.8],q);
      inst.add('gate-blue',geos.box,mat(0x137daf,.55),worldAt(s,x,2.7),[1.86,.5,1.97],q);
      inst.add('gate-blue',geos.box,mat(0x137daf,.55),worldAt(s,x,7.3),[1.86,.5,1.97],q);
      inst.add('gate-caps',geos.box,mat(0xffdc79),worldAt(s,x,10.1),[2.35,.7,2.45],q);
    }
    inst.add('gate-cross',geos.box,mat(0xf2d19a),worldAt(s,0,10),[17.4,1.1,1.8],q);
    for(let i=-3;i<=3;i++)inst.add('gate-inlay',geos.box,mat(i%2?0x2182be:0xffd65a),worldAt(s,i*1.9,10),[.75,.8,1.88],q);
  }
  for(const loop of LOOPS)for(let s=loop.start-10;s<loop.end+10;s+=3.4)for(const side of [-1,1]){
    const fr=frame(s),q=new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(V(fr.r),V(fr.n),V(fr.f).negate()));
    inst.add('loop-edging',geos.box,mat(0x1cbbbb,.38,.25),worldAt(s,side*6.58,.22),[.26,.4,3.6],q);
  }
  inst.finish();
  return surfaces;
}
function scenery(scene){
  const rng=seeded(99),inst=new Instances(scene);
  const islandGeo=new T.CylinderGeometry(1,1.14,1,12,1),grassGeo=new T.CylinderGeometry(1,1.04,1,12,1);
  const leafGeo=new T.BufferGeometry();leafGeo.setAttribute('position',new T.Float32BufferAttribute([0,0,0,-.55,.3,-1.25,0,.65,-2.15,0,0,0,0,.65,-2.15,.55,.3,-1.25,-.55,.3,-1.25,-.19,-.5,-4.5,0,.65,-2.15,0,.65,-2.15,-.19,-.5,-4.5,.55,.3,-1.25],3));leafGeo.computeVertexNormals();
  const leafMat=new T.MeshStandardMaterial({color:0x269755,roughness:.8,side:T.DoubleSide});
  const flowerGeo=new T.CylinderGeometry(.5,.5,.15,7);
  function palm(pos,scale,rot){
    const trunkHeight=6*scale;
    inst.add('palm-trunks',geos.cylinder,mat(0xb58a58),{x:pos.x+.3*scale,y:pos.y+trunkHeight/2,z:pos.z},[.28*scale,trunkHeight,.29*scale],[0,rot,-.1]);
    for(let j=0;j<3;j++)inst.add('coconuts',geos.lowball,mat(0x805034),{x:pos.x+.5*scale+cos(j*2)*.4*scale,y:pos.y+trunkHeight-.15,z:pos.z+sin(j*2)*.4*scale},[.3*scale,.36*scale,.3*scale]);
    for(let j=0;j<6;j++)inst.add('palm-leaves',leafGeo,leafMat,{x:pos.x+.6*scale,y:pos.y+trunkHeight,z:pos.z},[scale,scale,scale],[.12+sin(j)*.12,rot+j*Math.PI/3,0]);
  }
  for(let s=-40;s<LENGTH+150;s+=44){
    if(loopAt(s,45))continue;const p=point(s);
    for(const side of [-1,1]){
      const near=rng()>.32,away=near?13+rng()*13:43+rng()*50;
      const rad=near?6+rng()*10:15+rng()*23, top=near?p.y-3-rng()*3:2+rng()*10;
      const pos=worldAt(s,side*away,0);pos.y=top;
      inst.add('island-rock',islandGeo,mat(0xb57d52),{x:pos.x,y:top-7,z:pos.z},[rad,13,rad*.8],[0,rng()*6,0]);
      inst.add('island-grass',grassGeo,mat(0x5fbd4f),{x:pos.x,y:top-.3,z:pos.z},[rad*1.05,.8,rad*.85],[0,0,0]);
      inst.add('island-shallows',geos.cylinder,new T.MeshBasicMaterial({color:0x60ddd1,transparent:true,opacity:.38}),{x:pos.x,y:-6.8,z:pos.z},[rad*1.5,.1,rad*1.17]);
      if(near||rng()>.35){palm({x:pos.x-1,y:top,z:pos.z},.8+rng()*.6,rng()*6);if(rad>11)palm({x:pos.x+5,y:top,z:pos.z+4},.65+rng()*.5,rng()*6);}
      if(near) {
        for(let n=0;n<4;n++){
          const fx=pos.x+(rng()-.5)*rad, fz=pos.z+(rng()-.5)*rad*.8;
          inst.add('bushes',geos.lowball,mat(0x29994d),{x:fx,y:top+.5,z:fz},[1+rng(),.8,1.1]);
          inst.add('flowers',flowerGeo,mat(0xffd14d),{x:fx,y:top+1.3,z:fz},[1,1,1],[.4,0,.4]);
        }
      }
      if(!near&&rng()>.5){
        const wh=top+6,wx=pos.x+side*rad*.82;
        inst.add('waterfalls',geos.box,new T.MeshStandardMaterial({color:0xa2f1f2,emissive:0x2582a2,emissiveIntensity:.2,roughness:.3,transparent:true,opacity:.85}),{x:wx,y:top-wh/2,z:pos.z},[2.4,wh,1.1]);
        inst.add('waterfall-foam',geos.lowball,mat(0xc9ffff),{x:wx,y:-6,z:pos.z},[3,.6,2.5]);
      }
    }
    // Small trackside palms and flowers close enough to feel the speed.
    if(!isGap(s)&&trackSpan(s).halfWidth>5.5){
      const side=rng()>.5?1:-1,pos=worldAt(s,side*6.0,.15);palm(pos,.55+rng()*.15,rng()*6);
    }
  }
  for(let s=-100;s<LENGTH+900;s+=115){
    const p=point(s);for(const side of [-1,1]){
      const height=28+rng()*85;
      inst.add('far-cliffs',geos.cylinder,mat(0x86bbad),{x:p.x+side*(150+rng()*130),y:height/2-8,z:p.z},[35+rng()*50,height,30+rng()*45],[0,rng()*6,0]);
      for(let j=0;j<3;j++)inst.add('clouds',geos.ball,new T.MeshBasicMaterial({color:0xf0fbff,fog:true}),{x:p.x+side*(40+rng()*140)+j*10,y:105+rng()*24,z:p.z},[15+rng()*8,5+rng()*4,8+rng()*9]);
    }
  }
  inst.finish();
}
function makeObject(o){
  const root=new T.Group();atFrame(root,o.s,o.x,0);
  if(o.type==='robot'){
    ball(root,0xe24335,[0,1.12,0],[.89,.65,.76]);
    ball(root,0x123e57,[0,1.36,-.66],[.57,.21,.15]);
    for(const x of [-.27,.27])ball(root,0xffef62,[x,1.36,-.78],[.13,.1,.04]);
    mesh(geos.box,mat(0xe9edf2,.45,.2),root,[0,.9,-.72],[.69,.15,.1]);
    for(const side of [-1,1]){
      bar(root,[side*.65,.85,0],[side*1.2,.43,-.22],.12,0x25495f);
      ball(root,0x9abfcb,[side*1.2,.4,-.22],[.3,.19,.4]);
      bar(root,[side*.56,1.23,0],[side*1.2,1.46,-.1],.1,0x526c7f);
      ball(root,0xee4939,[side*1.35,1.51,-.15],[.4,.28,.3]);
      coneBetween(root,[side*1.39,1.55,-.27],[side*1.42,1.7,-.67],.18,0xdcedec);
    }
    bar(root,[0,1.67,0],[0,2.1,0],.04,0x304752);ball(root,0xffe157,[0,2.15,0],[.13,.13,.13]);
  }else if(o.type==='spikes'){
    mesh(geos.box,mat(0x415970,.6,.3),root,[0,.15,0],[2.65,.3,2.05]);
    mesh(geos.box,mat(0xfaca41),root,[0,.27,-1.02],[2.65,.14,.15]);
    for(const x of [-.88,0,.88])for(const z of [-.5,.5])mesh(geos.cone,mat(0xc8e2ed,.3,.55),root,[x,.72,z],[.33,1.15,.33]);
  }else if(o.type==='crate'){
    mesh(geos.box,mat(0xc88542),root,[0,1,0],[2.25,2.05,2.05]);
    for(const y of [.15,1.85])mesh(geos.box,mat(0xf0c780),root,[0,y,-1.06],[2.3,.19,.12]);
    for(const x of [-1.04,1.04])mesh(geos.box,mat(0xf0c780),root,[x,1,-1.06],[.19,2,.12]);
    const beam=mesh(geos.box,mat(0xe6b373),root,[0,1,-1.09],[.23,2.5,.14]);beam.rotation.z=-.8;
  }else if(o.type==='dash'){
    mesh(geos.box,mat(0xc02b3c),root,[0,.06,0],[4.4,.15,3.8]);
    mesh(geos.box,mat(0xffc638),root,[0,.14,0],[3.9,.08,3.4]);
    for(let z=-1;z<=1;z+=1)for(const side of [-1,1]){const b=mesh(geos.box,mat(0xffffff),root,[side*.46,.2,z],[1.5,.07,.22]);b.rotation.y=-side*.64;}
  }else if(o.type==='jumpmark'){
    mesh(geos.box,mat(0x167bba),root,[0,.035,0],[4.3,.06,2.4]);
    for(const side of [-1,1]){const arrow=mesh(geos.box,mat(0xb4ffff),root,[side*.5,.08,-.2],[1.5,.04,.3]);arrow.rotation.y=-side*.65;}
    mesh(geos.box,mat(0xb4ffff),root,[0,.08,.55],[.3,.04,1.1]);
  }else if(o.type==='spring'){
    for(const x of [-4.1,0,4.1]){
      mesh(geos.cylinder,mat(0x2c536c,.5,.4),root,[x,.21,0],[1.55,.3,1.05]);
      for(let j=0;j<3;j++){const coil=mesh(new T.TorusGeometry(1.0,.11,5,14),mat(0xc4e7ef,.32,.55),root,[x,.35+j*.24,0],[1,1,.72]);coil.rotation.x=Math.PI/2;}
      mesh(geos.cylinder,mat(0xf13c45),root,[x,1,0],[1.6,.3,1.12]);
      mesh(geos.cylinder,mat(0xffe361),root,[x,1.17,0],[.65,.04,.47]);
    }
  }
  root.traverse(n=>{if(n.isMesh){n.castShadow=true;n.receiveShadow=true;}});return root;
}
export class World {
  constructor(canvas,game){
    this.game=game;this.scene=new T.Scene();this.scene.fog=new T.Fog(0xade9ed,125,410);
    this.renderer=new T.WebGLRenderer({canvas,antialias:false,alpha:false,powerPreference:'high-performance'});
    this.renderer.setClearColor(0x87dbe9);this.renderer.outputColorSpace=T.SRGBColorSpace;
    this.renderer.toneMapping=T.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.14;
    this.camera=new T.PerspectiveCamera(64,1,.12,1600);this.camera.position.set(0,15,20);
    this.scene.add(new T.HemisphereLight(0xd8f9ff,0x6c8d75,2.15));
    this.sun=new T.DirectionalLight(0xfff3ce,3.15);this.sun.position.set(-75,125,60);this.scene.add(this.sun,this.sun.target);
    this.sun.castShadow=true;this.sun.shadow.mapSize.set(1024,1024);this.sun.shadow.camera.left=-22;this.sun.shadow.camera.right=22;this.sun.shadow.camera.top=25;this.sun.shadow.camera.bottom=-20;this.sun.shadow.camera.near=1;this.sun.shadow.camera.far=240;this.sun.shadow.normalBias=.06;this.sun.shadow.bias=-.0004;
    this.renderer.shadowMap.type=T.PCFSoftShadowMap;
    const skyMat=new T.ShaderMaterial({side:T.BackSide,depthWrite:false,uniforms:{},vertexShader:'varying vec3 v;void main(){v=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:'varying vec3 v;void main(){float h=normalize(v).y;vec3 col=mix(vec3(.64,.91,.95),vec3(.075,.43,.85),smoothstep(-.05,.72,h));gl_FragColor=vec4(col,1.);}' });
    this.sky=mesh(new T.SphereGeometry(1200,24,16),skyMat,this.scene);this.sky.renderOrder=-100;
    this.waterMaterial=new T.ShaderMaterial({uniforms:{time:{value:0},fogColor:{value:new T.Color(0xade9ed)}},vertexShader:'varying vec3 vWorld;void main(){vec4 w=modelMatrix*vec4(position,1.);vWorld=w.xyz;gl_Position=projectionMatrix*viewMatrix*w;}',fragmentShader:'uniform float time;uniform vec3 fogColor;varying vec3 vWorld;void main(){float a=sin(vWorld.x*.17+vWorld.z*.12+time*.6);float b=sin(vWorld.x*.27-vWorld.z*.25+time*.9);float wave=a*b;vec3 col=mix(vec3(.025,.45,.62),vec3(.06,.72,.73),.5+wave*.22);float sparkle=pow(max(0.,sin(vWorld.x*.43+vWorld.z*.61+time)*sin(vWorld.z*.8-time*.7)),16.);col+=vec3(.28,.4,.35)*sparkle;float d=length(vWorld.xz-cameraPosition.xz);col=mix(col,fogColor,smoothstep(160.,650.,d));gl_FragColor=vec4(col,1.);}' });
    this.water=mesh(new T.PlaneGeometry(3000,6000),this.waterMaterial,this.scene,[0,-7,-1000]);this.water.rotation.x=-Math.PI/2;
    this.trackMeshes=terrain(this.scene);scenery(this.scene);
    this.cameraRay=new T.Raycaster();this.cameraCollisions=0;
    this.goal=new T.Group();atFrame(this.goal,LENGTH,0,3.65);this.scene.add(this.goal);
    mesh(new T.TorusGeometry(3.1,.25,10,56),mat(0xffda42,.25,.62),this.goal);
    mesh(new T.TorusGeometry(3.45,.07,5,48),mat(0xffffab,.4,.2),this.goal);
    for(let row=0;row<3;row++)for(let col=0;col<10;col++){
      const tile=mesh(geos.box,mat((row+col)%2?0xf8faf0:0x164c71),this.scene);
      atFrame(tile,LENGTH-2.5+row*.65,(col-4.5),.025);tile.scale.set(1,.04,.65);
    }
    this.sonic=makeSonic();this.scene.add(this.sonic.root);
    this.shadow=mesh(new T.CircleGeometry(.8,24),new T.MeshBasicMaterial({color:0x183f5b,transparent:true,opacity:.24,depthWrite:false}),this.scene);this.shadow.rotation.x=-Math.PI/2;
    this.aura=mesh(new T.SphereGeometry(1,16,10),new T.MeshBasicMaterial({color:0x57d9ff,transparent:true,opacity:.12,depthWrite:false,blending:T.AdditiveBlending}),this.sonic.root,[0,1.3,.4],[1.1,1.4,1.8]);this.aura.visible=false;
    this.targetScreen=null;
    this.objectGroup=new T.Group();this.scene.add(this.objectGroup);
    this.particles=[];this.particleGeometry=new T.BufferGeometry();this.particlePositions=new Float32Array(300*3);this.particleColors=new Float32Array(300*3);this.particleGeometry.setAttribute('position',new T.BufferAttribute(this.particlePositions,3));this.particleGeometry.setAttribute('color',new T.BufferAttribute(this.particleColors,3));
    this.particleMesh=new T.Points(this.particleGeometry,new T.PointsMaterial({size:.22,vertexColors:true,transparent:true,opacity:.9,depthWrite:false}));this.particleMesh.frustumCulled=false;this.scene.add(this.particleMesh);
    const speedPositions=new Float32Array(32*6);for(let i=0;i<32;i++){const a=i/32*Math.PI*2,r=4+Math.random()*3;speedPositions.set([cos(a)*r,sin(a)*r,-8-Math.random()*8,cos(a)*r*1.12,sin(a)*r*1.12,-3-Math.random()*4],i*6);}
    const speedG=new T.BufferGeometry();speedG.setAttribute('position',new T.BufferAttribute(speedPositions,3));this.speedLines=new T.LineSegments(speedG,new T.LineBasicMaterial({color:0xc7f7ff,transparent:true,opacity:.2,depthWrite:false}));this.camera.add(this.speedLines);this.scene.add(this.camera);this.speedLines.visible=false;
    this.time=0;this.runPhase=0;this.cameraReady=false;this.quality='Balanced';this.setQuality(this.quality);this.resize();this.resetObjects();
  }
  resetObjects(){
    if(!this.objectMeshes)this.objectMeshes=this.game.objects.map(o=>{const m=makeObject(o);this.objectGroup.add(m);return m;});
    if(!this.ringMesh){this.ringMesh=new T.InstancedMesh(geos.ring,mat(palette.gold,.25,.67),this.game.rings.length);this.ringMesh.instanceMatrix.setUsage(T.DynamicDrawUsage);this.ringMesh.frustumCulled=false;this.scene.add(this.ringMesh);}
    this.ringFrames=this.game.rings.map(r=>{const f=frame(r.s);return {position:V(worldAt(r.s,r.x,r.y)),q:new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(V(f.r),V(f.n),V(f.f).negate()))};});
    this.particles=[];this.cameraReady=false;
  }
  setQuality(q){this.quality=q;this.renderer.shadowMap.enabled=q==='High';this.resize();}
  resize(){const w=innerWidth,h=innerHeight;this.w=w;this.h=h;this.portrait=h>w;const cap=this.quality==='Low'?1:this.quality==='High'?2:1.35;this.renderer.setPixelRatio(Math.min(devicePixelRatio||1,cap,Math.sqrt(2200000/(w*h))));this.renderer.setSize(w,h,false);this.camera.aspect=w/h;this.camera.updateProjectionMatrix();}
  burst(s,x,h,color,count=14){const pos=V(worldAt(s,x,h));for(let i=0;i<count;i++){if(this.particles.length>=300)this.particles.shift();this.particles.push({p:pos.clone(),v:new T.Vector3((Math.random()-.5)*10,3+Math.random()*9,(Math.random()-.5)*10),life:.6+Math.random()*.5,c:new T.Color(color)});}}
  event(e){const g=this.game;if(e.type==='ring')this.burst(e.ring.s,e.ring.x,e.ring.y,0xffdf58,3);if(e.type==='destroy')this.burst(e.object.s,e.object.x,1.2,e.object.type==='robot'?0xff9a38:0xecc384,22);if(e.type==='hurt')this.burst(g.s,g.x,1.3,0xffd531,30);if(e.type==='spring')this.burst(g.s,g.x,.5,0xaaf8ff,16);if(e.type==='finish')this.burst(g.s,g.x,3,0xffe868,60);if(e.type==='retry')this.cameraReady=false;}
  keepCameraClear(position,focus,s){
    const loop=loopAt(s,45);if(!loop)return;
    const candidates=this.trackMeshes.filter(m=>m.userData.trackTo>=loop.start-65&&m.userData.trackFrom<=loop.end+65);
    const direction=position.clone().sub(focus),distance=direction.length();if(distance<.01)return;direction.normalize();
    let allowed=distance;
    // Test a small camera volume rather than only its center ray.
    const fr=frame(s);
    for(const offset of [new T.Vector3(),V(fr.r).multiplyScalar(.55),V(fr.r).multiplyScalar(-.55),V(fr.n).multiplyScalar(.45)]){
      this.cameraRay.set(focus.clone().add(offset),direction);this.cameraRay.near=.12;this.cameraRay.far=distance+.35;
      const hit=this.cameraRay.intersectObjects(candidates,false)[0];
      if(hit)allowed=Math.min(allowed,Math.max(.5,hit.distance-.85));
    }
    if(allowed<distance){position.copy(focus).addScaledVector(direction,allowed);this.cameraCollisions++;}
  }
  render(dt){
    const g=this.game;this.time+=dt;const t=this.time,ready=g.status==='ready';
    this.waterMaterial.uniforms.time.value=t;
    this.goal.children[1].rotation.z=t*.45;
    const fr=frame(g.s),p=V(fr.p),f=V(fr.f),r=V(fr.r),n=V(fr.n);
    const player=p.clone().addScaledVector(r,g.x).addScaledVector(n,g.h);
    this.sonic.root.position.copy(player);this.sonic.root.quaternion.setFromRotationMatrix(tempMatrix.makeBasis(r,n,f.clone().negate()));
    if(ready)this.sonic.root.rotateY(Math.PI*.95);
    this.sonic.root.scale.setScalar(ready?1.75:1.05);
    const running=g.status==='running';if(running)this.runPhase+=g.speed*dt*.95;
    const airborne=!g.grounded&&g.status!=='falling',spin=airborne&&!isLoop(g.s);
    this.sonic.body.visible=!spin;this.sonic.spin.visible=spin;this.sonic.spin.rotation.x-=running?dt*16:0;
    this.sonic.body.rotation.x=ready?0:g.boosting?-.42:-.21;this.sonic.body.rotation.z=ready?sin(t)*.015:-g.vx*.016;
    this.sonic.body.position.y=ready?sin(t*2.2)*.045:g.grounded?Math.abs(sin(this.runPhase))*.08:0;
    for(let i=0;i<2;i++){const phase=this.runPhase+i*Math.PI;this.sonic.legs[i].rotation.x=ready?0:sin(phase)*(g.boosting?1.05:.86);this.sonic.arms[i].rotation.x=ready?.08:g.boosting?-.95:sin(phase+Math.PI)*.65;this.sonic.arms[i].rotation.z=ready?(i===0?-.12:.12):i===0?-.2:.2;}
    this.sonic.root.visible=g.invulnerable<=0||Math.floor(t*18)%3!==0;
    this.aura.visible=g.boosting||g.dash>0;this.aura.material.opacity=.12+sin(t*30)*.04;
    this.shadow.position.copy(p).addScaledVector(r,g.x).addScaledVector(n,.055);this.shadow.quaternion.setFromRotationMatrix(tempMatrix.makeBasis(r,f.clone().negate(),n));this.shadow.scale.setScalar(Math.max(.5,1.35-g.h*.045));this.shadow.material.opacity=clamp(.26-g.h*.015,.03,.26);this.shadow.visible=!isGap(g.s)&&g.status!=='falling';
    let want,look,camUp;
    if(ready){
      if(this.portrait){want=p.clone().addScaledVector(f,-15).addScaledVector(r,11).addScaledVector(n,7);look=p.clone().addScaledVector(n,-2.5).addScaledVector(r,0);}
      else {want=p.clone().addScaledVector(f,-14).addScaledVector(r,11).addScaledVector(n,7.7);look=p.clone().addScaledVector(r,-5.2).addScaledVector(n,2.5);}
      want.addScaledVector(r,sin(t*.16)*.8);camUp=new T.Vector3(0,1,0);
    }else{
      const back=this.portrait?18:13.5,high=this.portrait?8.4:6.5;
      const eyeFrame=frame(g.s-back),leadFrame=frame(g.s+15),lift=Math.max(0,g.h-3.7)*.43;
      // The camera follows the road arc. Ordinary jumps stay visible against a
      // steady horizon, while large spring launches receive limited follow-up.
      want=V(eyeFrame.p).addScaledVector(V(eyeFrame.n),high+lift).addScaledVector(V(eyeFrame.r),g.x*.84);
      look=V(leadFrame.p).addScaledVector(V(leadFrame.n),1.9+lift*.7).addScaledVector(V(leadFrame.r),g.x*.62);camUp=n;
      if(g.status==='falling'){want.addScaledVector(n,g.h*.25);look.addScaledVector(n,g.h*.15);}
      this.keepCameraClear(want,player.clone().addScaledVector(n,1.35),g.s);
      if(g.status==='finished'){want=player.clone().addScaledVector(f,10).addScaledVector(r,9).addScaledVector(n,6);look=player.clone().addScaledVector(n,1.5);camUp=new T.Vector3(0,1,0);}
    }
    const follow=1-Math.exp(-dt*(isLoop(g.s)?13:8));
    if(!this.cameraReady){this.camera.position.copy(want);this.look=look.clone();this.camera.up.copy(camUp);this.cameraReady=true;}
    else {this.camera.position.lerp(want,follow);this.look.lerp(look,follow);this.camera.up.lerp(camUp,follow).normalize();}
    if(!ready)this.keepCameraClear(this.camera.position,player.clone().addScaledVector(n,1.35),g.s);
    const fov=ready?(this.portrait?64:54):(this.portrait?70:64)+(g.boosting?10:g.dash>0?5:0);
    this.camera.fov+=(fov-this.camera.fov)*(1-Math.exp(-dt*5));this.camera.updateProjectionMatrix();this.camera.lookAt(this.look);
    this.sky.position.copy(this.camera.position);this.speedLines.visible=g.boosting&&running;
    this.sun.position.copy(player).add(new T.Vector3(-65,110,55));this.sun.target.position.copy(player);
    for(let i=0;i<g.objects.length;i++){
      const o=g.objects[i],m=this.objectMeshes[i];m.visible=!o.dead&&Math.abs(o.s-g.s)<340;
      if(o.type==='robot'&&m.visible){const pf=frame(o.s);m.position.copy(V(worldAt(o.s,o.x,sin(t*3+o.s)*.075)));}
    }
    for(let i=0;i<g.rings.length;i++){
      const ring=g.rings[i],rf=this.ringFrames[i];dummy.position.copy(rf.position);dummy.quaternion.copy(rf.q);dummy.rotateY(t*2.5+ring.s*.09);
      const visible=!ring.collected&&Math.abs(ring.s-g.s)<310;dummy.scale.setScalar(visible?1:0);dummy.updateMatrix();this.ringMesh.setMatrixAt(i,dummy.matrix);
    }
    this.ringMesh.instanceMatrix.needsUpdate=true;
    this.camera.updateMatrixWorld();
    const target=g.target();this.targetScreen=null;
    if(target&&running){
      const aim=V(worldAt(target.s,targetX(target,g.x),target.type==='spring'?1:1.3)).project(this.camera);
      if(aim.z>-1&&aim.z<1&&Math.abs(aim.x)<1.05&&Math.abs(aim.y)<1.05)this.targetScreen={x:(aim.x*.5+.5)*this.w,y:(-.5*aim.y+.5)*this.h,type:target.type,object:target};
    }
    for(let i=this.particles.length-1;i>=0;i--){const a=this.particles[i];a.life-=dt;if(a.life<=0){this.particles.splice(i,1);continue;}a.v.y-=12*dt;a.p.addScaledVector(a.v,dt);}
    if(g.boosting&&running&&Math.random()>.35)this.burst(g.s-1,g.x,.4,0x5bcfff,1);
    this.particles.forEach((a,i)=>{this.particlePositions.set(a.p.toArray(),i*3);this.particleColors.set([a.c.r,a.c.g,a.c.b],i*3);});
    this.particleGeometry.setDrawRange(0,this.particles.length);this.particleGeometry.attributes.position.needsUpdate=true;this.particleGeometry.attributes.color.needsUpdate=true;
    this.renderer.render(this.scene,this.camera);
  }
}
