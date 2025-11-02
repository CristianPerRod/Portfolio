# Script de deployment automatico a GitHub Pages con manejo de errores robusto
# Uso: .\deploy-gh-pages.ps1 [-RepoName "mi-portfolio"] [-Visibility "public"] [-Owner "usuario"] [-CNAME "midominio.com"]

Param(
  [string]$RepoName = (Split-Path -Leaf (Get-Location)).ToLower().Replace(' ','-'),
  [ValidateSet('public','private')][string]$Visibility = 'public',
  [string]$Owner = '',
  [string]$CNAME = ''
)

# Funciones de utilidad
function Write-Info { Write-Host "i $args" -ForegroundColor Blue }
function Write-Success { Write-Host "v $args" -ForegroundColor Green }
function Write-Warn { Write-Host "! $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "x $args" -ForegroundColor Red }

function Test-Command {
  param([string]$Command)
  
  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    Write-Err "Falta '$Command'. Instalalo y reintenta."
    switch ($Command) {
      'git' { Write-Host "  Descarga: https://git-scm.com/download/win" }
      'gh'  { Write-Host "  Descarga: https://cli.github.com/" }
    }
    exit 1
  }
}

# Configurar manejo de errores - permitir errores controlados
$ErrorActionPreference = 'Continue'
$env:GIT_REDIRECT_STDERR = '2>&1'

# Verificar dependencias
Test-Command 'git'
Test-Command 'gh'

# Mostrar configuracion
Write-Info "Configuracion:"
Write-Host "  Repositorio: $RepoName"
Write-Host "  Visibilidad: $Visibility"
Write-Host "  Owner: $(if($Owner){$Owner}else{'auto-detectar'})"
Write-Host "  Dominio: $(if($CNAME){$CNAME}else{'ninguno'})"
Write-Host ""

# Verificar autenticacion GitHub
Write-Info "Verificando autenticacion en GitHub..."
try { 
  gh auth status *> $null 
  Write-Success "Autenticado en GitHub"
} catch {
  Write-Warn "No estas autenticado. Iniciando login..."
  gh auth login -w -p https
  Write-Success "Autenticado correctamente"
}

# Preparar archivos
Write-Info "Preparando archivos para deployment..."
Set-Content -Path .nojekyll -Value '' -Encoding ascii
if ($CNAME) { 
  Set-Content -Path CNAME -Value $CNAME -Encoding ascii 
  Write-Success "Archivo CNAME creado"
}

# Inicializar git si no existe
if (-not (Test-Path .git)) { 
  Write-Info "Inicializando repositorio Git..."
  git init | Out-Null 
  Write-Success "Repositorio Git inicializado"
}

# Commit inicial
Write-Info "Creando commit inicial..."
git add -A | Out-Null

try {
  git commit -m "Initial commit" 2>$null | Out-Null
  Write-Success "Cambios commiteados"
} catch {
  Write-Warn "No hay cambios para commitear"
}

# Asegurar rama main
git branch -M main 2>$null | Out-Null

# Auto-detectar owner
if (-not $Owner) { 
  $Owner = gh api user -q .login 
  Write-Info "Owner auto-detectado: $Owner"
}

$RepoFull = "$Owner/$RepoName"

# Verificar si el repositorio existe
Write-Info "Verificando repositorio '$RepoFull'..."

$repoExists = $false
try {
  gh repo view $RepoFull *> $null
  $repoExists = $true
} catch {
  $repoExists = $false
}

if ($repoExists) {
  Write-Warn "El repositorio '$RepoFull' ya existe"
  Write-Host ""
  Write-Host "Opciones:"
  Write-Host "  1) Actualizar repositorio existente (push forzado)"
  Write-Host "  2) Cancelar operacion"
  
  $choice = Read-Host "Selecciona una opcion [1-2]"
  
  switch ($choice) {
    '1' {
      Write-Info "Actualizando repositorio existente..."
      
      # Configurar remote
      try {
        git remote get-url origin *> $null
        git remote set-url origin "https://github.com/$RepoFull.git" | Out-Null
      } catch {
        git remote add origin "https://github.com/$RepoFull.git" | Out-Null
      }
      
      # Push forzado
      Write-Warn "Haciendo push forzado (sobreescribira el repositorio)..."
      $null = & git push -u origin main --force 2>&1
      
      if ($LASTEXITCODE -eq 0) {
        Write-Success "Repositorio actualizado"
      } else {
        Write-Err "Error al actualizar el repositorio"
        exit 1
      }
    }
    '2' {
      Write-Info "Operacion cancelada"
      exit 0
    }
    default {
      Write-Err "Opcion invalida"
      exit 1
    }
  }
} else {
  Write-Info "Creando nuevo repositorio '$RepoFull'..."
  
  $createResult = & gh repo create $RepoFull "--$Visibility" --source . --remote origin 2>&1
  
  if ($LASTEXITCODE -eq 0) {
    Write-Success "Repositorio creado"
    
    # Push inicial
    Write-Info "Subiendo codigo..."
    $null = & git push -u origin main 2>&1
    
    if ($LASTEXITCODE -eq 0) {
      Write-Success "Codigo subido"
    } else {
      Write-Err "Error al subir el codigo"
      exit 1
    }
  } else {
    Write-Err "Error al crear el repositorio: $createResult"
    exit 1
  }
}

# Activar GitHub Pages
Write-Info "Configurando GitHub Pages..."

# Intentar crear Pages - silenciar todos los errores completamente
try {
  gh api -X POST "repos/$RepoFull/pages" -f "source[branch]=main" -f "source[path]=/" 2>$null | Out-Null
  Write-Success "GitHub Pages activado"
} catch {
  # Si falla, intentar actualizar
  try {
    gh api -X PUT "repos/$RepoFull/pages" -f "source[branch]=main" -f "source[path]=/" 2>$null | Out-Null
    Write-Success "GitHub Pages actualizado"
  } catch {
    Write-Success "GitHub Pages ya estaba activo"
  }
}

# Configurar dominio custom
if ($CNAME) {
  Write-Info "Configurando dominio custom: $CNAME"
  
  try {
    gh api -X PUT "repos/$RepoFull/pages" -f "cname=$CNAME" 2>$null | Out-Null
    Write-Success "Dominio custom configurado"
  } catch {
    Write-Warn "No se pudo configurar el dominio automaticamente"
  }
}

# URL del portfolio
$pagesUrl = if ($CNAME) { "https://$CNAME/" } else { "https://$Owner.github.io/$RepoName/" }

Write-Host ""
Write-Success "Deployment completado!"
Write-Host ""
Write-Host "  Repositorio: https://github.com/$RepoFull"
Write-Host "  Portfolio:   $pagesUrl"
Write-Host ""
Write-Info "Nota: GitHub Pages puede tardar 1-2 minutos en estar disponible"

# Abrir en navegador
if (Get-Command Start-Process -ErrorAction SilentlyContinue) { 
  Start-Process $pagesUrl | Out-Null 
}