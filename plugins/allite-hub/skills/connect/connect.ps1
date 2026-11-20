<#
.SYNOPSIS
  이 PC 의 Claude Code 를 올라이트라이프 온톨로지 허브에 연결한다(허브 인증서 확인·신뢰 + MCP 서버 'allite-hub' 등록).
  로그인은 하지 않는다 — 다시 시작한 Claude Code 에서 /mcp → allite-hub → Authenticate 를 누르면 브라우저에 허브 로그인 화면이 뜬다.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File connect.ps1 -Config "$env:USERPROFILE\Downloads\server.json"
  powershell -NoProfile -ExecutionPolicy Bypass -File connect.ps1 -Url https://<허브IP>:8443 -Fingerprint AA:BB:...

  종료 코드: 0 완료 · 1 오류 · 2 인증서 지문 확인 필요(FINGERPRINT= 줄을 관리자 값과 대조한 뒤 -Fingerprint 로 다시) · 3 지문 불일치(중단)
  비밀번호·토큰은 묻지도 쓰지도 않는다.
#>
[CmdletBinding()]
param(
  [string]$Config,
  [string]$Url,
  [string]$Fingerprint,
  [string]$Name = 'allite-hub',
  [switch]$NoSystemTrust,
  [switch]$SkipClaude
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$McpPath = '/api/v1/mcp'

function Stop-Connect([int]$Code, [string]$Message) {
  Write-Host "ERROR: $Message"
  exit $Code
}

function Read-HubConfig([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { Stop-Connect 1 "설정 파일을 찾을 수 없습니다: $Path" }
  try { $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Stop-Connect 1 "설정 파일(JSON)을 읽을 수 없습니다: $Path" }
  $fp = $null
  if ($j.PSObject.Properties['fingerprint'] -and $j.fingerprint) { $fp = [string]$j.fingerprint }
  return @{ Url = [string]$j.url; Fingerprint = $fp }
}

function Format-Fingerprint([byte[]]$Raw) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $h = $sha.ComputeHash($Raw) } finally { $sha.Dispose() }
  return (($h | ForEach-Object { $_.ToString('X2') }) -join ':')
}

function ConvertTo-HexOnly([string]$Fp) { return ($Fp -replace '[^0-9A-Fa-f]', '').ToUpperInvariant() }

