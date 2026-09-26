param(
    [string]$ComfyUrl = 'http://localhost:8188',
    [int]$DebugPort = 9228,
    [string]$Browser = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    [string]$ScreenshotDirectory = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$profile = Join-Path $env:TEMP ('comfy-workflow-check-' + [guid]::NewGuid())
$socket = [System.Net.WebSockets.ClientWebSocket]::new()
$script:messageId = 0

function Send-CDP([string]$Method, $Parameters) {
    $script:messageId++
    $id = $script:messageId
    $json = @{ id = $id; method = $Method; params = $Parameters } | ConvertTo-Json -Depth 50 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $deadline = [Threading.CancellationTokenSource]::new(60000)
    try {
        $null = $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $deadline.Token).GetAwaiter().GetResult()
        do {
            $stream = [IO.MemoryStream]::new()
            try {
                do {
                    $buffer = [byte[]]::new(65536)
                    $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $deadline.Token).GetAwaiter().GetResult()
                    if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'Browser connection closed' }
                    $stream.Write($buffer, 0, $received.Count)
                } until ($received.EndOfMessage)
                $response = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
            } finally { $stream.Dispose() }
        } until ($response.id -eq $id)
        if ($response.error) { throw ($response.error | ConvertTo-Json -Compress) }
        return $response.result
    } finally { $deadline.Dispose() }
}

