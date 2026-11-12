const CACHE_NAME='tsa-legacy-shell-v1';
const LEGACY_ENTRY='/legacy/index.html';
const SUPABASE_SCRIPT='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.119.0';

self.addEventListener('install',event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE_NAME);
    try{await cache.add(LEGACY_ENTRY)}catch(_){}
    try{
      const response=await fetch(SUPABASE_SCRIPT,{mode:'no-cors'});
      await cache.put(SUPABASE_SCRIPT,response);
    }catch(_){}
    await self.skipWaiting();
  })());
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(key=>key.startsWith('tsa-legacy-shell-')&&key!==CACHE_NAME).map(key=>caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);

  if(request.mode==='navigate'&&url.origin===self.location.origin&&url.pathname.startsWith('/legacy/')){
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE_NAME);
      try{
        const response=await fetch(request);
        if(response&&response.ok&&url.pathname.endsWith('/index.html'))await cache.put(LEGACY_ENTRY,response.clone());
        return response;
      }catch(_){
        return (await cache.match(LEGACY_ENTRY))||Response.error();
      }
    })());
    return;
  }

  if(url.href===SUPABASE_SCRIPT){
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE_NAME);
      const cached=await cache.match(SUPABASE_SCRIPT);
      if(cached)return cached;
      try{
        const response=await fetch(request);
        if(response&&(response.ok||response.type==='opaque'))await cache.put(SUPABASE_SCRIPT,response.clone());
        return response;
      }catch(_){return Response.error()}
    })());
  }
});