# 허브에 TLS 로 붙어 인증서를 받고(검증 결과도 기록), 같은 연결로 MCP 로그인 메타데이터를 확인한다.
function Get-HubProbe([Uri]$U) {
  $port = $U.Port
  $tcp = New-Object System.Net.Sockets.TcpClient
  $iar = $tcp.BeginConnect($U.Host, $port, $null, $null)
  if (-not $iar.AsyncWaitHandle.WaitOne(8000)) { $tcp.Close(); Stop-Connect 1 "허브에 연결할 수 없습니다($($U.Host):$port). 사내망·주소를 확인하세요." }
  $tcp.EndConnect($iar)
  $script:TlsErrors = 'None'
  $stream = $tcp.GetStream()
  $ssl = $null
  try {
    if ($U.Scheme -eq 'https') {
      $cb = [System.Net.Security.RemoteCertificateValidationCallback] { param($s, $c, $ch, $e) $script:TlsErrors = [string]$e; return $true }
      $ssl = New-Object System.Net.Security.SslStream($stream, $false, $cb)
      $ssl.AuthenticateAsClient($U.Host, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
      $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (, $ssl.RemoteCertificate.GetRawCertData())
      $io = $ssl
    } else {
      $cert = $null
      $io = $stream
    }
    $req = "GET /.well-known/oauth-protected-resource$McpPath HTTP/1.1`r`nHost: $($U.Authority)`r`nAccept: application/json`r`nConnection: close`r`n`r`n"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($req)
    $io.Write($bytes, 0, $bytes.Length)
    $io.Flush()
    $reader = New-Object System.IO.StreamReader($io, [System.Text.Encoding]::UTF8)
    $resp = $reader.ReadToEnd()
    return @{ Cert = $cert; TlsErrors = $script:TlsErrors; Response = $resp }
  } finally {
    if ($ssl) { $ssl.Dispose() }
    $tcp.Close()
  }
}

# ── 1) 입력 ────────────────────────────────────────────────────────────────
if ($Config) {
  $c = Read-HubConfig $Config
  if (-not $Url) { $Url = $c.Url }
  if (-not $Fingerprint) { $Fingerprint = $c.Fingerprint }
} elseif (-not $Url) {
  $def = Join-Path $PSScriptRoot 'default-hub.json'   # 회사 키트(zip)로 받은 플러그인에만 있다
  if (Test-Path -LiteralPath $def) {
    $c = Read-HubConfig $def
    $Url = $c.Url
    if (-not $Fingerprint) { $Fingerprint = $c.Fingerprint }
  }
}
if (-not $Url) { Stop-Connect 1 '허브 주소가 없습니다. 관리자가 준 server.json(-Config) 이나 허브 주소(-Url https://<허브>:8443)를 주세요.' }
$Url = $Url.Trim().TrimEnd('/')
if ($Url.EndsWith($McpPath)) { $Url = $Url.Substring(0, $Url.Length - $McpPath.Length) }
if ($Url -notmatch '^[a-z]+://') { $Url = "https://$Url" }
try { $U = [Uri]$Url } catch { Stop-Connect 1 "허브 주소 형식이 틀렸습니다: $Url" }
if ($U.Scheme -ne 'https' -and $U.Scheme -ne 'http') { Stop-Connect 1 "허브 주소는 https:// 로 시작해야 합니다: $Url" }
$Url = "$($U.Scheme)://$($U.Authority)"
Write-Host "== 허브: $Url"

# ── 2) 인증서 확인 ─────────────────────────────────────────────────────────
$p = Get-HubProbe $U
$hubCrt = $null
if ($U.Scheme -eq 'https') {
  $fp = Format-Fingerprint $p.Cert.RawData
  $trusted = ($p.TlsErrors -eq 'None')
  if ($Fingerprint) {
    if ((ConvertTo-HexOnly $Fingerprint) -ne (ConvertTo-HexOnly $fp)) {
      Write-Host "FINGERPRINT=$fp"
      Stop-Connect 3 '허브 인증서 지문이 관리자 값과 다릅니다. 연결을 멈췄습니다 — 다른 서버이거나 가로채기일 수 있으니 관리자에게 알리세요.'
    }
    Write-Host "== 인증서 지문 일치: $fp"
  } elseif (-not $trusted) {
    Write-Host "FINGERPRINT=$fp"
    Write-Host 'CONFIRM: 이 허브는 자체 서명 인증서를 씁니다. 위 지문이 관리자가 알려 준 값(관리자 포털 > 클라이언트 내려받기)과 같은지 확인한 뒤 -Fingerprint 로 다시 실행하세요.'
    exit 2
  }
  if (-not $trusted) {
    $dir = Join-Path $env:USERPROFILE '.allite-hub'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $pem = "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($p.Cert.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----`n"
    $hubCrt = Join-Path $dir 'hub.crt'
    [System.IO.File]::WriteAllText($hubCrt, $pem, [System.Text.Encoding]::ASCII)
    Write-Host "== 인증서 저장: $hubCrt"
    if (-not $NoSystemTrust) {
      # Windows 신뢰 목록(현재 사용자) — Claude Code(기본: Windows 인증서 저장소 사용)와 브라우저 로그인 화면이 함께 믿는다. Windows 가 확인 창을 띄운다.
      $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', 'CurrentUser')
      try {
        $store.Open('ReadWrite')
        $have = @($store.Certificates | Where-Object { $_.Thumbprint -eq $p.Cert.Thumbprint }).Count -gt 0
        if (-not $have) { $store.Add($p.Cert); Write-Host '== Windows 신뢰 목록에 허브 인증서를 넣었습니다(현재 사용자).' }
        else { Write-Host '== Windows 신뢰 목록에 이미 있습니다.' }
      } catch {
        Write-Host "WARN: Windows 신뢰 목록에 넣지 못했습니다($($_.Exception.Message)). 브라우저 로그인 화면에서 인증서 경고가 보일 수 있습니다."
      } finally { $store.Close() }
    }
    # NODE_EXTRA_CA_CERTS(사용자 환경변수) — npm 으로 설치한 Claude Code 용. 이미 다른 파일을 쓰고 있으면 그 내용 + 허브 인증서를 묶는다.
    $bundle = Join-Path $dir 'ca-bundle.pem'
    $origFile = Join-Path $dir 'ca-original.txt'
    $cur = [Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'User')
    $target = $hubCrt
    if ($cur -and ($cur -ne $hubCrt)) {
      $orig = $cur
      if ($cur -eq $bundle -and (Test-Path -LiteralPath $origFile)) { $orig = (Get-Content -LiteralPath $origFile -Raw).Trim() }
      if ($orig -and ($orig -ne $bundle) -and ($orig -ne $hubCrt) -and (Test-Path -LiteralPath $orig)) {
        $body = [Convert]::ToBase64String($p.Cert.RawData)
        $origText = Get-Content -LiteralPath $orig -Raw
        if ((($origText -replace '\s', '')).Contains($body)) { $target = $orig }
        else {
          [System.IO.File]::WriteAllText($bundle, ($origText.TrimEnd() + "`n" + $pem), [System.Text.Encoding]::ASCII)
          [System.IO.File]::WriteAllText($origFile, $orig, [System.Text.Encoding]::UTF8)
          $target = $bundle
        }
      }
    }
    if ($cur -ne $target) {
      [Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $target, 'User')
      Write-Host "== 사용자 환경변수 NODE_EXTRA_CA_CERTS = $target"
    }
    $env:NODE_EXTRA_CA_CERTS = $target
  } else {
    Write-Host '== 공인 인증서 — 추가 설정이 필요 없습니다.'
  }
}

# ── 3) 허브가 로그인 연결을 지원하는지 ─────────────────────────────────────
$status = ($p.Response -split "`r?`n", 2)[0]
if ($status -notmatch ' 200 ' -or $p.Response -notmatch 'authorization_servers') {
  if ($status -match ' 403 ') { Stop-Connect 1 "허브가 이 PC 의 접속을 막았습니다(허용 대역 밖): $status" }
  Stop-Connect 1 "허브가 아이디·비밀번호 로그인 연결을 지원하지 않습니다(허브를 업데이트해야 합니다): $status"
}
Write-Host '== 허브 로그인 연결 지원 확인'

# ── 4) Claude Code 에 MCP 서버 등록(사용자 범위) ────────────────────────────
$mcpUrl = "$Url$McpPath"
$addCmd = "claude mcp add --transport http --scope user $Name $mcpUrl"
if (-not $SkipClaude) {
  $claude = Get-Command -Name 'claude.exe', 'claude.cmd' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $claude) {
    Write-Host "WARN: claude 명령을 찾지 못했습니다. 새 터미널에서 직접 실행하세요: $addCmd"
  } else {
    $ErrorActionPreference = 'Continue'
    & $claude.Source mcp remove $Name -s user *> $null
    $out = & $claude.Source mcp add --transport http --scope user $Name $mcpUrl 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($rc -ne 0) { Write-Host $out; Stop-Connect 1 "MCP 서버 등록 실패 — 직접 실행하세요: $addCmd" }
    Write-Host "== Claude Code 에 '$Name' 등록: $mcpUrl"
  }
}

