# Android export — note / stub

Il progetto **non** committa `export_presets.cfg` con path/keystore reali (secret).  
Usa questa checklist quando sei pronto a esportare APK/AAB.

## Prerequisiti

| Tool | Note |
|------|------|
| Godot **4.7.x** Standard | Stessa major del `project.godot` (`4.7`) |
| Export templates | **Editor → Manage Export Templates** → scarica per la tua versione |
| JDK | OpenJDK **17** consigliato |
| Android SDK | Platform tools + build-tools; path in Editor Settings |
| Keystore | Debug ok per test; release keystore **mai** in git (già in `.gitignore`: `*.keystore`) |

## Setup in Godot

1. **Editor → Editor Settings → Export → Android**  
   - Android SDK path  
   - Debug keystore (generata da Godot o Android Studio)
2. **Project → Export → Add → Android**
3. Compila preset (nome, package, version code/name, landscape).
4. Esporta APK o AAB.

## Cosa non mettere in git

- Keystore, password, alias
- Path assoluti macchina-locali in preset se evitabili
- Token AdMob / IAP (non ancora nel progetto)

## Cloud agents

L’ambiente cloud installa Godot per **headless check / import**, non l’SDK Android completo.  
Export Android resta un flusso **locale** (o CI dedicato futuro con secret GitHub).

## `scenes/chunks/`

Lasciare le cartelle `scenes/chunks/{easy,medium,hard,swing}/` come sono: legacy placeholder.  
L’architettura attiva è **Segment + Module** (vedi README). Non aggiungere chunk prefab lì senza decisione di design.
