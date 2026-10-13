# Run Infinity

Endless runner 2D mobile basato su Godot 4.  
Architettura local-first: Segment + Module, senza backend, AdMob o IAP.

**Repository:** https://github.com/alcodestudio2025/run-infinity

---

## Requisiti

| Tool | Versione / note |
|------|-----------------|
| **Godot** | 4.3+ (il progetto è impostato su **4.7 Mobile**) |
| **Git** | Per clonare e aggiornare il repo |
| **GitHub CLI** (opzionale) | Solo se vuoi usare `gh` |
| **Android SDK / JDK** (opzionale) | Solo per export Android |

Scarica Godot: https://godotengine.org/download  
Scarica Git: https://git-scm.com/downloads

---

## Setup su un altro PC (da zero)

### 1. Installa Git e Godot

1. Installa **Git**.
2. Installa **Godot 4.7** (o comunque 4.3+).
   - Preferisci la build **Standard** (non .NET) se usi solo GDScript.
3. (Opzionale) Installa **GitHub CLI** da https://cli.github.com

### 2. Clona il repository

Apri un terminale (PowerShell, Terminal, ecc.):

```bash
cd C:\Dev
git clone https://github.com/alcodestudio2025/run-infinity.git
cd run-infinity
```

Se usi SSH:

```bash
git clone git@github.com:alcodestudio2025/run-infinity.git
cd run-infinity
```

### 3. Apri il progetto in Godot

1. Avvia **Godot**.
2. **Import** → seleziona la cartella `run-infinity` → apri `project.godot`.
3. Attendi che Godot generi la cartella `.godot/` (import asset / cache).
4. Premi **F5** (o il pulsante Play).

La scena principale è già impostata:

```
run/main_scene = "res://scenes/Main.tscn"
```

### 4. Verifica gli Autoload

In Godot: **Project → Project Settings → Autoload**

Devono essere presenti, in questo ordine:

| Nome | Path |
|------|------|
| EventBus | `res://autoloads/EventBus.gd` |
| ServiceLocator | `res://autoloads/ServiceLocator.gd` |
| SaveManager | `res://autoloads/SaveManager.gd` |
| GameStateManager | `res://autoloads/GameStateManager.gd` |
| AudioManager | `res://autoloads/AudioManager.gd` |

Se mancano, aggiungili con **Add** e salva.

### 5. Verifica layer di collisione 2D

**Project → Project Settings → Layer Names → 2D Physics**

| Layer | Nome |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | obstacle |
| 4 | collectible |
| 5 | ui |
| 6 | camera |

### 6. Display / orientamento

Il progetto è in **landscape 1920×1080**:

- Viewport: `1920 x 1080`
- Stretch: `canvas_items` + `expand`
- Orientamento handheld: landscape

---

## Controlli di gioco (stato attuale)

| Azione | Input |
|--------|--------|
| Salto | Spazio / `ui_accept` / tap |
| Slide | Freccia giù / `ui_down` / swipe verso il basso |
| Restart dopo Game Over | `R` oppure Spazio / `ui_accept` |

---

## Cosa aspettarsi a F5

1. Avvio di `Main.tscn` → carica `GameScene`.
2. Mondo che scorre (Segment + Module).
3. Player a ~28% della larghezza schermo.
4. Ostacoli rossi su segmenti dispari.
5. HUD in alto a sinistra: Score / Distance.
6. Collisione → GAME OVER → mondo fermo → messaggio restart.
7. `R` o Spazio → run riparte.

---

## Struttura progetto (sintesi)

```
run-infinity/
├── autoloads/          # EventBus, ServiceLocator, SaveManager, GameState, Audio
├── scripts/
│   ├── core/           # Engine: RunLoop, Segment*, WorldScroller, GameConfig...
│   ├── player/         # Player, movimento, config, stati
│   ├── modules/        # SegmentModule, ObstacleModule, Placeholder
│   ├── services/       # Interfacce + local/null
│   ├── ui/             # HUD
│   └── systems/        # Placeholder swing
├── scenes/
│   ├── Main.tscn
│   ├── game/           # GameScene, World, CameraRig, Ground
│   ├── player/
│   ├── segments/
│   ├── modules/
│   └── ui/
├── assets/
├── project.godot
└── README.md
```

---

## Aggiornare il progetto su un PC già configurato

```bash
cd C:\Dev\run-infinity
git pull origin main
```

Poi riapri in Godot (o ricarica il progetto se era già aperto).

---

## Push delle modifiche (workflow consigliato)

Preferisci **feature branch + Pull Request verso `main`** (evita push diretti e force-push su `main`):

```bash
cd C:\Dev\run-infinity   # o il path del clone
git checkout main
git pull origin main
git checkout -b feature/descrizione-breve
# ... modifiche ...
git add -A
git commit -m "Descrivi la modifica"
git push -u origin feature/descrizione-breve
# Apri una PR su GitHub verso main
```

Dettagli: vedi i docs del Project Cursor (`workflow-git.md` / `project-context.md`) quando lavori in cloud.

### Prima volta su un nuovo PC con commit

Se Git chiede nome/email:

```bash
git config --global user.name "IlTuoNome"
git config --global user.email "tua-email@example.com"
```

Oppure usa l’email noreply di GitHub:

```text
{id}+{username}@users.noreply.github.com
```

### Login GitHub CLI (opzionale)

```bash
gh auth login
```

Segui il flusso browser / device code.

---

## Export Android (opzionale, futuro)

1. In Godot: **Editor → Manage Export Templates** → scarica i template per la tua versione.
2. Installa **Android SDK** e **JDK** (OpenJDK 17 consigliato).
3. **Editor → Editor Settings → Export → Android**  
   Imposta SDK path e keystore (debug ok per test).
4. **Project → Export → Add → Android**.
5. Esporta APK/AAB.

Il progetto non include ancora AdMob, IAP o backend.

---

## Problemi comuni

### “Too few arguments for load()”
Non chiamare `load()` senza path. Per i salvataggi usare `SaveManager.load_data()`.

### Camera: Invalid assignment of `current`
In Godot 4 usare `camera.make_current()`, non `camera.current = true`.

### Segment ground Nil / GroundPolygon
`configure()` deve essere chiamato **dopo** `add_child()`.  
`SegmentManager` già lo fa in ordine corretto.

### Autoload mancanti
Riapri Project Settings → Autoload e verifica l’ordine (vedi tabella sopra).

### `.godot/` non c’è dopo il clone
Normale: viene generata all’apertura in Godot. Non va commitata.

### Differenze fine riga Windows/Linux
Il repo ha `.gitattributes` / `.editorconfig`. Se Git avvisa su CRLF/LF, è solo un warning.

---

## Checklist “altro PC pronto”

- [ ] Git installato
- [ ] Godot 4.3+ (idealmente 4.7) installato
- [ ] Repo clonato
- [ ] Progetto importato in Godot
- [ ] Autoload presenti e nell’ordine corretto
- [ ] Layer 2D Physics configurati
- [ ] F5 funziona senza errori in Output
- [ ] Salto / slide / game over / restart funzionano
- [ ] (Opzionale) `git pull` / `git push` configurati con il tuo account

---

## Note architetturali utili

- **Niente chunk prefab**: mondo = `Segment` + `SegmentModule`.
- **WorldScroller** muove i segmenti; **SegmentManager** li crea/ricicla.
- **ModuleSpawner** attacca placeholder/ostacoli; in futuro lo farà DifficultyDirector.
- **ServiceLocator** usa servizi local/null (score/save local, ads/analytics null).
- Target primario: **Android**; landscape **1920×1080**.