# 같은 허브를 가리키는 옛 연결(개인 토큰 헤더)이 있으면 알린다 — Authorization 헤더가 있으면 Claude Code 는 로그인 대신 그 값을 쓴다.
$cfg = Join-Path $env:USERPROFILE '.claude.json'
if (Test-Path -LiteralPath $cfg) {
  try {
    $j = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
    $found = @()
    $scan = { param($servers, $scope) if ($servers) { foreach ($pr in $servers.PSObject.Properties) {
          $v = $pr.Value
          if ($pr.Name -ne $Name -and $v.PSObject.Properties['url'] -and ([string]$v.url).Contains($U.Authority)) { $script:found += "$($pr.Name) ($scope)" } } } }
    $script:found = @()
    if ($j.PSObject.Properties['mcpServers']) { & $scan $j.mcpServers 'user' }
    if ($j.PSObject.Properties['projects']) { foreach ($pp in $j.projects.PSObject.Properties) { if ($pp.Value.PSObject.Properties['mcpServers']) { & $scan $pp.Value.mcpServers "local: $($pp.Name)" } } }
    foreach ($f in $script:found) { Write-Host "OLD: 같은 허브를 가리키는 다른 연결이 있습니다 — $f. 옛 토큰 방식이면 지우세요: claude mcp remove <이름> -s <user|local>" }
  } catch { }
}

Write-Host "OK: 연결 설정을 마쳤습니다 ($mcpUrl)."
Write-Host 'NEXT: Claude Code 를 완전히 끄고 새 터미널에서 다시 실행 → /mcp → allite-hub → Authenticate → 브라우저의 허브 화면에서 회사 아이디·비밀번호로 로그인'
exit 0
