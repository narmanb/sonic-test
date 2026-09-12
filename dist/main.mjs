import {Game,LENGTH,START,LOOPS,loopAt,SPRING_GAPS,JUMP_GAPS,formatTime,clamp} from './core.mjs?v=2';
import {World} from './world.mjs?v=2';
import {Sound} from './audio.mjs';
const $=id=>document.getElementById(id), game=new Game(),sound=new Sound();
let world, touchSteer=0,boostHeld=false,stickPointer=null,boostPointer=null,keys=new Set(),previousPad={},last=0,accumulator=0,noticeTimer=0,loopTimer=0,toast='',toastTimer=0,uiTimer=0;
const elements={rings:$('rings'),time:$('time'),speed:$('speed'),progress:$('progress'),distance:$('distance'),sector:$('sector'),boostFill:$('boost-fill'),boostValue:$('boost-value'),callout:$('callout'),jumpLabel:$('jump-label'),targetLock:$('target-lock'),targetLabel:$('target-label')};
let lastLock=null;
function showError(error){console.error(error);$('loading').classList.add('hidden');$('error-screen').classList.remove('hidden');}
function message(text,seconds=2.5){toast=text;toastTimer=seconds;}
function releaseControls(){keys.clear();touchSteer=0;boostHeld=false;stickPointer=null;boostPointer=null;$('stick').style.transform='translate(0,0)';$('boost').classList.remove('pressed');}
function displayScreens(){
  const active=['running','paused','falling'].includes(game.status);
  $('start-screen').classList.toggle('hidden',game.status!=='ready');$('hud').classList.toggle('hidden',!active);
  $('pause').classList.toggle('hidden',!active);$('pause-screen').classList.toggle('hidden',game.status!=='paused');
  $('finish-screen').classList.toggle('hidden',game.status!=='finished');
  document.body.classList.toggle('playing',active);document.body.classList.toggle('boosting',game.boosting&&game.status==='running');
}
function start(){
  releaseControls();game.reset();world.resetObjects();sound.unlock();noticeTimer=0;toastTimer=0;loopTimer=0;displayScreens();
  $('start').blur();accumulator=0;
}
function pause(){if(game.status==='paused'){game.resume();sound.unlock();}else game.pause();releaseControls();displayScreens();}
function retry(){releaseControls();game.retry();world.cameraReady=false;toastTimer=0;displayScreens();}
function finish(){
  releaseControls();$('result-time').textContent=formatTime(game.elapsed);$('result-rings').textContent=game.ringCount;
  $('result-robots').textContent=game.robots;$('result-retries').textContent=game.retries;
  $('rank').textContent=game.retries===0&&game.elapsed<73&&game.ringCount>=90?'S':game.retries<=1&&game.elapsed<95?'A':game.retries<=4?'B':'C';displayScreens();
}
function wire(){
  $('start').addEventListener('click',start);$('replay').addEventListener('click',start);$('restart').addEventListener('click',start);
  $('pause').addEventListener('click',pause);$('resume').addEventListener('click',pause);$('retry').addEventListener('click',retry);
  $('sound').addEventListener('click',()=>{sound.setEnabled(!sound.enabled);if(sound.enabled)sound.unlock();$('sound').classList.toggle('muted',!sound.enabled);$('sound').setAttribute('aria-label',sound.enabled?'Mute sound':'Enable sound');$('sound').setAttribute('aria-pressed',String(sound.enabled));});
  $('quality').addEventListener('click',()=>{const options=['Balanced','High','Low'];const q=options[(options.indexOf(world.quality)+1)%options.length];world.setQuality(q);$('quality').textContent=q;});
  $('fullscreen').addEventListener('click',async()=>{
    try{
      if(document.fullscreenElement)await document.exitFullscreen();
      else if(document.documentElement.requestFullscreen){await document.documentElement.requestFullscreen();try{await screen.orientation?.lock?.('landscape');}catch{}}
      else message('Use your browser’s fullscreen option.',4);
    }catch{message('Fullscreen is unavailable in this view. Try opening in Chrome.',4);}
  });
  document.addEventListener('fullscreenchange',()=>{$('fullscreen').setAttribute('aria-label',document.fullscreenElement?'Exit fullscreen':'Enter fullscreen');world.resize();});
  const stick=$('joystick');
  function moveStick(e){if(e.pointerId!==stickPointer)return;const rect=stick.getBoundingClientRect(),r=rect.width*.38,dx=clamp((e.clientX-rect.left-rect.width/2)/r,-1,1);touchSteer=Math.abs(dx)<.1?0:Math.sign(dx)*(Math.abs(dx)-.1)/.9;$('stick').style.transform=`translate(${dx*r*.77}px,0)`;}
  stick.addEventListener('pointerdown',e=>{if(stickPointer!==null)return;e.preventDefault();stickPointer=e.pointerId;stick.setPointerCapture(e.pointerId);moveStick(e);});
  stick.addEventListener('pointermove',moveStick);
  const stopStick=e=>{if(e.pointerId!==stickPointer)return;stickPointer=null;touchSteer=0;$('stick').style.transform='translate(0,0)';};
  for(const type of ['pointerup','pointercancel','lostpointercapture'])stick.addEventListener(type,stopStick);
  $('jump').addEventListener('pointerdown',e=>{e.preventDefault();game.jump();$('jump').setPointerCapture(e.pointerId);});
  $('boost').addEventListener('pointerdown',e=>{if(boostPointer!==null)return;e.preventDefault();boostPointer=e.pointerId;boostHeld=true;$('boost').setPointerCapture(e.pointerId);$('boost').classList.add('pressed');});
  for(const type of ['pointerup','pointercancel','lostpointercapture'])$('boost').addEventListener(type,e=>{if(e.pointerId!==boostPointer)return;boostPointer=null;boostHeld=false;$('boost').classList.remove('pressed');});
  document.addEventListener('keydown',e=>{
    const codes=['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Space','ShiftLeft','ShiftRight','KeyA','KeyD','KeyW','KeyS','KeyP','Escape','Enter'];
    if(!codes.includes(e.code))return;
    // Let buttons retain their normal Enter/Space activation in menus.
    if(game.status!=='running'&&game.status!=='falling'&&e.target?.tagName==='BUTTON'&&['Enter','Space'].includes(e.code))return;
    e.preventDefault();keys.add(e.code);if(e.repeat)return;
    if(e.code==='Space'&&game.status==='running')game.jump();
    if(e.code==='KeyP'||e.code==='Escape')pause();
    if(e.code==='Enter'&&(game.status==='ready'||game.status==='finished'))start();
  });
  document.addEventListener('keyup',e=>keys.delete(e.code));
  window.addEventListener('blur',()=>{if(game.status==='running'||game.status==='falling')game.pause();releaseControls();displayScreens();});
  document.addEventListener('visibilitychange',()=>{if(document.hidden){if(game.status==='running'||game.status==='falling')game.pause();releaseControls();displayScreens();}});
  window.addEventListener('resize',()=>world.resize());
  $('view').addEventListener('webglcontextlost',e=>{e.preventDefault();game.pause();releaseControls();$('error-text').textContent='The 3D view was interrupted. Reload the level to continue.';showError(new Error('WebGL context lost'));});
  document.addEventListener('contextmenu',e=>e.preventDefault());
}
function input(){
  let steer=touchSteer,boost=boostHeld||keys.has('ShiftLeft')||keys.has('ShiftRight'),brake=keys.has('ArrowDown')||keys.has('KeyS');
  if(keys.has('ArrowLeft')||keys.has('KeyA'))steer=-1;if(keys.has('ArrowRight')||keys.has('KeyD'))steer=1;
  let pad;try{pad=Array.from(navigator.getGamepads?.()||[]).find(p=>p?.connected);}catch{}
  if(pad){
    const axis=pad.axes[0]||0;if(Math.abs(axis)>.17)steer=Math.sign(axis)*(Math.abs(axis)-.17)/.83;
    if(pad.buttons[14]?.pressed)steer=-1;if(pad.buttons[15]?.pressed)steer=1;
    boost ||=!!(pad.buttons[2]?.pressed||pad.buttons[7]?.pressed);
    const jump=!!pad.buttons[0]?.pressed,startButton=!!pad.buttons[9]?.pressed;
    if(jump&&!previousPad.jump){if(game.status==='ready'||game.status==='finished')start();else if(game.status==='running')game.jump();}
    if(startButton&&!previousPad.startButton)pause();previousPad={jump,startButton};
  }else previousPad={};
  return {steer,boost,brake};
}
function updateHUD(dt){
  noticeTimer=Math.max(0,noticeTimer-dt);toastTimer=Math.max(0,toastTimer-dt);loopTimer=Math.max(0,loopTimer-dt);
  const e=elements,percent=clamp((game.s-START)/(LENGTH-START)*100,0,100);
  e.rings.textContent=String(game.ringCount).padStart(3,'0');e.time.textContent=formatTime(game.elapsed);e.speed.textContent=Math.round(game.speed*3.6);
  e.progress.style.width=percent+'%';e.distance.textContent=Math.floor(percent)+'%';e.sector.textContent=game.s<620?'PALM SHORES':game.s<1235?'SKYLINE LOOP':game.s<1730?'ISLAND HOP':game.s<2505?'HORIZON LOOP':'SKIPSTONE RUN';
  e.boostFill.style.width=game.energy+'%';e.boostValue.textContent=Math.round(game.energy);
  let hint='';
  if(toastTimer>0)hint=toast;
  else if(game.s<120)hint='STEER TO COLLECT RINGS · HOLD BOOST FOR SPEED';
  else if(game.s>145&&game.s<212)hint='JUMP OR STEER AROUND SPIKES';
  else if(game.s>285&&game.s<338)hint='BOOST THROUGH CRATES';
  else if(game.s>650&&game.s<715)hint='JUMP, THEN TAP JUMP AGAIN TO ATTACK';
  else if(loopAt(game.s))hint='ROUND THE LOOP!';
  else if(LOOPS.some(loop=>game.s>loop.start-45&&game.s<loop.start))hint='LOOP AHEAD · KEEP RUNNING';
  else if(JUMP_GAPS.some(([a])=>game.s>a-52&&game.s<a+2))hint='BLUE ARROWS · JUMP THE GAP';
  else if(SPRING_GAPS.some(([a])=>game.s>a-60&&game.s<a-12))hint='SPRINGS CAN BE HOMING TARGETS · TAP JUMP IN THE AIR';
  else if(game.boostExhausted)hint='RELEASE BOOST TO RECHARGE';
  else if(game.s>2510&&game.s<2560)hint='SKIPSTONE RUN · STAY ON THE NARROW PATH';
  else if(game.s>LENGTH-100&&game.s<LENGTH)hint='THE FINISH IS AHEAD · GO FOR IT!';
  if(game.status==='falling')hint='BACK TO YOUR CHECKPOINT…';
  const target=game.target();e.jumpLabel.textContent=target?(target.type==='spring'?'SPRING':'ATTACK'):'JUMP';$('jump').classList.toggle('target-ready',!!target);
  e.callout.textContent=hint;e.callout.classList.toggle('visible',!!hint&&game.status!=='paused');
  $('checkpoint-notice').classList.toggle('visible',noticeTimer>0);
  document.body.classList.toggle('boosting',game.boosting&&game.status==='running');
}
function tick(now){
  const dt=Math.min(.08,last?(now-last)/1000:1/60);last=now;
  try{
    const controls=input();
    if(game.status==='running'||game.status==='falling'){
      accumulator=Math.min(accumulator+dt,.15);
      while(accumulator>=1/120){game.step(1/120,controls);accumulator-=1/120;}
    }else accumulator=0;
    for(const e of game.drainEvents()){
      world.event(e);sound.event(e);
      if(e.type==='checkpoint')noticeTimer=2;
      if(e.type==='hurt')message('RINGS LOST · KEEP MOVING',1.8);
      if(e.type==='retry'){message('LET’S TRY THAT AGAIN',2);displayScreens();}
      if(e.type==='finish')finish();
    }
    uiTimer+=dt;if(uiTimer>=1/25){updateHUD(uiTimer);uiTimer=0;}
    sound.update(game.status==='running');world.render(Math.min(dt,.05));
    const lock=world.targetScreen;
    elements.targetLock.classList.toggle('hidden',!lock||game.status!=='running');
    if(lock){
      elements.targetLock.style.left=lock.x+'px';elements.targetLock.style.top=lock.y+'px';
      elements.targetLock.classList.toggle('spring-lock',lock.type==='spring');elements.targetLabel.textContent=lock.type==='spring'?'SPRING LOCK':'ROBOT LOCK';
      if(lastLock!==lock.object)sound.tone(lock.type==='spring'?1047:784,.08,'sine',.1);
    }
    lastLock=lock?.object||null;
    requestAnimationFrame(tick);
  }catch(err){showError(err);}
}
function registerTools(){
  const context=document.modelContext;if(!context?.registerTool)return;
  const lifecycle=new AbortController();
  const defs=[{
    name:'read_run_status',description:'Read the current Cobalt Coast run, checkpoint and boost. Does not change the game.',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true,untrustedContentHint:false},
    execute(arg){if(!arg||Object.keys(arg).length)throw new Error('Expected an empty object.');return game.snapshot();}
  },{
    name:'pause_run',description:'Pause the active Cobalt Coast run or resume a paused run.',inputSchema:{type:'object',properties:{paused:{type:'boolean'}},required:['paused'],additionalProperties:false},annotations:{readOnlyHint:false,untrustedContentHint:false},
    execute(arg){if(!arg||typeof arg.paused!=='boolean'||Object.keys(arg).some(k=>k!=='paused'))throw new Error('paused must be a boolean.');if(arg.paused){game.pause();releaseControls();}else game.resume();displayScreens();return game.snapshot();}
  }];
  for(const tool of defs)try{Promise.resolve(context.registerTool(tool,{signal:lifecycle.signal})).catch(()=>{});}catch{}
  window.addEventListener('pagehide',()=>lifecycle.abort(),{once:true});
}
try{world=new World($('view'),game);wire();registerTools();displayScreens();world.render(1/60);$('loading').classList.add('hidden');requestAnimationFrame(tick);}catch(err){showError(err);}
