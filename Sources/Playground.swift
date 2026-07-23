import Foundation

// ---------------------------------------------------------------------------
// Playground: GET / — página auto-servida pra testar o protocolo do Craby
// (estados, eventos, vigília, celebrate, balões). Zero dependências: HTML+JS
// inline, mesma origem, sem CORS. O "swagger" do caranguejo.
// ---------------------------------------------------------------------------

let playgroundHTML = #"""
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Craby Playground</title>
<style>
  body { font: 14px -apple-system, sans-serif; background: #1c1c1e; color: #eee;
         max-width: 760px; margin: 24px auto; padding: 0 16px; }
  h1 { font-size: 20px; } h2 { font-size: 15px; margin: 22px 0 8px; color: #f6b73c; }
  .card { background: #2a2a2d; border-radius: 10px; padding: 12px 14px; margin: 10px 0; }
  button { background: #f6b73c; border: 0; border-radius: 6px; padding: 6px 12px;
           margin: 3px 4px 3px 0; font-weight: 600; cursor: pointer; }
  button.alt { background: #555; color: #eee; }
  input, select { background: #1c1c1e; color: #eee; border: 1px solid #444;
           border-radius: 6px; padding: 5px 8px; margin: 2px 4px 2px 0; }
  #out { background: #111; border-radius: 8px; padding: 10px; white-space: pre-wrap;
         font: 12px ui-monospace, monospace; min-height: 60px; }
  small { color: #999; }
</style>
</head>
<body>
<h1>🦀 Craby Playground</h1>
<p><small>Dispare os endpoints e olhe o pet no canto da tela. Contrato completo no
<a href="https://github.com/duperez/crab-companion/blob/main/PROTOCOL.md" style="color:#f6b73c">PROTOCOL.md</a>.</small></p>

<h2>Estados (sessão "playground")</h2>
<div class="card">
  <button onclick="hit('/working?session=playground&project=playground')">working</button>
  <button onclick="hit('/done?session=playground&project=playground&summary=tarefa%20de%20teste%20pronta')">done</button>
  <button onclick="hit('/attention?session=playground&project=playground')">attention</button>
  <button onclick="hit('/idle?session=playground&project=playground')">idle</button>
</div>

<h2>Evento estruturado (multi-fonte)</h2>
<div class="card">
  <input id="evSource" value="ci" size="6" title="source">
  <select id="evState"><option>working</option><option>done</option>
    <option>attention</option><option>idle</option></select>
  <input id="evProject" value="meu-repo" size="10" title="project">
  <input id="evDetail" value="pipeline no step de testes" size="24" title="detail">
  <input id="evUrl" placeholder="url (opcional)" size="18">
  <button onclick="sendEvent()">enviar /event</button>
  <div><small>attention + url = legenda no pet e clique abre o link</small></div>
</div>

<h2>Vigília (/watch)</h2>
<div class="card">
  <input id="wId" value="demo" size="8" title="id">
  <input id="wLabel" value="servidor:4600" size="14" title="label">
  <input id="wUrl" placeholder="url (opcional)" size="18">
  <button onclick="watch('alive')">🟢 alive</button>
  <button onclick="watch('dead')">🔴 dead</button>
  <button class="alt" onclick="watch('gone')">gone</button>
  <div><small>alive registra no tooltip/menu · dead vira attention com legenda</small></div>
</div>

<h2>Festa</h2>
<div class="card">
  <input id="cText" value="Push feito! 🎉" size="24">
  <button onclick="hit('/celebrate?text=' + encodeURIComponent(v('cText')))">/celebrate</button>
</div>

<h2>Balões (long-poll: a resposta chega quando você clica no balão)</h2>
<div class="card">
  <button onclick="ask({title:'[playground] Permissão', detail:'Craby quer testar o balão', urgent:false})">permissão</button>
  <button onclick="ask({title:'[playground] Permissão urgente', detail:'rm -rf / (de mentira)', urgent:true, rule:'Bash(rm *)'})">urgente + regra</button>
  <button onclick="ask({title:'[playground] Pergunta', detail:'Qual opção?', urgent:false, options:['Opção A','Opção B','Opção C']})">múltipla escolha</button>
  <button onclick="ask({title:'[playground] Texto', detail:'Digite algo aí', urgent:false, input:true})">texto livre</button>
  <div><small>sem clique em ~45s (90s no texto) o balão devolve "ask"</small></div>
</div>

<h2>Introspecção</h2>
<div class="card">
  <button class="alt" onclick="status()">GET /status</button>
</div>

<h2>Resposta</h2>
<div id="out">—</div>

<script>
  const out = document.getElementById('out');
  const v = id => document.getElementById(id).value;
  function show(text) { out.textContent = text; }
  async function hit(path) {
    show('→ GET ' + path);
    try { show('→ GET ' + path + '\n← ' + await (await fetch(path)).text()); }
    catch (e) { show('erro: ' + e); }
  }
  function sendEvent() {
    const q = new URLSearchParams({ source: v('evSource'), session: 'playground',
      state: document.getElementById('evState').value,
      project: v('evProject'), detail: v('evDetail') });
    if (v('evUrl')) q.set('url', v('evUrl'));
    hit('/event?' + q);
  }
  function watch(status) {
    const q = new URLSearchParams({ id: v('wId'), label: v('wLabel'), status,
      source: 'playground' });
    if (v('wUrl')) q.set('url', v('wUrl'));
    hit('/watch?' + q);
  }
  async function ask(payload) {
    show('→ POST /ask ' + JSON.stringify(payload) + '\n… aguardando seu clique no balão');
    try {
      const r = await fetch('/ask', { method: 'POST', body: JSON.stringify(payload) });
      show('← resposta do balão: ' + await r.text());
    } catch (e) { show('erro: ' + e); }
  }
  async function status() {
    try { show(JSON.stringify(await (await fetch('/status')).json(), null, 2)); }
    catch (e) { show('erro: ' + e); }
  }
</script>
</body>
</html>
"""#
