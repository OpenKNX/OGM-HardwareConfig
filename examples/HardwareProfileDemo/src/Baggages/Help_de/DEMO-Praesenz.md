# Demo-Präsenz

**Wie es funktioniert:** Ein Modul, das nur manche Geräte unterstützen. Jedes OpenKNX-Modul hat auf der Seite OpenKNX → Module einen Schalter (`BASE_ModuleEnabled_<Präfix>`); steht er auf aus, verschwindet das ganze Modul aus dem Baum. Das Manifest setzt diesen Schalter mit `<Fix capability="!Presence" value="0" show="assign">` auf allen Geräten ohne Präsenzsensor auf aus. Das Modul selbst weiß nichts von der Hardware.

- **Raumcontroller Pro** (Präsenzsensor): das Modul ist sichtbar.
- **Alle anderen Geräte**: das Modul ist ausgeblendet.
- **Nicht gewählt**: das Modul ist sichtbar.
