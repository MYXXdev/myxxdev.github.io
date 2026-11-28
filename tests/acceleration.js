const fs=require('fs'), vm=require('vm'), assert=require('assert');
const source=fs.readFileSync(__dirname+'/../Companions/SpeedyAds/Acceleration.js','utf8').replace(/__MYB_INITIAL_ENABLED__/g,'true');
function scenario(limit,clamp=false,dynamic=false){
 let cap=limit;
 let now=1000,perf=100,writes=0,rate=1,listener,timers=[],intervals=[];
 const video={addEventListener:(name,fn)=>{if(name==='ratechange')listener=fn;}};
 Object.defineProperty(video,'playbackRate',{get:()=>rate,set:value=>{writes++;if(value>cap&&!clamp)throw new Error('unsupported');rate=Math.min(value,cap);if(listener)listener.call(video);}});
 const date={now:()=>now},performance={now:()=>perf};
 const window={frames:[],performance,setTimeout:function(...args){timers.push(args);return 1;},setInterval:function(...args){intervals.push(args);return 1;},addEventListener:()=>{}};window.parent=window;
 const document={getElementsByTagName:()=>[video],addEventListener:()=>{}};
 vm.runInNewContext(source,{window,document,Date:date,performance});
 assert.equal(video.playbackRate,limit>=100?100:limit);assert.equal(window.__MYBAppControl.requestedRate,100);
 window.setTimeout(()=>{},30000,'payload');assert.equal(timers.at(-1)[1],300);assert.equal(timers.at(-1)[2],'payload');
 window.setInterval(()=>{},1);assert.equal(intervals.at(-1)[1],4,'avoid zero-delay busy loops');
 now+=20;perf+=20;assert.equal(date.now(),3000);assert.equal(performance.now(),2100);
 const before=writes;rate=1;listener.call(video);assert.equal(video.playbackRate,Math.min(limit,100));assert.equal(writes,before+1,'one bounded enforcement, no ratechange loop');
 window.__MYBAppControl.setEnabled(false);assert.equal(video.playbackRate,1);assert.equal(date.now(),now);assert.equal(performance.now(),perf);
 window.setTimeout(()=>{},30000);assert.equal(timers.at(-1)[1],30000);
 window.__MYBAppControl.setEnabled(true);assert.equal(video.playbackRate,Math.min(limit,100));
 if(dynamic){cap=2;rate=1;const before=writes;listener.call(video);assert.equal(rate,2);assert(writes-before<12,"bounded renegotiation after metadata changes the player limit");}
 return writes;
}
assert(scenario(100)<10);assert(scenario(16)<15);assert(scenario(16,true)<10);assert(scenario(100,false,true)<20);
console.log('100x video requests, unsupported/clamped-rate fallback, bounded ratechange handling, 100x timers/clocks, and reversible per-app activation passed');
