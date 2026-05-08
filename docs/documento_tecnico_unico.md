# Documento tecnico unico — App kiosk visitatori + allineamento modulo Odoo

## 1) Obiettivo del documento
Questo documento descrive **solo ciò che emerge dal codice dell'app Flutter** presente in questo repository, senza assunzioni su implementazioni Odoo non visibili qui.

Serve come base da fornire a ChatGPT insieme all'export del modulo Odoo (modelli, campi, viste, automazioni, ACL) per:
- verificare coerenza tra app e modulo;
- identificare mismatch di campi/selection/stati;
- pianificare evoluzioni funzionali in sicurezza.

---

## 2) Contesto tecnico app
- Tecnologia: Flutter/Dart.
- Routing principale:
  - `/visit/checkin`
  - `/privacy`
  - `/badge/scan`
  - `/checkout-scan`
- Backend: Odoo via JSON-RPC (`/web/session/authenticate`, `/web/dataset/call_kw`).
- Modelli Odoo configurati lato app:
  - visite: `x_visite`
  - badge: `x_badge`
  - visitatori: `x_visitatori`

---

## 3) Flusso end-to-end (comportamento applicativo)

### 3.1 Check-in (creazione visita)
1. L'utente compila dati visitatore/visita (nome, cognome, titolo, società, motivo, documento, scadenza documento, host).
2. L'app esegue find-or-create del visitatore su `x_visitatori`.
3. L'app crea una visita in stato `draft` su `x_visite`, con snapshot dati documento e riferimento visitatore.

### 3.2 Privacy + firma
1. Se non esiste una visita corrente, la pagina privacy blocca il flusso e rimanda al check-in.
2. Se la visita esiste, mostra informativa IT/EN + avvertenze.
3. Salva consenso privacy e firma (base64) sulla visita.

### 3.3 Assegnazione badge e ingresso (check-in operativo)
1. Scansione QR badge.
2. Verifica badge su `x_badge`:
   - esiste,
   - attivo,
   - libero (nessuna visita corrente).
3. Aggiorna badge collegandolo alla visita corrente.
4. Aggiorna visita con badge, timestamp ingresso, stato `checked_in`.

### 3.4 Uscita (check-out)
1. Scansione badge in pagina checkout.
2. Ricerca della visita corrente dal badge.
3. Aggiorna visita con stato `checked_out` e timestamp uscita.
4. Libera badge (`visita_corrente = false/null`).

---

## 4) Mappatura tecnica campi usati dall'app

## 4.1 Modello visite (`x_visite`)
- `x_name` (nome record)
- `x_studio_visitatore` (M2O visitatore)
- `x_studio_societa`
- `x_studio_motivo_accesso`
- `x_studio_persona_da_visitare` (host)
- `x_studio_stato_visita` (`draft`, `checked_in`, `checked_out`)
- `x_studio_ingresso` (datetime)
- `x_studio_uscita` (datetime)
- `x_studio_consenso_privacy` (boolean)
- `x_studio_firma` (immagine/base64)
- Snapshot documento:
  - `x_studio_tipo_di_documento_visita`
  - `x_studio_numero_documento_visita`
  - `x_studio_scadenza_documento_visita`
- `x_studio_badge` (M2O badge)

## 4.2 Modello badge (`x_badge`)
- `x_studio_codice_badge`
- `x_studio_attivo`
- `x_studio_visita_corrente` (M2O visita)

## 4.3 Modello visitatori (`x_visitatori`)
- `x_studio_nome`
- `x_studio_cognome`
- `x_studio_tipo_di_documento`
- `x_studio_numero_documento`
- `x_studio_chiave_documento`
- `x_studio_scadenza_documento`
- `x_studio_societa`
- `x_studio_titolo`
- `x_name` (nome record generato)

---

## 5) Regole applicative dedotte dal codice

### 5.1 Dedup visitatori
L'app genera una chiave documento normalizzata (`TIPO|NUMERO_NORMALIZZATO`) e usa una strategia in 3 passi:
1. ricerca per chiave documento;
2. fallback su nome+cognome;
3. creazione nuovo visitatore.

### 5.2 Stato visita
Macchina stati implicita nel codice app:
- creazione: `draft`
- dopo assegnazione badge: `checked_in`
- checkout: `checked_out`

### 5.3 Vincoli badge
- badge non trovato => errore;
- badge non attivo => errore;
- badge già assegnato => errore;
- checkout consentito solo se badge con visita corrente valida.

### 5.4 Host
L'app prova a risolvere `hostName` verso ID dipendente (lookup su `hr.employee` per nome) prima della create visita.

---

## 6) Dati sensibili e rischi
Nel codice è presente configurazione Odoo con URL, DB e credenziali statiche in `AppConfig`. Questo implica:
- esposizione segreti nel client;
- necessità di migrazione a gestione sicura (es. backend proxy + secret storage).

---

## 7) Cosa fornire da Odoo per completare l'allineamento
Allega a questo documento un export con:
1. `ir.model`/`ir.model.fields` dei modelli coinvolti (`x_visite`, `x_visitatori`, `x_badge`, `hr.employee` lato host);
2. selection values reali dei campi stato/tipo documento;
3. viste form/tree/search con eventuali campi obbligatori;
4. record rules + ACL (`ir.rule`, `ir.model.access`);
5. automazioni (`base.automation`, server actions) che modificano gli stessi campi;
6. eventuali constraint SQL/python che impattano create/write.

---

## 8) Prompt operativo consigliato per ChatGPT (con export Odoo allegato)

"Analizza il seguente documento tecnico app Flutter e l'export Odoo allegato.
Obiettivi:
1) verifica corrispondenza campi/modelli/selection;
2) evidenzia mismatch bloccanti o potenziali bug di integrazione;
3) proponi una matrice di compatibilità (OK/Warning/Error) per ogni campo usato dall'app;
4) suggerisci piano di remediation in passi incrementali senza downtime operativo.
Non inventare campi o logiche: usa solo i dati presenti nei file allegati."
