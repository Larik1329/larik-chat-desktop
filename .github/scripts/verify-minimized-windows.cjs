// Windows runner only: synthetic windows, no Chat accounts, network or user media.
const{app,BrowserWindow,desktopCapturer,session}=require('electron');const assert=require('node:assert/strict');const{windowsCapture}=require(process.env.CAPTURE_MODULE);
let target,requester;const sleep=ms=>new Promise(r=>setTimeout(r,ms));
app.whenReady().then(async()=>{
 try{
  assert.equal(process.platform,'win32');
  target=new BrowserWindow({width:640,height:360,title:'Larik minimized capture CI',show:true,webPreferences:{sandbox:true,contextIsolation:true,nodeIntegration:false}});
  await target.loadURL('data:text/html,<title>Larik minimized capture CI</title><body style="background:%235865f2;color:white;font:32px sans-serif">Synthetic capture test</body>');
  target.minimize();for(let n=0;n<40&&!target.isMinimized();n++)await sleep(50);assert(target.isMinimized());
  const native=windowsCapture({pid:0}),handle=target.getNativeWindowHandle().readBigUInt64LE(0),id='window:'+handle+':0';
  const row=native.list().find(s=>s.id===id);assert(row,'Native catalogue lost minimized window');assert(row.minimized);
  const before=await desktopCapturer.getSources({types:['window'],thumbnailSize:{width:0,height:0}});console.log('CHROMIUM_MINIMIZED_LISTED',before.some(s=>s.id===id));
  await native.prepare(row);for(let n=0;n<40&&target.isMinimized();n++)await sleep(50);assert.equal(target.isMinimized(),false);
  const after=await desktopCapturer.getSources({types:['window'],thumbnailSize:{width:0,height:0}});assert(after.some(s=>s.id===id),'Restored native HWND cannot be selected by Chromium');
  console.log('WINDOWS_NATIVE_MINIMIZED_ENUM_RESTORE_PASS');
  session.defaultSession.setDisplayMediaRequestHandler((_request,callback)=>callback({video:{id:row.id,name:row.name}}));
  requester=new BrowserWindow({show:true,width:400,height:300,webPreferences:{sandbox:true,contextIsolation:true,nodeIntegration:false}});
  await requester.loadFile(require('node:path').join(__dirname,'capture-check.html'));
  const settings=await requester.webContents.executeJavaScript(`(async()=>{const stream=await navigator.mediaDevices.getDisplayMedia({video:true,audio:false});try{const video=document.createElement('video');video.muted=true;video.srcObject=stream;document.body.append(video);await video.play();await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('No captured frame')),10000);video.requestVideoFrameCallback(()=>{clearTimeout(timer);resolve();});});return{...stream.getVideoTracks()[0].getSettings(),decodedWidth:video.videoWidth,decodedHeight:video.videoHeight};}finally{stream.getTracks().forEach(t=>t.stop());}})()`,true);
  assert(settings.decodedWidth>0&&settings.decodedHeight>0);console.log('WINDOWS_NATIVE_WINDOW_CAPTURE_FRAME_PASS',JSON.stringify(settings));
 }catch(e){console.error(e);process.exitCode=1;}finally{target?.destroy();requester?.destroy();app.exit(process.exitCode||0);}
});