try {
    if (Get-NetTCPConnection -LocalPort $DebugPort -ErrorAction SilentlyContinue) { throw 'Debug port already in use' }
    $browserProcess = Start-Process -FilePath $Browser -WindowStyle Hidden -PassThru -ArgumentList @(
        '--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-sync',
        "--remote-debugging-port=$DebugPort", "--user-data-dir=`"$profile`"", $ComfyUrl
    )
    $page = $null
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $tabs = Invoke-RestMethod "http://127.0.0.1:$DebugPort/json/list" -TimeoutSec 5
            $page = $tabs | Where-Object { $_.type -eq 'page' -and $_.url -like "$ComfyUrl*" } | Select-Object -First 1
        } catch { if ($i -eq 1) { Write-Host $_.Exception.Message } }
        if ($page) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $page) { throw 'Browser did not start' }
    $null = $socket.ConnectAsync([uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $null = Send-CDP 'Emulation.setDeviceMetricsOverride' @{ width = 1920; height = 1080; deviceScaleFactor = 1; mobile = $false }
    foreach ($model in @('stable-diffusion', 'anima')) {
        $path = Join-Path $root "workflows/generation/$model/$model-text-to-image.json"
        $workflow = Get-Content -LiteralPath $path -Raw
        $expression = @'
(async () => {
  for (let i = 0; !window.comfyAPI?.app?.app?.graph && i < 200; i++) await new Promise(r => setTimeout(r, 100));
  const { app } = await import('/scripts/app.js');
  for (let i = 0; !window.LiteGraph?.registered_node_types?.StringConcatenate && i < 200; i++) await new Promise(r => setTimeout(r, 100));
  if (!window.LiteGraph?.registered_node_types?.StringConcatenate) throw new Error('Node registration not ready');
  await new Promise(r => setTimeout(r, 2500));
  const workflow = WORKFLOW;
  const assert = (value, message) => { if (!value) throw new Error(message); };
  for (let i = 0; !app.graph && i < 100; i++) await new Promise(r => setTimeout(r, 100));
  await app.loadGraphData(structuredClone(workflow));
  const nodes = app.graph._nodes;
  const fields = nodes.filter(n => n.type === 'PrimitiveStringMultiline').sort((a,b) => a.title.localeCompare(b.title));
  assert(fields.length === 6, 'Expected six prompt fields: ' + JSON.stringify(nodes.map(n => n.type)));
  async function serialize() { return (await app.graphToPrompt()).output; }
  function textAt(prompt, id) {
    const node = prompt[id];
    if (node.class_type === 'PrimitiveStringMultiline') return node.inputs.value;
    if (node.class_type === 'StringConcatenate') return textAt(prompt,node.inputs.string_a[0]) + node.inputs.delimiter + textAt(prompt,node.inputs.string_b[0]);
    throw new Error('Unexpected string node: ' + JSON.stringify({id,node}));
  }
  function ancestors(prompt) {
    const seen = new Set();
    function walk(id) { if (seen.has(id)) return; seen.add(id); for (const value of Object.values(prompt[id].inputs)) if (Array.isArray(value)) walk(String(value[0])); }
    for (const [id,n] of Object.entries(prompt)) if (n.class_type === 'SaveImage') walk(id);
    return [...seen].map(id => prompt[id]);
  }
  let prompt = await serialize();
  const positive = nodes.find(n => n.title === 'Positive（自動入力）');
  const joined = textAt(prompt, prompt[positive.id].inputs.text[0]);
  assert(joined === fields.map(n => n.widgets[0].value).join('\n'), 'Prompt order or widget serialization changed');
  let active = ancestors(prompt);
  assert(!active.some(n => /LoraLoader|UpscaleModel|ImageScaleBy/.test(n.class_type)), 'Optional nodes required while disabled');
  const loras = nodes.filter(n => /^LoraLoader/.test(n.type));
  for (const n of loras) { n.mode = 0; n.widgets.find(w => w.name === 'lora_name').value = 'test.safetensors'; }
  prompt = await serialize();
  assert(ancestors(prompt).filter(n => /^LoraLoader/.test(n.class_type)).length === 2, 'Both LoRAs must reach sampler');
  for (const n of loras) n.mode = 4;
  const scale = nodes.find(n => n.type === 'ImageScaleBy');
  const upscale = nodes.find(n => n.type === 'ImageUpscaleWithModel');
  scale.mode = 0;
  prompt = await serialize(); active = ancestors(prompt);
  assert(active.some(n => n.class_type === 'ImageScaleBy') && !active.some(n => n.class_type === 'UpscaleModelLoader'), 'Simple resize incorrectly requires model');
  scale.mode = 4; upscale.mode = 0;
  prompt = await serialize(); active = ancestors(prompt);
  assert(active.some(n => n.class_type === 'UpscaleModelLoader') && !active.some(n => n.class_type === 'ImageScaleBy'), 'Model upscale path incorrect');
  scale.mode = 0;
  prompt = await serialize(); active = ancestors(prompt);
  assert(active.some(n => n.class_type === 'ImageScaleBy') && active.some(n => n.class_type === 'ImageUpscaleWithModel'), 'Combined upscale path incorrect');
  await app.loadGraphData(structuredClone(workflow));
  app.canvas.ds.scale = 0.58;
  app.canvas.ds.offset = [160, 120];
  app.canvas.setDirty(true, true);
  app.canvas.draw(true, true);
  await new Promise(r => setTimeout(r, 700));
  return { status: 'PASS', nodes: nodes.length, checks: ['ordered prompt', 'optional models bypassed', 'two LoRAs', 'resize', 'model upscale', 'combined upscale'] };
})()
'@
        $expression = $expression.Replace('WORKFLOW', $workflow)
        $result = Send-CDP 'Runtime.evaluate' @{ expression = $expression; awaitPromise = $true; returnByValue = $true }
        if ($result.exceptionDetails) { throw ($result.exceptionDetails | ConvertTo-Json -Depth 20) }
        "$model : $($result.result.value | ConvertTo-Json -Compress -Depth 10)"
        if ($ScreenshotDirectory) {
            $null = New-Item -ItemType Directory -Force -Path $ScreenshotDirectory
            $capture = Send-CDP 'Page.captureScreenshot' @{ format = 'png' }
            [IO.File]::WriteAllBytes((Join-Path (Resolve-Path $ScreenshotDirectory) "$model.png"), [Convert]::FromBase64String($capture.data))
        }
    }
} finally {
    if ($socket.State -eq [Net.WebSockets.WebSocketState]::Open) {
        try { $null = Send-CDP 'Browser.close' @{} } catch {}
    }
    $socket.Dispose()
    if ($browserProcess -and -not $browserProcess.HasExited) { Stop-Process -Id $browserProcess.Id -ErrorAction SilentlyContinue }
}
