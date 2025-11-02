# Cristian Pérez Rodriguez — Sitio estático para GitHub Pages

Este ZIP contiene tu portfolio completo con páginas individuales para cada proyecto.

## 🚀 Despliegue rápido

### macOS / Linux
```bash
chmod +x ./deploy-gh-pages.sh
./deploy-gh-pages.sh
```

### Windows (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File .\deploy-gh-pages.ps1
```

> Requisitos: tener instalados **git** y **GitHub CLI (`gh`)**. Durante el despliegue, si no has iniciado sesión, se abrirá el navegador para autenticarte.

## 📁 Archivos incluidos
- `.editorconfig`
- `.gitattributes`
- `.nojekyll`
- `deploy-gh-pages.ps1`
- `deploy-gh-pages.sh`
- `index.html`

## ℹ️ Notas
- GitHub Pages publicará desde la rama `main` y la carpeta raíz.
- Si deseas dominio propio, edita/crea el archivo `CNAME` y vuelve a ejecutar el script.
- La primera publicación puede tardar 1–2 minutos.
- Cada proyecto tiene su propia página HTML para mejor SEO.
