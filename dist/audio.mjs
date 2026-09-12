export class Sound {
  constructor(){this.enabled=true;this.context=null;this.nextBeat=0;this.beat=0;this.ringAt=0;}
  async unlock(){
    if(!this.context){
      const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return;
      this.context=new AC();this.master=this.context.createGain();this.master.gain.value=this.enabled?.3:0;this.master.connect(this.context.destination);this.nextBeat=this.context.currentTime;
    }
    if(this.context.state==='suspended')try{await this.context.resume();}catch{}
  }
  setEnabled(v){this.enabled=v;if(this.master)this.master.gain.setTargetAtTime(v?.3:0,this.context.currentTime,.03);}
  tone(freq,duration=.1,type='sine',volume=.2,endFreq=null,delay=0){
    if(!this.enabled||!this.context||this.context.state!=='running')return;
    const a=this.context,t=a.currentTime+delay,o=a.createOscillator(),v=a.createGain();
    o.type=type;o.frequency.setValueAtTime(freq,t);if(endFreq)o.frequency.exponentialRampToValueAtTime(Math.max(20,endFreq),t+duration);
    v.gain.setValueAtTime(.0001,t);v.gain.exponentialRampToValueAtTime(Math.max(.001,volume),t+.006);v.gain.exponentialRampToValueAtTime(.0001,t+duration);
    o.connect(v);v.connect(this.master);o.start(t);o.stop(t+duration+.015);
  }
  noise(duration=.2,volume=.12){
    if(!this.enabled||!this.context||this.context.state!=='running')return;
    const a=this.context,n=a.createBuffer(1,a.sampleRate*duration,a.sampleRate),d=n.getChannelData(0);
    for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1)*(1-i/d.length);
    const s=a.createBufferSource(),f=a.createBiquadFilter(),v=a.createGain();s.buffer=n;f.type='highpass';f.frequency.value=1200;v.gain.value=volume;s.connect(f);f.connect(v);v.connect(this.master);s.start();
  }
  event(e){
    switch(e.type){
      case 'ring':if(this.context&&this.context.currentTime-this.ringAt>.035){this.ringAt=this.context.currentTime;this.tone(1480,.1,'sine',.32);this.tone(2217,.2,'sine',.22,null,.045);}break;
      case 'jump':this.tone(310,.2,'triangle',.25,830);break;
      case 'airdash':case 'homing':this.tone(550,.15,'sawtooth',.1,1100);this.noise(.12,.1);break;
      case 'spring':this.tone(150,.5,'triangle',.32,1600);this.tone(300,.35,'sine',.2,1900);break;
      case 'dash':this.noise(.25,.18);this.tone(150,.28,'triangle',.23,740);break;
      case 'destroy':this.noise(.22,.35);this.tone(150,.16,'square',.1,45);break;
      case 'hurt':this.tone(880,.22,'square',.12,220);this.noise(.2,.13);break;
      case 'fall':this.tone(440,.55,'triangle',.23,80);break;
      case 'checkpoint':[523,659,784,1047].forEach((f,i)=>this.tone(f,.2,'triangle',.19,null,i*.08));break;
      case 'finish':[523,659,784,1047,988,1047,1319].forEach((f,i)=>this.tone(f,.32,'triangle',.24,null,i*.14));break;
    }
  }
  update(playing){
    if(!this.context||!this.enabled||this.context.state!=='running')return;
    const now=this.context.currentTime;
    if(!playing){this.nextBeat=now+.12;return;}
    if(this.nextBeat<now-.4)this.nextBeat=now;
    const tune=[76,0,79,83,81,79,76,74,72,0,76,79,78,76,74,71,72,0,76,79,83,81,79,76,74,0,78,81,79,78,74,0];
    const bass=[48,48,53,55];
    while(this.nextBeat<now+.12){
      const i=this.beat%32,delay=Math.max(0,this.nextBeat-now),m=tune[i];
      if(m)this.tone(440*2**((m-69)/12),.13,'triangle',.052,null,delay);
      if(i%2===0)this.tone(440*2**((bass[Math.floor(i/8)]-69)/12),.19,'sine',.12,null,delay);
      if(i%4===0)this.tone(110,.1,'sine',.18,40,delay);
      if(i%4===2)this.tone(180,.04,'triangle',.03,null,delay);
      this.beat++;this.nextBeat+=60/136/2;
    }
  }
}
