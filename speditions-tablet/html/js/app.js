/* =========================================================
   Speditions-Tablet - NUI Frontend
   ========================================================= */

const State = {
    employee: null,
    role: null,
    config: null,
    currentView: null,
    currentScreen: null,
    currentCategory: null,
};

// ---------------------------------------------------------
// RPC-Layer
// ---------------------------------------------------------

function getResourceName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'speditions-tablet';
}

function rpc(action, payload) {
    return fetch(`https://${getResourceName()}/rpc`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, payload: payload || {} }),
    }).then((r) => r.json()).catch(() => ({ ok: false, error: 'connection_error' }));
}

function nuiPost(name, payload) {
    return fetch(`https://${getResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
}

// call() zeigt bei einem Fehler bewusst schon einen Toast und wirft danach,
// damit der aufrufende Code nicht weiterläuft - das erzeugt aber eine
// "Uncaught (in promise)"-Meldung in der Konsole, obwohl der Fehler dem
// Nutzer bereits angezeigt wurde. Da unterdrücken wir hier gezielt.
window.addEventListener('unhandledrejection', (event) => {
    event.preventDefault();
});

const ERROR_MESSAGES = {
    not_logged_in: 'Du bist nicht angemeldet.',
    invalid_credentials: 'Name oder Passwort falsch.',
    employee_already_exists: 'Dieser Name ist bereits vergeben.',
    employee_not_found: 'Mitarbeiter nicht gefunden.',
    already_clocked_in: 'Du bist bereits eingestempelt.',
    not_clocked_in: 'Du bist nicht eingestempelt.',
    nothing_to_pay: 'Für diesen Mitarbeiter steht aktuell kein Gehalt aus.',
    employee_not_online: 'Dieser Mitarbeiter ist gerade nicht online/am Tablet eingeloggt - Gehalt kann nur als echtes Bargeld an den anwesenden Charakter ausgezahlt werden.',
    dispatcher_available: 'Ein Disponent ist gerade online - Aufträge werden von ihm zugewiesen.',
    driver_not_online: 'Dieser Fahrer ist gerade nicht online.',
    insufficient_player_cash: 'Du hast nicht genug Bargeld dabei, um diesen Betrag einzuzahlen.',
    employee_inactive: 'Dieses Mitarbeiterkonto ist deaktiviert.',
    forbidden_role: 'Keine Berechtigung für diese Aktion.',
    missing_permission: 'Keine Berechtigung für diese Aktion.',
    insufficient_balance: 'Nicht genügend Guthaben für diese Auszahlung.',
    invalid_amount: 'Ungültiger Betrag.',
    missing_reason: 'Bitte einen Grund angeben.',
    missing_fields: 'Bitte alle Pflichtfelder ausfüllen.',
    plate_taken: 'Dieses Kennzeichen ist bereits vergeben.',
    vehicle_not_found: 'Fahrzeug nicht gefunden.',
    vehicle_unavailable: 'Dieses Fahrzeug ist gerade nicht verfügbar - evtl. hat es sich in der Zwischenzeit ein anderer Fahrer genommen. Bitte Auswahl neu öffnen.',
    vehicle_archived: 'Fahrzeug ist archiviert.',
    trailer_not_found: 'Anhänger nicht gefunden.',
    trailer_unavailable: 'Dieser Anhänger ist gerade nicht verfügbar - evtl. hat ihn sich in der Zwischenzeit ein anderer Fahrer genommen. Bitte Auswahl neu öffnen.',
    missing_trailer_or_workshop: 'Bitte entweder einen Anhänger auswählen oder Werkstattfahrt (kein Anhänger) wählen.',
    driver_not_found: 'Fahrer nicht gefunden.',
    order_not_found: 'Auftrag nicht gefunden.',
    order_not_open: 'Auftrag ist nicht mehr offen.',
    order_not_pending: 'Auftrag befindet sich nicht im richtigen Status.',
    order_not_in_transit: 'Auftrag ist nicht unterwegs.',
    order_not_reassignable: 'Auftrag kann nicht neu zugewiesen werden.',
    order_not_cancellable: 'Auftrag kann in diesem Status nicht abgebrochen werden.',
    order_not_active: 'Für diesen Auftrag kann aktuell keine Markierung gesetzt werden.',
    player_not_found: 'Deine Position konnte nicht ermittelt werden - bitte erneut versuchen.',
    cancel_already_requested: 'Für diesen Auftrag läuft bereits eine Abbruch-Anfrage.',
    cancel_request_not_found: 'Abbruch-Anfrage nicht gefunden.',
    cancel_request_already_resolved: 'Diese Abbruch-Anfrage wurde bereits bearbeitet.',
    shift_not_started: 'Du musst zuerst deine Fahrerkarte einstecken (Reiter Fahrerkarte, Fahrt starten), bevor du einen Auftrag annehmen kannst.',
    shift_update_failed: 'Fahrerkarte konnte nicht gespeichert werden - fehlen evtl. die Spalten on_shift/shift_started_at in st_drivers (sql/install.sql aktuell?)?',
    no_cargo_route_available: 'Aktuell gibt es keine passende Fracht-/Standortkombination für einen neuen Auftrag.',
    order_already_closed: 'Auftrag ist bereits abgeschlossen.',
    not_your_order: 'Das ist nicht dein Auftrag.',
    driver_missing_permission: 'Dieser Fahrer besitzt nicht die für den Auftrag erforderliche Berechtigung (z.B. Gefahrgut).',
    last_management_account: 'Es muss mindestens eine aktive Geschäftsführung geben.',
    invalid_status_transition: 'Ungültiger Statuswechsel.',
    invalid_status: 'Ungültiger Status.',
    invalid_role: 'Ungültige Rolle.',
    invalid_permission: 'Ungültige Berechtigung.',
    role_not_found: 'Rolle nicht gefunden.',
    role_is_builtin: 'Die drei mitgelieferten Basisrollen können nicht gelöscht werden.',
    role_in_use: 'Dieser Rolle sind noch Mitarbeiter zugeordnet - erst umverteilen, dann löschen.',
    missing_permissions: 'Bitte mindestens eine Berechtigung auswählen.',
    last_roles_manage_role: 'Diese Rolle ist die letzte mit der Berechtigung "Rollen & Berechtigungen verwalten", der noch Mitarbeiter zugeordnet sind - das würde die Geschäftsführung aussperren.',
    unknown_action: 'Unbekannte Aktion.',
    connection_error: 'Keine Verbindung zum Server.',
    server_error: 'Serverfehler. Bitte später erneut versuchen.',
};

function translateError(code) {
    // Server hängt bei vehicle_missing_trailer das benötigte Anhänger-Label
    // per ":" an den Fehlercode an (siehe server/sv_orders.lua), damit hier
    // steht, WELCHER Anhänger gebraucht wird, statt nur des rohen Codes.
    if (typeof code === 'string' && code.startsWith('vehicle_missing_trailer:')) {
        const needed = code.slice('vehicle_missing_trailer:'.length);
        return `Am Fahrzeug hängt kein passender Anhänger - benötigt wird: ${needed}.`;
    }
    return ERROR_MESSAGES[code] || code || 'Unbekannter Fehler';
}

async function call(action, payload) {
    const res = await rpc(action, payload);
    if (!res || !res.ok) {
        toast('Fehler', translateError(res && res.error), 'error');
        throw new Error((res && res.error) || 'error');
    }
    return res.result;
}

// ---------------------------------------------------------
// Helpers
// ---------------------------------------------------------

function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function formatMoney(n) {
    const val = Math.round(Number(n) || 0);
    return '$' + val.toLocaleString('de-DE');
}

function formatDate(s, withTime) {
    if (!s) return '-';
    // DATETIME-Spalten kommen je nach oxmysql-Version/Treiber entweder als
    // "YYYY-MM-DD HH:MM:SS"-String ODER als roher Unix-Zeitstempel (ms) an -
    // beide Fälle abdecken, statt nur den String-Fall.
    const isRawTimestamp = typeof s === 'number' || /^\d+$/.test(String(s));
    const d = isRawTimestamp ? new Date(Number(s)) : new Date(String(s).replace(' ', 'T'));
    if (isNaN(d.getTime())) return String(s);
    const date = d.toLocaleDateString('de-DE');
    if (!withTime) return date;
    const time = d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    return `${date} ${time}`;
}

const VEHICLE_STATUS_META = {
    verfuegbar: { label: 'Verfügbar', dot: 'green' },
    im_einsatz: { label: 'Im Einsatz', dot: 'blue' },
    wartung: { label: 'Wartung', dot: 'yellow' },
    defekt: { label: 'Defekt', dot: 'red' },
    ausser_betrieb: { label: 'Außer Betrieb', dot: 'gray' },
};

const DRIVER_STATUS_META = {
    offline: { label: 'Offline', dot: 'gray' },
    verfuegbar: { label: 'Verfügbar', dot: 'green' },
    im_einsatz: { label: 'Im Einsatz', dot: 'blue' },
    pause: { label: 'Pause', dot: 'yellow' },
};

const ORDER_STATUS_META = {
    offen: { label: 'Offen', dot: 'gray' },
    disponiert: { label: 'Disponiert', dot: 'yellow' },
    angenommen: { label: 'Angenommen', dot: 'blue' },
    anfahrt: { label: 'Anfahrt zum Beladepunkt', dot: 'blue' },
    beladen: { label: 'Beladen, unterwegs zum Ziel', dot: 'blue' },
    entladen: { label: 'Wird entladen', dot: 'blue' },
    unterwegs: { label: 'Unterwegs', dot: 'blue' },
    abgeschlossen: { label: 'Abgeschlossen', dot: 'green' },
    abgebrochen: { label: 'Abgebrochen', dot: 'red' },
    abgelehnt: { label: 'Abgelehnt', dot: 'red' },
};

const EMPLOYMENT_STATUS_META = {
    aktiv: { label: 'Aktiv', dot: 'green' },
    inaktiv: { label: 'Inaktiv', dot: 'gray' },
};

// Die 9 festen Rollen der Speditions-Website (src/lib/roles.ts dort) - nur
// für die Website-Sync-Rollenzuordnung im Reiter "Rollen" (Config.Website).
const WEBSITE_ROLE_LABELS = {
    geschaeftsfuehrung: 'Geschäftsführer',
    prokurist: 'Prokurist',
    betriebsleiter: 'Betriebsleiter',
    chefdisponent: 'Chefdisponent',
    disponent: 'Disponent',
    lager: 'Lager',
    fuhrpark: 'Fuhrpark & Werkstatt',
    buchhaltung: 'Buchhaltung',
    fahrer: 'Fahrer',
};

function badge(meta) {
    if (!meta) return '-';
    return `<span class="pill"><span class="dot dot-${meta.dot}"></span>${meta.label}</span>`;
}

function hoursMeter(label, minutes, maxMinutes, extraHint) {
    const pct = Math.min(100, Math.round((minutes / maxMinutes) * 100));
    const cls = pct >= 100 ? 'over' : pct >= 80 ? 'warn' : '';
    return `<div class="meter-row">
        <div class="meter-label"><span>${label}</span><b>${minutes} / ${maxMinutes} min</b></div>
        <div class="meter-track"><span class="meter-fill ${cls}" style="width:${pct}%;"></span></div>
        ${extraHint ? `<div class="card-hint" style="margin-top:4px;">${extraHint}</div>` : ''}
    </div>`;
}

function renderHoursBlock(hours) {
    if (!hours) return '<div class="card-hint">Keine Daten.</div>';
    const restHint = hours.resting ? `Pause läuft seit ${formatDate(hours.restingSince, true)} (mind. ${hours.requiredBreakMinutes} Min. nötig, um die Lenkzeit zurückzusetzen)` : '';
    return `${hoursMeter('Ununterbrochene Lenkzeit', hours.continuousMinutes, hours.maxContinuousMinutes, restHint)}${hoursMeter('Lenkzeit heute', hours.dailyMinutes, hours.maxDailyMinutes)}`;
}

function table(headers, rowsHtml) {
    const body = rowsHtml.length
        ? rowsHtml.join('')
        : `<tr class="empty-row"><td colspan="${headers.length}">Keine Einträge vorhanden.</td></tr>`;
    return `<div class="scroll-x"><table><thead><tr>${headers.map((h) => `<th>${h}</th>`).join('')}</tr></thead><tbody>${body}</tbody></table></div>`;
}

// Checkbox-Liste aller Berechtigungen (gruppiert nach Config.Permissions'
// `group`-Feld) für die Rollen-Anlegen-/Bearbeiten-Modals.
function permissionCheckboxesHtml(catalog, selectedKeys) {
    const groups = {};
    catalog.forEach((p) => {
        const g = p.group || 'Sonstiges';
        (groups[g] = groups[g] || []).push(p);
    });
    return Object.keys(groups).map((g) => `
        <div style="margin-top:10px;">
            <div style="font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:var(--text-2);margin-bottom:4px;">${escapeHtml(g)}</div>
            ${groups[g].map((p) => `
                <label style="display:flex;align-items:center;gap:8px;font-size:13px;color:var(--text-0);margin:6px 0;">
                    <input type="checkbox" class="role-perm-checkbox" value="${p.key}" style="width:auto;" ${selectedKeys.includes(p.key) ? 'checked' : ''} />
                    ${escapeHtml(p.label)}
                </label>`).join('')}
        </div>`).join('');
}

// ---------------------------------------------------------
// Toasts
// ---------------------------------------------------------

function toast(title, msg, type) {
    const stack = document.getElementById('toast-stack');
    const el = document.createElement('div');
    el.className = `toast ${type || ''}`;
    el.innerHTML = `<div class="toast-title">${escapeHtml(title)}</div><div class="toast-msg">${escapeHtml(msg || '')}</div>`;
    stack.appendChild(el);
    setTimeout(() => el.remove(), 5000);
}

// ---------------------------------------------------------
// Modal
// ---------------------------------------------------------

function openModal(title, subtitle, bodyHtml, actionsHtml) {
    const root = document.getElementById('modal-root');
    root.innerHTML = `<div class="modal-box">
        <div class="modal-title">${title}</div>
        ${subtitle ? `<div class="modal-subtitle">${subtitle}</div>` : ''}
        <div class="modal-body">${bodyHtml}</div>
        <div class="modal-actions">${actionsHtml}</div>
    </div>`;
    root.classList.remove('hidden');
}

function closeModal() {
    const root = document.getElementById('modal-root');
    root.classList.add('hidden');
    root.innerHTML = '';
}

document.getElementById('modal-root').addEventListener('click', (e) => {
    if (e.target.id === 'modal-root') closeModal();
});

function modalInputValue(id) {
    const el = document.getElementById(id);
    return el ? el.value : '';
}

// Ersetzt das native window.confirm() - in der FiveM-NUI (CEF) friert ein
// synchroner JS-Dialog (confirm/alert/prompt) das GESAMTE Spiel ein, weil
// der Renderprozess auf eine Antwort wartet, die das Spiel nie zustellen
// kann (kein natives Handling für JS-Dialoge). actionCall ist ein fertiger
// JS-Aufruf als String (z.B. "Actions.reallyDeleteTrailer(5)"), analog zu
// den bereits vorhandenen onclick-Handlern mit Template-Literals.
function openConfirmModal(title, message, confirmLabel, actionCall) {
    openModal(title, '', `<p style="font-size:13px;color:var(--text-1);">${escapeHtml(message)}</p>`, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-danger" onclick="${actionCall}">${escapeHtml(confirmLabel)}</button>
    `);
}

// ---------------------------------------------------------
// Navigation
// ---------------------------------------------------------

// Welche Apps sichtbar sind, hängt NICHT von der Rolle selbst ab, sondern
// von deren Berechtigungen (server/sv_roles.lua) - so tauchen auch von der
// Geschäftsführung frei angelegte Rollen mit den passenden Berechtigungen
// automatisch mit den richtigen Apps auf. Jede App gehört zusätzlich zu
// genau einer Kategorie (Homescreen-Ordner).
const CATEGORIES = [
    { id: 'auftraege', label: 'Aufträge', icon: 'truck' },
    { id: 'finanzen', label: 'Finanzen', icon: 'cash' },
    { id: 'fuhrpark', label: 'Fuhrpark', icon: 'garage' },
    { id: 'mitarbeiter', label: 'Mitarbeiterverwaltung', icon: 'people' },
    { id: 'disposition', label: 'Disposition', icon: 'radio' },
    { id: 'geschaeftsfuehrung', label: 'Geschäftsführung', icon: 'briefcase' },
];

// Mehrere frühere Einzel-Apps sind zu je einer App mit rechter Sektionen-
// Leiste zusammengelegt (renderSectionedApp), damit nicht jede Kleinigkeit
// eine eigene Kachel braucht - siehe VIEWS['driver-orders']/['dispatch-
// orders']/['gf-finance-hub']/['gf-fleet-hub']/['gf-employees']. `perm` ist
// entweder eine einzelne Berechtigung oder (bei zusammengelegten Apps mit
// unterschiedlich berechtigten Sektionen) ein Array - sichtbar, wenn
// mindestens eine davon vorhanden ist (siehe appHasPermission()).
// Fahrerkarte und Dispositions-Dienst liegen NICHT hier, sondern als
// Dock-Icons auf dem Home-Screen (s. DOCK_ITEMS/renderDock()).
const APPS = [
    // Aufträge
    { id: 'driver-orders', label: 'Meine Aufträge', perm: 'driver_actions', category: 'auftraege', icon: 'list' },
    { id: 'gf-cargo-types', label: 'Frachtarten', perm: 'cargo_types_manage', category: 'auftraege', icon: 'box' },
    { id: 'gf-orders', label: 'Auftragsstatistik', perm: 'stats_view', category: 'auftraege', icon: 'chart' },
    // Finanzen
    { id: 'driver-earnings', label: 'Meine Einnahmen', perm: 'driver_actions', category: 'finanzen', icon: 'wallet' },
    { id: 'gf-finance-hub', label: 'Finanzcenter', perm: ['dispatch', 'stats_view', 'finance_view', 'wages_manage', 'finance_payout'], category: 'finanzen', icon: 'wallet' },
    // Fuhrpark (Fahrerkarte liegt als Dock-Icon auf dem Home-Screen, s.
    // renderDock() - nicht mehr hier in der Kategorie)
    { id: 'driver-vehicle', label: 'Mein Fahrzeug', perm: 'driver_actions', category: 'fuhrpark', icon: 'car' },
    { id: 'gf-fleet-hub', label: 'Fuhrpark-Verwaltung', perm: 'fleet_manage', category: 'fuhrpark', icon: 'garage' },
    // Mitarbeiterverwaltung
    { id: 'gf-employees', label: 'Mitarbeiter', perm: ['employees_manage', 'roles_manage'], category: 'mitarbeiter', icon: 'idcard' },
    { id: 'dispatch-drivers', label: 'Fahrerübersicht', perm: 'dispatch', category: 'mitarbeiter', icon: 'people' },
    // Disposition - Auftragsverwaltung liegt bewusst HIER (nicht unter
    // "Aufträge"), damit Disponenten für ihren gesamten Arbeitsalltag
    // (Aufträge disponieren, Nachrichten, Live-Karte) nicht zwischen
    // Kategorien wechseln müssen.
    { id: 'dispatch-orders', label: 'Auftragsverwaltung', perm: 'dispatch', category: 'disposition', icon: 'clipboard' },
    { id: 'driver-messages', label: 'Nachrichten', perm: 'driver_actions', category: 'disposition', icon: 'chat' },
    { id: 'dispatch-map', label: 'Live Karte', perm: 'live_map_view', category: 'disposition', icon: 'pin' },
    // Geschäftsführung
    { id: 'gf-locations', label: 'Orte', perm: 'locations_manage', category: 'geschaeftsfuehrung', icon: 'pin' },
    { id: 'gf-log', label: 'Protokoll', perm: 'activity_log_view', category: 'geschaeftsfuehrung', icon: 'clipboard' },
    { id: 'gf-console', label: 'Konsole', perm: 'console_view', category: 'geschaeftsfuehrung', icon: 'terminal' },
];

// Kleines, selbst gezeichnetes Icon-Set (kein Emoji, keine externen
// Schriften/CDN-Requests) für die Kategorie-Kacheln auf dem Homescreen.
const CATEGORY_ICON_PATHS = {
    truck: '<path d="M3 7h11v9H3z"/><path d="M14 10h4l3 3v3h-7z"/><circle cx="7" cy="18" r="1.6"/><circle cx="17" cy="18" r="1.6"/>',
    cash: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="3"/>',
    garage: '<path d="M4 11 12 4l8 7"/><path d="M5 11v8h14v-8"/><path d="M9 19v-5h6v5"/>',
    people: '<circle cx="9" cy="8" r="3"/><path d="M3 19c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.4"/><path d="M15.5 13.2c2.5.3 4.5 2.4 4.5 5.3"/>',
    radio: '<circle cx="12" cy="17" r="1.6"/><path d="M8.5 13.5a5 5 0 0 1 7 0"/><path d="M5.8 10.8a9 9 0 0 1 12.4 0"/><path d="M3.2 8a13 13 0 0 1 17.6 0"/>',
    briefcase: '<rect x="3" y="8" width="18" height="11" rx="2"/><path d="M9 8V6a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/>',
};

function categoryIconSvg(key) {
    const inner = CATEGORY_ICON_PATHS[key] || CATEGORY_ICON_PATHS.briefcase;
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${inner}</svg>`;
}

// Zusätzliches Icon-Set für einzelne App-Kacheln (statt des früheren
// Buchstaben-Platzhalters) - fällt auf das Kategorie-Icon zurück, wenn eine
// App keinen eigenen Schlüssel hat oder dieser unbekannt ist.
const APP_ICON_PATHS = {
    list: '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><circle cx="3.5" cy="6" r="1.4"/><circle cx="3.5" cy="12" r="1.4"/><circle cx="3.5" cy="18" r="1.4"/>',
    chart: '<path d="M4 20V10"/><path d="M11 20V4"/><path d="M18 20v-7"/><path d="M3 20h18"/>',
    wallet: '<path d="M3 7a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M16 12h3"/>',
    idcard: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6 16c0-1.7 1.3-3 3-3s3 1.3 3 3"/><path d="M14 10h4"/><path d="M14 14h4"/>',
    car: '<path d="M4 16V11l2-5h12l2 5v5"/><path d="M4 16h16"/><circle cx="7.5" cy="17.5" r="1.6"/><circle cx="16.5" cy="17.5" r="1.6"/>',
    chat: '<path d="M4 5h16v10H8l-4 4Z"/>',
    pin: '<path d="M12 21s7-6.1 7-11a7 7 0 1 0-14 0c0 4.9 7 11 7 11Z"/><circle cx="12" cy="10" r="2.4"/>',
    clipboard: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1"/><path d="M9 11h6"/><path d="M9 15h6"/>',
    terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3"/><path d="M12 15h5"/>',
    box: '<path d="m3 8 9-5 9 5-9 5-9-5Z"/><path d="M3 8v8l9 5 9-5V8"/><path d="M12 13v8"/>',
    // Handfunkgerät (Antenne, Gehäuse, Lautsprecher, Grill) - bewusst anders
    // als das "radio"-Icon (Funkwellen-Bögen, Kategorie "Disposition"/Dock-
    // Icon "Dispositions-Dienst"), damit beide Dock-Icons unterscheidbar sind.
    walkie: '<path d="M9 3v3"/><rect x="7" y="6" width="10" height="15" rx="2"/><circle cx="12" cy="10.5" r="1.3"/><path d="M9.5 14.5h5"/><path d="M9.5 17.5h5"/>',
};

function iconSvg(key) {
    const inner = APP_ICON_PATHS[key] || CATEGORY_ICON_PATHS[key] || CATEGORY_ICON_PATHS.briefcase;
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${inner}</svg>`;
}

function appHasPermission(item, perms) {
    if (!item.perm) return true; // kein perm-Feld = für jeden angemeldeten Mitarbeiter sichtbar (z.B. Funk)
    return Array.isArray(item.perm) ? item.perm.some((p) => perms.includes(p)) : perms.includes(item.perm);
}

function visibleApps(permissions) {
    const perms = permissions || [];
    return APPS.filter((item) => appHasPermission(item, perms));
}

function appsInCategory(categoryId, permissions) {
    return visibleApps(permissions).filter((item) => item.category === categoryId);
}

function visibleCategories(permissions) {
    return CATEGORIES.filter((c) => appsInCategory(c.id, permissions).length > 0);
}

function currentPermissions() {
    return (State.config && State.config.permissions) || [];
}

function renderHome() {
    State.currentScreen = 'home';
    State.currentCategory = null;
    document.getElementById('home-grid').classList.remove('hidden');
    document.getElementById('category-grid').classList.add('hidden');
    document.getElementById('app-view').classList.add('hidden');
    const grid = document.getElementById('home-grid');
    // Große Uhrzeit/Datum oben links (iPadOS-Homescreen-Optik) - über eine
    // .home-tiles-Kachelfläche statt direkt im .home-grid-Scrollcontainer,
    // damit sie nicht Teil des Grids ist. startClock() hält beide Felder
    // aktuell, solange das Tablet offen ist.
    grid.innerHTML = `
        <div class="home-clock">
            <div class="home-clock-time" id="home-clock-time"></div>
            <div class="home-clock-date" id="home-clock-date"></div>
        </div>
        <div class="home-widgets" id="home-widgets"></div>
        <div class="home-widget-right">
            <div id="home-widget-drivercard"></div>
            <div id="home-widget-vehicle"></div>
        </div>
        <div class="home-tiles">
            ${visibleCategories(currentPermissions()).map((c) => `
                <div class="category-tile" onclick="showCategory('${c.id}')">
                    <div class="tile-icon cat-${c.id}">${categoryIconSvg(c.icon)}</div>
                    <div class="tile-label">${escapeHtml(c.label)}</div>
                </div>
            `).join('')}
        </div>`;
    updateClockElements();
    renderDock();
    renderHomeWidgets();
    renderDriverCardWidget();
    renderVehicleWidget();
}

// Homescreen-Widget "Aktueller Auftrag" (Fahrer) - bewusst knapp gehalten
// (Fracht, Strecke, Status), damit der Inhalt in die feste Widget-Größe
// passt, statt zu überlaufen. Tippen öffnet die volle App "Meine Aufträge".
// Best-effort wie der Dock-Status: rohes rpc() statt call(), damit ein
// Fehler hier keinen Fehler-Toast auf dem Homescreen auslöst.
const ACTIVE_ORDER_STATUSES = ['angenommen', 'anfahrt', 'beladen', 'entladen'];

async function renderHomeWidgets() {
    const el = document.getElementById('home-widgets');
    if (!el) return;
    if (!currentPermissions().includes('driver_actions')) {
        el.innerHTML = '';
        return;
    }
    el.innerHTML = `
        <div class="widget" onclick="showView('driver-orders')">
            <div class="widget-header">${iconSvg('list')}<span>Aktueller Auftrag</span></div>
            <div id="widget-order-body"><div class="widget-empty">Lädt…</div></div>
        </div>`;

    const res = await rpc('driver:myOrders');
    const body = document.getElementById('widget-order-body');
    if (!body) return; // Homescreen inzwischen verlassen
    if (!res || !res.ok) {
        body.innerHTML = '<div class="widget-empty">Keine Daten verfügbar.</div>';
        return;
    }
    const active = (res.result.orders || []).find((o) => ACTIVE_ORDER_STATUSES.includes(o.status));
    if (!active) {
        body.innerHTML = '<div class="widget-empty">Kein aktiver Auftrag.</div>';
        return;
    }
    const meta = ORDER_STATUS_META[active.status];
    body.innerHTML = `
        <div class="widget-title">${escapeHtml(active.cargo)}</div>
        <div class="widget-sub">${escapeHtml(active.start_location)} → ${escapeHtml(active.end_location)}</div>
        <div class="widget-status"><span class="dot dot-${meta ? meta.dot : 'gray'}"></span>${escapeHtml(meta ? meta.label : active.status)}</div>`;
}

// Zweites Homescreen-Widget (Fahrerkarte), rechts auf dem Startbildschirm -
// zeigt knapp, ob die Fahrerkarte gerade eingesteckt ist, ohne dass man
// dafür erst die App öffnen muss. Tippen öffnet die volle Fahrerkarte.
async function renderDriverCardWidget() {
    const el = document.getElementById('home-widget-drivercard');
    if (!el) return;
    if (!currentPermissions().includes('driver_actions')) {
        el.innerHTML = '';
        return;
    }
    el.innerHTML = `
        <div class="widget" onclick="showView('driver-card')">
            <div class="widget-header">${iconSvg('idcard')}<span>Fahrerkarte</span></div>
            <div id="widget-drivercard-body"><div class="widget-empty">Lädt…</div></div>
        </div>`;

    const res = await rpc('driver:card');
    const body = document.getElementById('widget-drivercard-body');
    if (!body) return; // Homescreen inzwischen verlassen
    if (!res || !res.ok) {
        body.innerHTML = '<div class="widget-empty">Keine Daten verfügbar.</div>';
        return;
    }
    const driver = res.result.driver;
    body.innerHTML = driver && driver.onShift
        ? `<div class="widget-title">Eingesteckt</div>
           <div class="widget-sub">Seit ${formatDate(driver.shiftStartedAt, true)}</div>
           <div class="widget-status"><span class="dot dot-green"></span>Fahrt läuft</div>`
        : `<div class="widget-title">Nicht eingesteckt</div>
           <div class="widget-status"><span class="dot dot-gray"></span>Fahrerkarte einstecken, um Aufträge anzunehmen</div>`;
}

// Drittes Homescreen-Widget (Mein Fahrzeug), direkt unter dem Fahrerkarte-
// Widget - zeigt das aktuell zugewiesene Firmenfahrzeug knapp zusammengefasst
// (Name/Modell, Kennzeichen, Status, Tank). Tippen öffnet "Mein Fahrzeug".
async function renderVehicleWidget() {
    const el = document.getElementById('home-widget-vehicle');
    if (!el) return;
    if (!currentPermissions().includes('driver_actions')) {
        el.innerHTML = '';
        return;
    }
    el.innerHTML = `
        <div class="widget" onclick="showView('driver-vehicle')">
            <div class="widget-header">${iconSvg('car')}<span>Mein Fahrzeug</span></div>
            <div id="widget-vehicle-body"><div class="widget-empty">Lädt…</div></div>
        </div>`;

    const res = await rpc('driver:vehicle');
    const body = document.getElementById('widget-vehicle-body');
    if (!body) return; // Homescreen inzwischen verlassen
    if (!res || !res.ok) {
        body.innerHTML = '<div class="widget-empty">Keine Daten verfügbar.</div>';
        return;
    }
    const v = res.result.vehicle;
    if (!v) {
        body.innerHTML = '<div class="widget-empty">Kein Fahrzeug zugewiesen.</div>';
        return;
    }
    const meta = VEHICLE_STATUS_META[v.status];
    body.innerHTML = `
        <div class="widget-title">${escapeHtml(v.name)}</div>
        <div class="widget-sub">${escapeHtml(v.model)} · ${escapeHtml(v.plate)}</div>
        <div class="widget-status"><span class="dot dot-${meta ? meta.dot : 'gray'}"></span>${escapeHtml(meta ? meta.label : v.status)} · Tank ${v.fuel}%</div>`;
}

// Dock (fixiert unten auf dem Home-Screen, analog iPad) - Fahrerkarte,
// Dispositions-Dienst und Funk liegen bewusst hier statt in einer Kategorie:
// alle drei sind ein "aktueller Zustand, den man ständig im Blick haben
// will"-Schalter, kein eigentlicher Arbeitsbereich. Sichtbar je nach
// Berechtigung (kein `perm` = für jeden angemeldeten Mitarbeiter, s.
// appHasPermission()) - Fahrerkarte/Dienst zeigen einen Status-Punkt (im
// Dienst/eingesteckt = grün), Funk stattdessen den aktuell eingestellten
// Kanal als Badge (rein clientseitig, s. currentRadioChannel/cl_radio.lua).
const DOCK_ITEMS = [
    { id: 'driver-card', label: 'Fahrerkarte', perm: 'driver_actions', icon: 'idcard', statusRpc: 'driver:card', statusPath: (r) => r && r.driver && r.driver.onShift },
    { id: 'dispatch-duty', label: 'Dispositions-Dienst', perm: 'dispatch', icon: 'radio', statusRpc: 'dispatch:dutyStatus', statusPath: (r) => r && r.onDuty },
    { id: 'funk', label: 'Funk', perm: null, icon: 'walkie', badge: true },
];

function renderDock() {
    const perms = currentPermissions();
    const items = DOCK_ITEMS.filter((it) => !it.perm || perms.includes(it.perm));
    const dock = document.getElementById('dock');
    if (!dock) return;
    if (!items.length) {
        dock.classList.add('hidden');
        dock.innerHTML = '';
        return;
    }
    dock.classList.remove('hidden');
    // Icon-only, ohne Beschriftung darunter - wie das echte iPad-Dock (Name
    // steht als Tooltip/Titel zur Verfügung, nicht permanent im Bild).
    dock.innerHTML = items.map((it) => `
        <div class="dock-item" title="${escapeHtml(it.label)}" onclick="showView('${it.id}')">
            <div class="tile-icon">
                ${iconSvg(it.icon)}
                ${it.badge
                    ? `<span class="dock-badge" id="dock-badge-${it.id}"></span>`
                    : `<span class="dock-status-dot" id="dock-status-${it.id}"></span>`}
            </div>
        </div>
    `).join('');
    refreshDockStatus();
    updateRadioDockBadge();
}

// Best-effort - wie refreshTimeclock() bewusst über das rohe rpc() statt
// call(), damit ein Fehler hier keinen Fehler-Toast auf dem Homescreen
// auslöst (reiner Status-Punkt, keine kritische Aktion).
async function refreshDockStatus() {
    for (const it of DOCK_ITEMS) {
        if (!it.statusRpc) continue; // z.B. Funk - Status kommt nicht vom Server, s. updateRadioDockBadge()
        const dot = document.getElementById(`dock-status-${it.id}`);
        if (!dot) continue;
        const res = await rpc(it.statusRpc);
        if (res && res.ok) dot.classList.toggle('on', !!it.statusPath(res.result));
    }
}

// ---------------------------------------------------------
// Funk (Dock-Item + VIEWS['funk']) - bindet an pma-voice an
// (client/cl_radio.lua). Läuft bewusst komplett clientseitig, ohne
// Server-RPC: pma-voice validiert Kanäle bereits selbst serverseitig, und
// beide Seiten starten unabhängig voneinander auf demselben Standardkanal
// (Config.Radio.defaultChannel) - ein Abgleich beim Öffnen des Tablets ist
// daher nicht nötig, solange der Kanal ausschließlich über diese App
// gewechselt wird. currentRadioChannel ist damit die alleinige Quelle der
// Wahrheit für die NUI-Anzeige (Dock-Badge + aktiver Kanal in der App).
function radioChannelRange() {
    const cfg = (State.config && State.config.radioChannels) || {};
    return {
        min: cfg.minChannel || 1000,
        max: cfg.maxChannel || 1009,
        default: cfg.defaultChannel || 1000,
    };
}

// Vorläufig auf 1000 (der ausgelieferte Standardwert) - bis die echte
// Server-Konfiguration da ist, s. syncRadioChannelDefaultOnce(). Danach NIE
// mehr automatisch überschrieben (auch nicht bei erneutem Login/Unlock),
// damit ein bereits gewählter Kanal über mehrere Tablet-Öffnungen hinweg
// erhalten bleibt, statt bei jedem Login auf den Standardkanal
// zurückzuspringen.
let currentRadioChannel = 1000;
let radioChannelDefaultSynced = false;
function syncRadioChannelDefaultOnce() {
    if (radioChannelDefaultSynced) return;
    radioChannelDefaultSynced = true;
    currentRadioChannel = radioChannelRange().default;
}

function updateRadioDockBadge() {
    const badge = document.getElementById('dock-badge-funk');
    if (badge) badge.textContent = String(currentRadioChannel);
}

// VIEWS['funk'] steht weiter unten bei den übrigen VIEW RENDERERS (nach
// `const VIEWS = {};`), nicht hier - sonst TDZ-Fehler beim Scriptstart
// (Zugriff auf VIEWS vor dessen Deklaration).

function showHome() {
    if (activeViewInterval) { clearInterval(activeViewInterval); activeViewInterval = null; }
    State.currentView = null;
    renderHome();
}

// Zurück-Button im App-Topbar - führt zur Kategorie zurück, aus der die App
// geöffnet wurde, oder direkt zum Startbildschirm bei Dock-Apps (Fahrerkarte/
// Dispositions-Dienst), die keiner Kategorie angehören.
function showBackFromApp() {
    if (State.currentCategory) showCategory(State.currentCategory);
    else showHome();
}

function showCategory(catId) {
    if (activeViewInterval) { clearInterval(activeViewInterval); activeViewInterval = null; }
    State.currentScreen = 'category';
    State.currentCategory = catId;
    State.currentView = null;
    document.getElementById('home-grid').classList.add('hidden');
    document.getElementById('app-view').classList.add('hidden');
    document.getElementById('dock').classList.add('hidden');
    const catGrid = document.getElementById('category-grid');
    catGrid.classList.remove('hidden');
    const category = CATEGORIES.find((c) => c.id === catId);
    const apps = appsInCategory(catId, currentPermissions());
    catGrid.innerHTML = `
        <div class="category-header">
            <button class="app-back-btn" onclick="showHome()">&#8249; Startbildschirm</button>
            <span class="category-title">${escapeHtml(category ? category.label : '')}</span>
        </div>
        <div class="app-grid">
            ${apps.map((a) => `
                <div class="app-tile" onclick="showView('${a.id}')">
                    <div class="tile-icon cat-${catId}">${iconSvg(a.icon || (category ? category.icon : 'briefcase'))}</div>
                    <div class="tile-label">${escapeHtml(a.label)}</div>
                </div>
            `).join('')}
        </div>`;
}

// Manche Ansichten können periodisch pollen, solange sie aktiv sind -
// dieses Intervall wird beim Verlassen der Ansicht automatisch gestoppt.
let activeViewInterval = null;

async function showView(id) {
    if (activeViewInterval) { clearInterval(activeViewInterval); activeViewInterval = null; }
    State.currentView = id;
    State.currentScreen = 'app';
    const app = APPS.find((a) => a.id === id);
    // Dock-Apps (Fahrerkarte/Dispositions-Dienst) gehören keiner Kategorie
    // an - Zurück führt bei ihnen über showBackFromApp() zum Startbildschirm.
    State.currentCategory = app ? app.category : null;
    document.getElementById('home-grid').classList.add('hidden');
    document.getElementById('category-grid').classList.add('hidden');
    document.getElementById('dock').classList.add('hidden');
    document.getElementById('app-view').classList.remove('hidden');
    const titleEl = document.getElementById('app-topbar-title');
    const dockItem = DOCK_ITEMS.find((it) => it.id === id);
    if (titleEl) titleEl.textContent = app ? app.label : (dockItem ? dockItem.label : '');
    const content = document.getElementById('content');
    content.innerHTML = '<div class="card-hint">Lädt...</div>';
    try {
        const renderer = VIEWS[id];
        if (renderer) await renderer(content);
    } catch (e) {
        // eslint-disable-next-line no-console
        console.error('[speditions-tablet] Fehler beim Laden der Ansicht', id, e);
    }
}

function refreshIfViewing(ids) {
    if (ids.includes(State.currentView)) showView(State.currentView);
}

// ---------------------------------------------------------
// Boot / Open / Close
// ---------------------------------------------------------

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.type) return;
    if (data.type === 'open') handleOpen(data.companyName);
    else if (data.type === 'close') handleClose();
    else if (data.type === 'push') handlePush(data.event, data.data);
});

document.addEventListener('keydown', (e) => {
    if (!document.getElementById('lock-screen').classList.contains('hidden')) { unlockTablet(); return; }
    if (e.key === 'Escape') requestClose();
});

document.getElementById('lock-screen').addEventListener('click', () => unlockTablet());
document.getElementById('login-submit').addEventListener('click', () => Actions.login());
document.getElementById('login-username').addEventListener('keydown', (e) => { if (e.key === 'Enter') Actions.login(); });
document.getElementById('login-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') Actions.login(); });
document.getElementById('employee-chip').addEventListener('click', () => Actions.openAccountModal());

function requestClose() {
    nuiPost('close', {});
}

async function closeTabletWithVehicleCheck() {
    if (State.config && Array.isArray(State.config.permissions) && State.config.permissions.includes('driver_actions')) {
        const res = await rpc('driver:vehicle');
        if (res && res.ok && res.result && res.result.vehicle) {
            openVehicleConditionModal(res.result.vehicle);
            return;
        }
    }
    requestClose();
}

document.getElementById('close-btn').addEventListener('click', () => closeTabletWithVehicleCheck());

function hideAllScreens() {
    document.getElementById('lock-screen').classList.add('hidden');
    document.getElementById('boot-screen').classList.add('hidden');
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('main-ui').classList.add('hidden');
}

function showLoginScreen() {
    hideAllScreens();
    document.getElementById('login-username').value = '';
    document.getElementById('login-password').value = '';
    document.getElementById('login-error').classList.add('hidden');
    document.getElementById('login-screen').classList.remove('hidden');
    document.getElementById('login-username').focus();
}

function handleOpen(companyName) {
    State.companyName = companyName || 'Speditions-Tablet';
    document.getElementById('lock-company-name').textContent = State.companyName;
    document.getElementById('app').classList.remove('hidden');
    hideAllScreens();
    document.getElementById('lock-screen').classList.remove('hidden');
    startClock();
}

let unlocking = false;
async function unlockTablet() {
    if (unlocking) return;
    unlocking = true;

    hideAllScreens();
    document.getElementById('boot-screen').classList.remove('hidden');
    document.getElementById('boot-logo').textContent = (State.companyName || 'SPEDITIONS-TABLET').toUpperCase();

    const res = await rpc('session:whoami');
    unlocking = false;

    if (res && res.ok && res.result && res.result.loggedIn) {
        const data = res.result;
        State.employee = data.employee;
        State.role = data.employee.role;
        State.config = data;
        syncRadioChannelDefaultOnce();
        boot(data);
    } else {
        showLoginScreen();
    }
}

function openVehicleConditionModal(vehicle) {
    openModal('Fahrzeugzustand melden', `${escapeHtml(vehicle.name)} (${escapeHtml(vehicle.plate)}) - Pflichtangabe vor dem Schließen des Tablets`, `
        <label>Tankstand (%)</label>
        <input id="condition-fuel" type="number" min="0" max="100" value="${vehicle.fuel}" />
        <label>Mängel / Besonderheiten</label>
        <textarea id="condition-notes"></textarea>
        <label style="display:flex;align-items:center;gap:8px;margin-top:12px;">
            <input type="checkbox" id="condition-workshop" style="width:auto;" />
            <span style="font-size:12.5px;color:var(--text-1);">Werkstatt erforderlich (Fahrzeug wird auf "Wartung" gesetzt)</span>
        </label>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.submitVehicleConditionAndClose()">Melden &amp; schließen</button>
    `);
}

function handleClose() {
    document.getElementById('app').classList.add('hidden');
    closeModal();
    if (clockInterval) { clearInterval(clockInterval); clockInterval = null; }
    if (timeclockInterval) { clearInterval(timeclockInterval); timeclockInterval = null; }
}

// Aktualisiert alle Uhrzeit-/Datumsanzeigen im Tablet (Topbar, Lock-Screen,
// die große Homescreen-Uhr im iPadOS-Stil) - einzeln aufrufbar, damit
// renderHome() die große Uhr sofort korrekt zeigt, statt bis zum nächsten
// Intervall-Tick zu warten.
function updateClockElements() {
    const now = new Date();
    const time = now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    const dateLong = now.toLocaleDateString('de-DE', { weekday: 'long', day: '2-digit', month: 'long' });
    const setText = (id, text) => {
        const el = document.getElementById(id);
        if (el) el.textContent = text;
    };
    setText('clock', time);
    setText('lock-time', time);
    setText('lock-date', dateLong);
    setText('home-clock-time', time);
    setText('home-clock-date', dateLong);
}

let clockInterval = null;
function startClock() {
    if (clockInterval) clearInterval(clockInterval);
    updateClockElements();
    clockInterval = setInterval(updateClockElements, 15000);
}

function boot(data) {
    document.getElementById('boot-screen').classList.add('hidden');
    document.getElementById('main-ui').classList.remove('hidden');
    document.getElementById('employee-name').textContent = data.employee.name;
    document.getElementById('employee-role').textContent = data.roleLabels[data.employee.role] || data.employee.role;
    document.getElementById('topbar-brand').textContent = State.companyName;
    showHome();
    startTimeclockWidget();
}

// ---------------------------------------------------------
// Stempeluhr (Topbar-Widget, für jede Rolle sichtbar)
// ---------------------------------------------------------

let timeclockInterval = null;
let timeclockState = null;

function formatHm(totalSeconds) {
    const h = Math.floor(totalSeconds / 3600);
    const m = Math.floor((totalSeconds % 3600) / 60);
    return `${h}:${String(m).padStart(2, '0')} Std.`;
}

async function refreshTimeclock() {
    const res = await rpc('me:payrollStatus');
    if (!res || !res.ok) return;
    timeclockState = res.result;

    const dot = document.getElementById('timeclock-dot');
    const label = document.getElementById('timeclock-label');
    if (!dot || !label) return;

    dot.classList.toggle('on', timeclockState.clockedIn);
    if (timeclockState.clockedIn) {
        label.textContent = 'Eingestempelt';
    } else {
        label.textContent = timeclockState.unpaidSeconds > 0
            ? `Ausgestempelt (${formatHm(timeclockState.unpaidSeconds)} offen)`
            : 'Einstempeln';
    }
}

function startTimeclockWidget() {
    if (timeclockInterval) clearInterval(timeclockInterval);
    refreshTimeclock();
    timeclockInterval = setInterval(refreshTimeclock, 30000);
}

document.getElementById('timeclock-btn').addEventListener('click', async () => {
    if (timeclockState && timeclockState.clockedIn) {
        await call('me:clockOut');
        toast('Ausgestempelt', '', 'success');
    } else {
        await call('me:clockIn');
        toast('Eingestempelt', '', 'success');
    }
    refreshTimeclock();
});

function handlePush(event, data) {
    const map = {
        'notifications:new': () => { toast(data.title, data.message, 'info'); refreshIfViewing(['driver-messages', 'driver-orders']); },
        'orders:newOpenOrder': () => { toast('Neuer Auftrag', 'Ein neuer Auftrag ist im Pool verfügbar.', 'info'); refreshIfViewing(['dispatch-orders']); },
        'orders:activeChanged': () => { refreshIfViewing(['dispatch-orders', 'driver-orders']); if (State.currentScreen === 'home') renderHomeWidgets(); },
        'orders:cancelRequested': () => { toast('Abbruch-Anfrage', 'Ein Fahrer möchte einen Auftrag abbrechen.', 'warning'); refreshIfViewing(['dispatch-orders']); },
        'orders:completed': () => { toast('Auftrag abgeschlossen', 'Ein Auftrag wurde erfolgreich abgeschlossen.', 'success'); refreshIfViewing(['dispatch-orders', 'gf-finance-hub']); if (State.currentScreen === 'home') renderHomeWidgets(); },
        'dispatch:driversChanged': () => refreshIfViewing(['dispatch-drivers']),
        'dispatch:dutyChanged': () => { refreshIfViewing(['dispatch-orders', 'driver-orders', 'dispatch-duty']); if (State.currentScreen === 'home') refreshDockStatus(); },
        'fleet:changed': () => refreshIfViewing(['gf-fleet-hub', 'dispatch-drivers']),
        'finance:balanceChanged': () => refreshIfViewing(['gf-finance-hub']),
        'roles:changed': () => refreshAfterRolesChanged(),
        'cargotypes:changed': () => refreshAfterCargoTypesChanged(),
    };
    if (map[event]) map[event]();
}

// Wird ausgeloest, sobald sich irgendeine Rolle aendert (Berechtigungen,
// Label, neue/geloeschte Rolle) - laedt die eigene Sitzung neu (falls sich
// die eigenen Berechtigungen geaendert haben, z.B. neue Reiter), und
// aktualisiert offene Rollen-/Mitarbeiter-/Gehalts-Ansichten.
async function refreshAfterRolesChanged() {
    const res = await rpc('session:whoami');
    if (res && res.ok && res.result && res.result.loggedIn) {
        const data = res.result;
        State.employee = data.employee;
        State.role = data.employee.role;
        State.config = data;
        syncRadioChannelDefaultOnce();
        document.getElementById('employee-role').textContent = data.roleLabels[data.employee.role] || data.employee.role;
        if (State.currentScreen === 'home') renderHome();
        else if (State.currentScreen === 'category') showCategory(State.currentCategory);
    }
    refreshIfViewing(['gf-employees', 'gf-finance-hub']);
}

// Wird ausgeloest, sobald sich Frachtarten aendern (angelegt/bearbeitet/
// geloescht) - haelt State.config.cargoTypes (Namensliste, u.a. fuer die
// Quelle-/Ziel-Checkboxen im Orte-Formular) aktuell, ohne dass sich jeder
// erst neu einloggen muss.
async function refreshAfterCargoTypesChanged() {
    const res = await rpc('cargotypes:list');
    if (res && res.ok && res.result && State.config) {
        State.config.cargoTypes = res.result.cargoTypes.map((c) => c.name);
    }
    refreshIfViewing(['gf-cargo-types', 'gf-locations']);
}

// =========================================================
// VIEW RENDERERS
// =========================================================

const VIEWS = {};

// ---------------------------------------------------------
// Split-View-Helper (Sektionen-Leiste rechts, iPad-Splitview-Prinzip) -
// für Apps, die mehrere frühere Einzel-Apps zu einem Bereich zusammenlegen
// (z.B. "Auftragsverwaltung", "Finanzcenter"). Jede Sektion bleibt
// permission-gated wie zuvor die jeweilige Einzel-App; der zuletzt aktive
// Tab pro App bleibt gemerkt, damit ein Refresh (refreshIfViewing) nicht
// auf den ersten Tab zurückspringt.
// ---------------------------------------------------------

const sectionedAppActiveKey = {};

async function renderSectionedApp(root, appId, sections) {
    const perms = currentPermissions();
    const visible = sections.filter((s) => !s.perm || perms.includes(s.perm));
    if (!visible.length) {
        root.innerHTML = '<div class="card-hint">Keine Berechtigung für diese App.</div>';
        return;
    }
    if (!visible.some((s) => s.key === sectionedAppActiveKey[appId])) {
        sectionedAppActiveKey[appId] = visible[0].key;
    }

    root.innerHTML = `
        <div class="app-split">
            <div class="app-split-content" id="app-split-content"><div class="card-hint">Lädt...</div></div>
            <div class="app-split-sidebar">
                ${visible.map((s) => `
                    <button class="app-split-tab ${s.key === sectionedAppActiveKey[appId] ? 'active' : ''}" data-section="${s.key}">${escapeHtml(s.label)}</button>
                `).join('')}
            </div>
        </div>`;

    root.querySelectorAll('.app-split-tab').forEach((btn) => {
        btn.addEventListener('click', () => {
            sectionedAppActiveKey[appId] = btn.dataset.section;
            renderSectionedApp(root, appId, sections);
        });
    });

    const active = visible.find((s) => s.key === sectionedAppActiveKey[appId]);
    const content = root.querySelector('#app-split-content');
    await active.render(content);
}

// Springt innerhalb einer zusammengelegten App direkt zu einer bestimmten
// Sektion (z.B. ein Verweis-Button von "Finanzen" zu "Ein-/Auszahlungen").
function jumpToSection(appId, key) {
    sectionedAppActiveKey[appId] = key;
    showView(appId);
}

// ---------- FUNK ----------

VIEWS['funk'] = async (root) => {
    const range = radioChannelRange();
    const channels = [];
    for (let ch = range.min; ch <= range.max; ch++) channels.push(ch);

    root.innerHTML = `
        <h1 class="view-title">Funk</h1>
        <p class="view-subtitle">Aktueller Kanal: <strong id="funk-active-channel">${currentRadioChannel}</strong> - zum Wechseln einfach antippen.</p>
        <div class="funk-grid">
            ${channels.map((ch) => `
                <button class="funk-channel-btn ${ch === currentRadioChannel ? 'active' : ''}" id="funk-ch-${ch}" onclick="Actions.setRadioChannel(${ch})">
                    ${iconSvg('walkie')}
                    <span class="funk-channel-num">${ch}</span>
                </button>
            `).join('')}
        </div>
        <p class="card-hint" style="margin-top:18px;">Sprechen läuft über die normale Funk-Taste von pma-voice, sobald ein Kanal eingestellt ist.</p>`;
};

// ---------- FAHRER ----------

VIEWS['driver-card'] = async (root) => {
    const d = await call('driver:card');
    const emp = d.employee;
    const stats = d.statistics;
    const vehicle = d.vehicle;

    const permsHtml = d.permissions.map((p) => `
        <div class="perm-item ${p.granted ? 'granted' : 'denied'}">
            <span class="mark"></span>${escapeHtml(p.label)}
        </div>`).join('');

    root.innerHTML = `
        <h1 class="view-title">Fahrerkarte</h1>
        <p class="view-subtitle">Deine digitale Personalakte als Fahrer.</p>
        <div class="driver-card">
            <div class="driver-card-head">FAHRERKARTE</div>
            <div class="driver-card-body">
                <div class="driver-card-name">${escapeHtml(emp.name)}</div>
                <div class="driver-card-id">Mitarbeiter-ID: #${emp.id}</div>
                <div class="driver-card-status">
                    ${badge(DRIVER_STATUS_META[d.driver.currentStatus])}
                    <span style="color:var(--text-2)">Fahrer seit ${formatDate(emp.hiredAt)}</span>
                </div>
                <div style="margin-top:14px;">
                    <label style="margin-top:0;">Status ändern</label>
                    <select id="driver-status-select">
                        ${Object.keys(DRIVER_STATUS_META).map((k) => `<option value="${k}" ${k === d.driver.currentStatus ? 'selected' : ''}>${DRIVER_STATUS_META[k].label}</option>`).join('')}
                    </select>
                    <button class="btn btn-primary btn-sm" style="margin-top:10px;" onclick="Actions.setDriverStatus()">Übernehmen</button>
                </div>
            </div>
            <div class="driver-card-section">
                <h4>Fahrerkarte</h4>
                <div class="stat-row">
                    <span>Status</span>
                    <span>${d.driver.onShift ? `Eingesteckt (seit ${formatDate(d.driver.shiftStartedAt, true)})` : 'Nicht eingesteckt'}</span>
                </div>
                <p class="card-hint">Vor der Annahme eines Auftrags musst du hier deine Fahrt starten, damit deine Lenk-/Ruhezeiten erfasst werden.</p>
                ${d.driver.onShift
                    ? `<button class="btn btn-sm btn-danger" onclick="Actions.endShift()">Fahrerkarte abziehen (Fahrt beenden)</button>`
                    : `<button class="btn btn-sm btn-primary" onclick="Actions.openStartShiftModal()">Fahrerkarte einstecken (Fahrt starten)</button>`}
            </div>
            <div class="driver-card-section">
                <h4>Statistik</h4>
                <div class="stat-row"><span>Aufträge</span><span>${stats.total_orders}</span></div>
                <div class="stat-row"><span>Kilometer</span><span>${Number(stats.total_km).toLocaleString('de-DE')} km</span></div>
                <div class="stat-row"><span>Lieferungen</span><span>${stats.successful_deliveries}</span></div>
                <div class="stat-row"><span>Pünktlich</span><span>${stats.punctuality_rate} %</span></div>
                <div class="stat-row"><span>Abgebrochen/Abgelehnt</span><span>${stats.cancelled_orders}</span></div>
            </div>
            <div class="driver-card-section">
                <h4>Fahrerberechtigungen</h4>
                <div class="perm-list">${permsHtml}</div>
            </div>
            <div class="driver-card-section">
                <h4>Lenk- &amp; Ruhezeiten</h4>
                ${renderHoursBlock(d.hours)}
            </div>
            <div class="driver-card-section">
                <h4>Aktueller LKW</h4>
                ${vehicle ? `
                    <div class="stat-row"><span>${escapeHtml(vehicle.name)}</span><span>${escapeHtml(vehicle.model)}</span></div>
                    <div class="stat-row"><span>Kennzeichen</span><span>${escapeHtml(vehicle.plate)}</span></div>
                    <div class="stat-row"><span>Kilometerstand</span><span>${Number(vehicle.mileage).toLocaleString('de-DE')} km</span></div>
                ` : `<div class="card-hint">Kein Fahrzeug zugewiesen.</div>`}
            </div>
            ${d.driver.notes ? `
            <div class="driver-card-section">
                <h4>Verwarnungen / Notizen</h4>
                <div style="font-size:13px;color:var(--text-1);">${escapeHtml(d.driver.notes)}</div>
            </div>` : ''}
        </div>`;
};

// "Meine Aufträge" - zusammengelegte Fahrer-App: aktuelle Aufträge/Pool +
// Historie als Sektionen rechts (renderSectionedApp), statt zwei eigener
// Kategorie-Kacheln ("Aufträge" + "Historie").
VIEWS['driver-orders'] = async (root) => {
    await renderSectionedApp(root, 'driver-orders', [
        { key: 'current', label: 'Aktuell', render: renderDriverOrdersCurrent },
        { key: 'history', label: 'Historie', render: renderDriverOrdersHistory },
    ]);
};

async function renderDriverOrdersCurrent(root) {
    const [d, pool] = await Promise.all([call('driver:myOrders'), call('driver:openOrders')]);

    const cargoHint = { anfahrt: 'Zum Beladepunkt fahren, dort per E abholen', beladen: 'Zum Zielort fahren, dort per E abliefern', entladen: 'Wird entladen...' };

    const coordsText = (c) => (c ? `GPS: ${c.x}, ${c.y}` : '');
    const CANCELLABLE_STATUSES = ['angenommen', 'anfahrt', 'beladen', 'entladen'];

    const rows = d.orders.map((o) => {
        let actions = '';
        if (o.status === 'disponiert') {
            actions = `<button class="btn btn-sm btn-primary" onclick="Actions.acceptOrder(${o.id})">Annehmen</button>
                        <button class="btn btn-sm btn-danger" onclick="Actions.declineOrder(${o.id})">Ablehnen</button>`;
        } else if (cargoHint[o.status]) {
            actions = `<span class="view-subtitle" style="margin:0;">${cargoHint[o.status]}</span>`;
        }
        if (CANCELLABLE_STATUSES.includes(o.status)) {
            actions += `<button class="btn btn-sm" style="margin-left:6px;" onclick="Actions.setCustomMarker(${o.id})">Neue Markierung setzen</button>`;
            actions += o.pending_cancel_request_id
                ? `<span class="pill pill-warning" style="margin-left:6px;">Abbruch angefragt</span>`
                : `<button class="btn btn-sm btn-danger" style="margin-left:6px;" onclick="Actions.requestCancelOrder(${o.id})">Abbrechen</button>`;
        }
        const lieferschein = ['angenommen', 'anfahrt', 'beladen', 'entladen'].includes(o.status) ? `
            <tr class="lieferschein-row">
                <td colspan="7">
                    <div class="lieferschein">
                        <div class="lieferschein-head">
                            <div class="lieferschein-title">Lieferschein #${o.id}</div>
                            <div class="lieferschein-meta">Ausgestellt ${formatDate(o.created_at, true)}${o.dispatcher_name ? ` · Disponiert von ${escapeHtml(o.dispatcher_name)}` : ''}</div>
                        </div>
                        <div class="lieferschein-grid">
                            <div><span>Ware</span><strong>${escapeHtml(o.cargo)}</strong></div>
                            <div><span>Menge</span><strong>${o.cargo_amount ? `${Number(o.cargo_amount).toLocaleString('de-DE')} ${escapeHtml(o.cargo_unit || '')}` : '-'}</strong></div>
                            <div><span>Gefahrgut</span><strong>${o.requires_permission ? 'Ja' : 'Nein'}</strong></div>
                            <div><span>Entfernung</span><strong>${Number(o.distance_km).toLocaleString('de-DE')} km</strong></div>
                            <div><span>Abholort</span><strong>${escapeHtml(o.start_location)}</strong><small>${coordsText(o.start_coords)}</small></div>
                            <div><span>Zielort</span><strong>${escapeHtml(o.end_location)}</strong><small>${coordsText(o.end_coords)}</small></div>
                            <div><span>Fahrzeug</span><strong>${o.vehicle_name ? `${escapeHtml(o.vehicle_name)} (${escapeHtml(o.vehicle_plate)})` : '-'}</strong></div>
                            <div><span>Frist</span><strong>${o.deadline ? formatDate(o.deadline, true) : '-'}</strong></div>
                        </div>
                    </div>
                </td>
            </tr>` : '';
        return `<tr>
            <td>#${o.id}</td>
            <td>${escapeHtml(o.cargo)}</td>
            <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
            <td>${Number(o.distance_km).toLocaleString('de-DE')} km</td>
            <td>${o.vehicle_name ? `${escapeHtml(o.vehicle_name)} (${escapeHtml(o.vehicle_plate)})` : '-'}</td>
            <td>${badge(ORDER_STATUS_META[o.status])}</td>
            <td class="btn-row">${actions}</td>
        </tr>${lieferschein}`;
    });

    const poolRows = pool.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}${o.requires_permission ? ' <span class="pill pill-warning">Gefahrgut</span>' : ''}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${Number(o.distance_km).toLocaleString('de-DE')} km</td>
        <td>${formatMoney(o.value)}</td>
        <td class="btn-row">
            <button class="btn btn-sm btn-primary" ${pool.dispatcherAvailable ? 'disabled' : ''} onclick="Actions.selfAssignOrder(${o.id})">Übernehmen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Meine Aufträge</h1>
        <p class="view-subtitle">Zugewiesene und aktive Aufträge.</p>
        ${!pool.onShift ? `<p class="view-subtitle" style="color:var(--yellow);">Du musst zuerst deine Fahrerkarte einstecken (Reiter Fahrerkarte, Fahrt starten), bevor du einen Auftrag annehmen kannst.</p>` : ''}
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Fahrzeug', 'Status', 'Aktion'], rows)}</div>

        <h1 class="view-title" style="margin-top:24px;">Offener Auftragspool</h1>
        <p class="view-subtitle">${pool.dispatcherAvailable
            ? 'Ein Disponent ist gerade online - Aufträge werden von ihm zugewiesen.'
            : 'Aktuell ist kein Disponent verfügbar - du kannst dir einen offenen Auftrag selbst übernehmen.'}</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Wert', ''], poolRows)}</div>`;
}

async function renderDriverOrdersHistory(root) {
    const d = await call('driver:history');
    const rows = d.history.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${badge(ORDER_STATUS_META[o.status])}</td>
        <td>${o.status === 'abgeschlossen' ? (o.punctual ? 'Pünktlich' : 'Verspätet') : '-'}</td>
        <td>${o.status === 'abgeschlossen' ? formatMoney(o.value) : '-'}</td>
        <td>${formatDate(o.completed_at || o.created_at, true)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Auftragshistorie</h1>
        <p class="view-subtitle">Deine abgeschlossenen, abgebrochenen und abgelehnten Aufträge.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Status', 'Pünktlichkeit', 'Wert', 'Datum'], rows)}</div>`;
}

VIEWS['driver-earnings'] = async (root) => {
    const e = await call('driver:earnings');
    root.innerHTML = `
        <h1 class="view-title">Meine Einnahmen</h1>
        <p class="view-subtitle">Von dir erwirtschafteter Unternehmensumsatz - kein Auszahlungsanspruch.</p>
        <div class="grid grid-3">
            <div class="card"><div class="card-title">Diese Woche</div><div class="card-value">${formatMoney(e.thisWeek)}</div></div>
            <div class="card"><div class="card-title">Dieser Monat</div><div class="card-value">${formatMoney(e.thisMonth)}</div></div>
            <div class="card"><div class="card-title">Gesamt</div><div class="card-value">${formatMoney(e.total)}</div></div>
        </div>
        <div class="section" style="margin-top:16px;">
            <div class="section-header"><h3>Auszahlungsstatus</h3></div>
            <p style="color:var(--text-1);font-size:13px;line-height:1.6;">
                Diese Beträge gehören dem <strong>Speditionsunternehmen</strong> und liegen als Unternehmensguthaben vor.
                Sie werden <strong>nicht automatisch</strong> auf dein persönliches Spielerkonto überwiesen.
                Auszahlungen aus dem Unternehmensguthaben kann ausschließlich die Geschäftsführung vornehmen.
            </p>
        </div>`;
};

VIEWS['driver-vehicle'] = async (root) => {
    const d = await call('driver:vehicle');
    const v = d.vehicle;
    root.innerHTML = `
        <h1 class="view-title">Mein Fahrzeug</h1>
        <p class="view-subtitle">Dir aktuell zugewiesenes Firmenfahrzeug.</p>
        ${v ? `
        <div class="card" style="max-width:420px;">
            <div class="card-title">${escapeHtml(v.vehicle_class)}</div>
            <div class="card-value small">${escapeHtml(v.name)}</div>
            <div class="stat-row"><span>Modell</span><span>${escapeHtml(v.model)}</span></div>
            <div class="stat-row"><span>Kennzeichen</span><span>${escapeHtml(v.plate)}</span></div>
            <div class="stat-row"><span>Kilometerstand</span><span>${Number(v.mileage).toLocaleString('de-DE')} km</span></div>
            <div class="stat-row"><span>Tank</span><span>${v.fuel} %</span></div>
            <div class="stat-row"><span>Status</span><span>${badge(VEHICLE_STATUS_META[v.status])}</span></div>
        </div>` : `<div class="section card-hint">Dir ist aktuell kein Fahrzeug zugewiesen.</div>`}`;
};

VIEWS['driver-messages'] = async (root) => {
    const d = await call('driver:messages');
    const rows = d.messages.map((m) => `
        <div class="section" style="margin-bottom:10px;${m.read_state ? 'opacity:0.6;' : ''}">
            <div class="section-header">
                <h3>${escapeHtml(m.title)}</h3>
                <span class="card-hint">${formatDate(m.created_at, true)}</span>
            </div>
            <p style="font-size:13px;color:var(--text-1);margin:0 0 8px;">${escapeHtml(m.message)}</p>
            ${m.sender_name ? `<div class="card-hint">Von: ${escapeHtml(m.sender_name)}</div>` : ''}
            ${!m.read_state ? `<button class="btn btn-sm" style="margin-top:8px;" onclick="Actions.markRead(${m.id})">Als gelesen markieren</button>` : ''}
        </div>`).join('');

    root.innerHTML = `
        <h1 class="view-title">Nachrichten</h1>
        <p class="view-subtitle">Nachrichten von deinem Disponenten.</p>
        ${rows || '<div class="section card-hint">Keine Nachrichten vorhanden.</div>'}`;
};

// ---------- DISPONENT ----------

// Wiederverwendbare Zeilen-Renderer für Fahrer/Auftragspool/aktive Aufträge -
// werden von den Sektionen der zusammengelegten App "Auftragsverwaltung"
// (VIEWS['dispatch-orders']) sowie von VIEWS['dispatch-drivers'] verwendet,
// damit keine Zeilen-/Aktions-Logik doppelt gepflegt werden muss.
function driversTableRows(drivers) {
    return drivers.map((r) => `<tr>
        <td>${badge(DRIVER_STATUS_META[r.current_status])}</td>
        <td>${escapeHtml(r.name)}</td>
        <td>${r.vehicle_name ? `${escapeHtml(r.vehicle_name)} (${escapeHtml(r.vehicle_plate)})` : '-'}</td>
        <td>${r.vehicle_status ? badge(VEHICLE_STATUS_META[r.vehicle_status]) : '-'}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.messageDriver(${r.driver_id}, ${escapeHtml(JSON.stringify(r.name))})">Nachricht</button>
            <button class="btn btn-sm" onclick="Actions.remindDriver(${r.driver_id})">Lenkzeit erinnern</button>
        </td>
    </tr>`);
}

function openOrdersTableRows(orders) {
    return orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}${o.requires_permission ? ' <span class="pill pill-warning">Gefahrgut</span>' : ''}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${Number(o.distance_km).toLocaleString('de-DE')} km</td>
        <td>${formatMoney(o.value)}</td>
        <td><button class="btn btn-sm btn-primary" onclick="Actions.openDispatchModal(${o.id}, ${escapeHtml(JSON.stringify(o.requires_permission || null))})">Disponieren</button></td>
    </tr>`);
}

function activeOrdersTableRows(orders) {
    return orders.map((o) => {
        const cancelActions = o.pending_cancel_request_id ? `
            <button class="btn btn-sm btn-primary" onclick="Actions.resolveCancelRequest(${o.pending_cancel_request_id}, true)">Abbruch genehmigen</button>
            <button class="btn btn-sm" onclick="Actions.resolveCancelRequest(${o.pending_cancel_request_id}, false)">Ablehnen</button>` : '';
        return `<tr>
            <td>#${o.id}</td>
            <td>${escapeHtml(o.cargo)}</td>
            <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
            <td>${o.driver_name ? escapeHtml(o.driver_name) : '-'}</td>
            <td>${o.vehicle_name ? `${escapeHtml(o.vehicle_name)} (${escapeHtml(o.vehicle_plate)})` : '-'}</td>
            <td>${badge(ORDER_STATUS_META[o.status])}${o.pending_cancel_request_id ? ' <span class="pill pill-warning">Abbruch angefragt</span>' : ''}</td>
            <td class="btn-row">
                ${cancelActions}
                ${['disponiert', 'angenommen', 'anfahrt', 'beladen'].includes(o.status) ? `<button class="btn btn-sm" onclick="Actions.openReassignModal(${o.id})">Neu zuweisen</button>` : ''}
                <button class="btn btn-sm btn-danger" onclick="Actions.cancelOrder(${o.id})">Abbrechen</button>
            </td>
        </tr>`;
    });
}

// ---------------------------------------------------------
// Live-Karte - zeigt AUSSCHLIESSLICH gerade eingestempelte Fahrer als
// Marker über einem echten Kartenbild (statt eines abstrakten Schemas).
// Das Kartenbild selbst liefert diese Ressource NICHT mit (Rockstars
// GTA-V-Kartengrafik ist urheberrechtlich geschützt) - lege eine eigene
// Datei unter html/img/map.jpg ab (siehe README "Live-Karte").
//
// Die Fahrerposition selbst kommt IMMER direkt und serverseitig von GTA
// (GetEntityCoords, server/sv_tracking.lua) - kein Client-Trust, keine
// Kalibrierung nötig. DEFAULT_MAP_BOUNDS ist lediglich die feste
// Umrechnung Weltkoordinaten→Kartenbild-Prozent für den mitgelieferten
// Config.LiveMap.bounds-Wert (config.lua). Passt dein eigenes Kartenbild
// nicht zu diesem Ausschnitt, passe die vier Zahlen dort direkt an
// (siehe README "Live-Karte") - ein separates Kalibrierungswerkzeug gibt
// es bewusst nicht mehr, um die App einfach zu halten.
// ---------------------------------------------------------

const DEFAULT_MAP_BOUNDS = { minX: -4300, maxX: 4700, minY: -4300, maxY: 8200 };
const LIVE_MAP_POLL_MS = 3000; // sollte grob Config.LiveMap.trackingIntervalMs (Lua) entsprechen

function worldToMapPercent(x, y) {
    const b = (State.config && State.config.liveMapBounds) || DEFAULT_MAP_BOUNDS;
    const px = ((x - b.minX) / (b.maxX - b.minX)) * 100;
    const py = 100 - ((y - b.minY) / (b.maxY - b.minY)) * 100; // Y invertiert: Norden (GTA Y+) = oben
    return [px, py];
}

VIEWS['dispatch-map'] = async (root) => {
    root.innerHTML = `
        <h1 class="view-title">Live-Karte</h1>
        <p class="view-subtitle">Zeigt ausschließlich gerade eingestempelte Fahrer (aktualisiert alle ${Math.round(LIVE_MAP_POLL_MS / 1000)}s).</p>
        <div class="live-map-wrap">
            <img id="live-map-img" class="live-map-img" src="img/map.jpg" alt="Karte" onerror="this.closest('.live-map-wrap').classList.add('live-map-img-missing')" />
            <div class="live-map-img-fallback-hint">Kein Kartenbild gefunden - lege eine Datei unter <code>html/img/map.jpg</code> ab (siehe README).</div>
            <div id="live-map-markers" class="live-map-markers"></div>
        </div>
        <div class="section" style="margin-top:16px;" id="live-map-driver-list"></div>`;

    const markersEl = document.getElementById('live-map-markers');
    const listEl = document.getElementById('live-map-driver-list');

    const refresh = async () => {
        const d = await call('dispatch:liveMap');

        markersEl.innerHTML = d.drivers.map((drv) => {
            const [px, py] = worldToMapPercent(drv.x, drv.y);
            return `<div class="live-map-marker" style="left:${px}%;top:${py}%;" title="${escapeHtml(drv.name)}">
                <div class="live-map-dot"></div>
                <div class="live-map-marker-label">${escapeHtml(drv.name)}</div>
            </div>`;
        }).join('');

        listEl.innerHTML = d.drivers.map((drv) => {
            const orderLabel = drv.order
                ? `Auftrag - ${escapeHtml(drv.order.cargo)}: ${escapeHtml(drv.order.startLocation)} → ${escapeHtml(drv.order.endLocation)} (${escapeHtml((ORDER_STATUS_META[drv.order.status] && ORDER_STATUS_META[drv.order.status].label) || drv.order.status)})`
                : 'Kein laufender Auftrag';
            const vehicleLabel = drv.vehicleLabel || drv.vehiclePlate
                ? `${escapeHtml(drv.vehicleLabel || 'Fahrzeug')}${drv.vehiclePlate ? ` - ${escapeHtml(drv.vehiclePlate)}` : ''}`
                : 'Kein Fahrzeug erkannt';
            return `<div class="live-map-driver-row">
                <div>
                    <div class="live-map-driver-name">${escapeHtml(drv.name)}</div>
                    <div class="live-map-driver-order">${vehicleLabel}</div>
                    <div class="live-map-driver-order">${orderLabel}</div>
                </div>
            </div>`;
        }).join('') || '<div class="card-hint">Aktuell ist niemand eingestempelt.</div>';
    };

    await refresh();
    activeViewInterval = setInterval(refresh, LIVE_MAP_POLL_MS);
};

VIEWS['dispatch-drivers'] = async (root) => {
    const d = await call('dispatch:drivers');
    root.innerHTML = `
        <h1 class="view-title">Fahrerübersicht</h1>
        <p class="view-subtitle">Alle aktiven Fahrer mit Status und aktuellem Fahrzeug.</p>
        <div class="section">${table(['Status', 'Fahrer', 'Fahrzeug', 'Fahrzeugstatus', ''], driversTableRows(d.drivers))}</div>`;
};

// Dock-App (kein Kategorie-Eintrag, s. DOCK_ITEMS/renderDock()) - der
// Dispositions-Dienst-Toggle: erst wenn ein Disponent im Dienst ist, gilt
// die Disposition als aktiv (isDispatcherAvailable() serverseitig), vorher
// dürfen Fahrer offene Aufträge wieder selbst übernehmen.
VIEWS['dispatch-duty'] = async (root) => {
    const duty = await call('dispatch:dutyStatus');
    root.innerHTML = `
        <h1 class="view-title">Dispositions-Dienst</h1>
        <p class="view-subtitle">Erst wenn ein Disponent im Dienst ist, gilt die Disposition als aktiv - vorher können Fahrer offene Aufträge wieder selbst übernehmen.</p>
        <div class="section" style="display:flex;align-items:center;justify-content:space-between;gap:14px;">
            <div>
                <div class="card-title">Status</div>
                <div class="card-hint">${duty.onDuty
                    ? `Im Dienst seit ${formatDate(duty.shiftStartedAt, true)} - du bist für Fahrer als verfügbarer Disponent sichtbar, die Selbstzuweisung offener Aufträge ist für sie gesperrt.`
                    : 'Nicht im Dienst - Fahrer können sich offene Aufträge derzeit selbst zuweisen, solange kein Disponent im Dienst ist.'}</div>
            </div>
            ${duty.onDuty
                ? `<button class="btn btn-danger" onclick="Actions.endDispatchDuty()">Dienst beenden</button>`
                : `<button class="btn btn-primary" onclick="Actions.startDispatchDuty()">Dienst beginnen</button>`}
        </div>`;
};

// "Auftragsverwaltung" - zusammengelegte Disponenten-App: Pool/Aktiv/
// Abgeschlossen als Sektionen rechts statt drei eigener Kategorie-Kacheln
// (löst außerdem das frühere "Allgemeine Disposition"-Cockpit ab - die
// Fahrerübersicht bleibt als eigene App unter Mitarbeiterverwaltung
// erhalten, statt hier dupliziert zu werden). Der Dispositions-Dienst-
// Toggle zieht mit dem Home-Dock in Schritt C um.
VIEWS['dispatch-orders'] = async (root) => {
    await renderSectionedApp(root, 'dispatch-orders', [
        { key: 'pool', label: 'Pool', render: renderDispatchOrdersPool },
        { key: 'active', label: 'Aktiv', render: renderDispatchOrdersActive },
        { key: 'completed', label: 'Abgeschlossen', render: renderDispatchOrdersCompleted },
    ]);
};

async function renderDispatchOrdersPool(root) {
    const [pool, drivers] = await Promise.all([call('dispatch:openOrders'), call('dispatch:drivers')]);
    window.__availableDrivers = drivers.drivers;
    root.innerHTML = `
        <h1 class="view-title">Auftragspool</h1>
        <p class="view-subtitle">Automatisch generierte Aufträge, die noch keinem Fahrer zugewiesen sind.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Wert', ''], openOrdersTableRows(pool.orders))}</div>`;
}

async function renderDispatchOrdersActive(root) {
    const [active, drivers] = await Promise.all([call('dispatch:activeOrders'), call('dispatch:drivers')]);
    window.__availableDrivers = drivers.drivers;
    root.innerHTML = `
        <h1 class="view-title">Aktive Aufträge</h1>
        <p class="view-subtitle">Live-Überwachung aller disponierten und laufenden Aufträge.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Fahrer', 'Fahrzeug', 'Status', 'Aktion'], activeOrdersTableRows(active.orders))}</div>`;
}

async function renderDispatchOrdersCompleted(root) {
    const d = await call('dispatch:completedOrders');
    const rows = d.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${o.driver_name ? escapeHtml(o.driver_name) : '-'}</td>
        <td>${badge(ORDER_STATUS_META[o.status])}</td>
        <td>${o.status === 'abgeschlossen' ? formatMoney(o.value) : '-'}</td>
        <td>${formatDate(o.completed_at, true)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Abgeschlossene Aufträge</h1>
        <p class="view-subtitle">Historie abgeschlossener, abgebrochener und abgelehnter Aufträge.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Fahrer', 'Status', 'Wert', 'Datum'], rows)}</div>`;
}

// ---------- GESCHÄFTSFÜHRUNG ----------

// "Finanzcenter" - zusammengelegte Finanz-App: Übersicht/Umsatz/Finanzen/
// Gehälter/Ein-Auszahlungen als Sektionen rechts, statt fünf eigener
// Kategorie-Kacheln unter "Finanzen". Jede Sektion behält ihre bisherige
// Berechtigung (appHasPermission() macht die App sichtbar, sobald
// mindestens eine davon vorhanden ist).
VIEWS['gf-finance-hub'] = async (root) => {
    await renderSectionedApp(root, 'gf-finance-hub', [
        { key: 'overview', label: 'Übersicht', perm: 'stats_view', render: renderFinanceOverview },
        { key: 'revenue', label: 'Umsatz', perm: 'dispatch', render: renderFinanceRevenue },
        { key: 'finance', label: 'Finanzen', perm: 'finance_view', render: renderFinanceLedger },
        { key: 'payroll', label: 'Gehälter', perm: 'wages_manage', render: renderFinancePayroll },
        { key: 'payouts', label: 'Ein-/Auszahlungen', perm: 'finance_payout', render: renderFinancePayouts },
    ]);
};

async function renderFinanceRevenue(root) {
    const r = await call('dispatch:companyOrdersRevenue');
    root.innerHTML = `
        <h1 class="view-title">Unternehmensumsatz</h1>
        <p class="view-subtitle">Reine Leseansicht - Auszahlungen sind der Geschäftsführung vorbehalten.</p>
        <div class="grid grid-3">
            <div class="card"><div class="card-title">Einnahmen heute</div><div class="card-value">${formatMoney(r.revenueToday)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Woche</div><div class="card-value">${formatMoney(r.revenueWeek)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Monat</div><div class="card-value">${formatMoney(r.revenueMonth)}</div></div>
        </div>`;
}

async function renderFinanceOverview(root) {
    const [d, stats] = await Promise.all([call('gf:dashboard'), call('gf:stats')]);
    const activity = d.recentActivity.map((a) => `<div class="stat-row"><span>[${formatDate(a.created_at, true)}] ${a.employee_name ? escapeHtml(a.employee_name) : 'System'}</span><span style="color:var(--text-2);">${escapeHtml(a.details)}</span></div>`).join('');

    const maxRevenue = Math.max(1, ...stats.revenueByDay.map((r) => Number(r.total)));
    const revenueBars = stats.revenueByDay.map((r) => {
        const pct = Math.max(3, Math.round((Number(r.total) / maxRevenue) * 100));
        return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;" title="${formatDate(r.day)}: ${formatMoney(r.total)}">
            <div style="width:100%;height:90px;display:flex;align-items:flex-end;">
                <div style="width:100%;height:${pct}%;background:var(--accent);border-radius:4px 4px 0 0;"></div>
            </div>
            <span style="font-size:10px;color:var(--text-2);">${formatDate(r.day).slice(0, 5)}</span>
        </div>`;
    }).join('');

    const topDriversRows = stats.topDrivers.map((t) => `<tr>
        <td>${escapeHtml(t.name)}</td>
        <td>${t.total_orders}</td>
        <td>${Number(t.total_km).toLocaleString('de-DE')} km</td>
        <td>${t.successful_deliveries}</td>
        <td>${t.punctuality_rate} %</td>
    </tr>`);

    const statusOrder = ['offen', 'disponiert', 'angenommen', 'anfahrt', 'beladen', 'entladen', 'unterwegs', 'abgeschlossen', 'abgebrochen', 'abgelehnt'];
    const statusCounts = {};
    stats.ordersByStatus.forEach((s) => { statusCounts[s.status] = s.c; });
    const maxStatus = Math.max(1, ...Object.values(statusCounts).map(Number));
    const statusBars = statusOrder.filter((s) => statusCounts[s]).map((s) => {
        const count = Number(statusCounts[s]);
        const pct = Math.max(4, Math.round((count / maxStatus) * 100));
        return `<div class="stat-row" style="align-items:center;">
            <span style="width:120px;">${badge(ORDER_STATUS_META[s])}</span>
            <span style="flex:1;background:var(--bg-3);border-radius:4px;margin:0 10px;overflow:hidden;height:8px;">
                <span style="display:block;height:100%;width:${pct}%;background:var(--accent);"></span>
            </span>
            <span>${count}</span>
        </div>`;
    }).join('');

    root.innerHTML = `
        <h1 class="view-title">Geschäftsführung</h1>
        <p class="view-subtitle">Unternehmensübersicht in Echtzeit.</p>
        <div class="grid grid-4">
            <div class="card"><div class="card-title">Unternehmensguthaben</div><div class="card-value">${formatMoney(d.balance)}</div></div>
            <div class="card"><div class="card-title">Umsatz heute</div><div class="card-value">${formatMoney(d.revenueToday)}</div></div>
            <div class="card"><div class="card-title">Umsatz Woche</div><div class="card-value">${formatMoney(d.revenueWeek)}</div></div>
            <div class="card"><div class="card-title">Umsatz Monat</div><div class="card-value">${formatMoney(d.revenueMonth)}</div></div>
        </div>
        <div class="grid grid-4" style="margin-top:16px;">
            <div class="card"><div class="card-title">Aufträge abgeschlossen</div><div class="card-value small">${d.totalOrders}</div></div>
            <div class="card"><div class="card-title">Offene Aufträge</div><div class="card-value small">${d.openOrders}</div></div>
            <div class="card"><div class="card-title">Aktive Aufträge</div><div class="card-value small">${d.activeOrders}</div></div>
            <div class="card"><div class="card-title">Fahrer / Disponenten</div><div class="card-value small">${d.drivers} / ${d.dispatchers}</div></div>
        </div>
        <div class="grid grid-4" style="margin-top:16px;">
            <div class="card"><div class="card-title">LKW gesamt</div><div class="card-value small">${d.vehicles}</div></div>
            <div class="card"><div class="card-title">LKW im Einsatz</div><div class="card-value small">${d.vehiclesInUse}</div></div>
            <div class="card"><div class="card-title">LKW verfügbar</div><div class="card-value small">${d.vehiclesAvailable}</div></div>
            <div class="card"><div class="card-title">LKW Wartung/Defekt</div><div class="card-value small">${d.vehiclesMaintenance}</div></div>
        </div>
        <div class="grid grid-2" style="margin-top:16px;">
            <div class="section">
                <div class="section-header"><h3>Umsatz der letzten 14 Tage</h3></div>
                <div style="display:flex;gap:6px;align-items:flex-end;">${revenueBars || '<div class="card-hint">Keine Daten.</div>'}</div>
            </div>
            <div class="section">
                <div class="section-header"><h3>Aufträge nach Status</h3></div>
                ${statusBars || '<div class="card-hint">Keine Daten.</div>'}
            </div>
        </div>
        <div class="section" style="margin-top:16px;">
            <div class="section-header"><h3>Top-Fahrer</h3></div>
            ${table(['Fahrer', 'Aufträge', 'Kilometer', 'Lieferungen', 'Pünktlichkeit'], topDriversRows)}
        </div>
        <div class="section" style="margin-top:16px;">
            <div class="section-header"><h3>Letzte Aktivitäten</h3></div>
            ${activity || '<div class="card-hint">Keine Aktivitäten.</div>'}
        </div>`;
}

// "Mitarbeiter" - zusammengelegte App: Mitarbeiter/Rollen als Sektionen
// rechts statt zweier eigener Kategorie-Kacheln unter Mitarbeiterverwaltung.
VIEWS['gf-employees'] = async (root) => {
    await renderSectionedApp(root, 'gf-employees', [
        { key: 'staff', label: 'Mitarbeiter', perm: 'employees_manage', render: renderStaffList },
        { key: 'roles', label: 'Rollen', perm: 'roles_manage', render: renderStaffRoles },
    ]);
};

async function renderStaffList(root) {
    const [d, rolesRes] = await Promise.all([call('gf:employees:list'), call('roles:list')]);
    const roleOptions = (e) => rolesRes.roles.map((r) => `<option value="${r.key}" ${e.role === r.key ? 'selected' : ''}>${escapeHtml(r.label)}</option>`).join('');
    const rows = d.employees.map((e) => `<tr>
        <td>#${e.id}</td>
        <td>${escapeHtml(e.name)}</td>
        <td>${escapeHtml(e.username || '-')}</td>
        <td>
            <select onchange="Actions.changeRole(${e.id}, this.value)">${roleOptions(e)}</select>
        </td>
        <td>${badge(EMPLOYMENT_STATUS_META[e.status])}</td>
        <td>${formatDate(e.hired_at)}</td>
        <td>
            <button class="btn btn-sm" onclick="Actions.openSetDiscordIdModal(${e.id}, '${escapeHtml(e.name)}', ${escapeHtml(JSON.stringify(e.discord_id || ''))})">${e.discord_id ? escapeHtml(e.discord_id) : 'nicht verknüpft'}</button>
        </td>
        <td class="btn-row">
            ${e.driver_id ? `<button class="btn btn-sm btn-primary" onclick="Actions.openDriverFile(${e.driver_id})">Fahrerakte</button>` : ''}
            <button class="btn btn-sm" onclick="Actions.openResetPasswordModal(${e.id}, '${escapeHtml(e.name)}')">Passwort zurücksetzen</button>
            <button class="btn btn-sm ${e.status === 'aktiv' ? 'btn-danger' : 'btn-primary'}" onclick="Actions.toggleEmployeeStatus(${e.id}, '${e.status === 'aktiv' ? 'inaktiv' : 'aktiv'}')">${e.status === 'aktiv' ? 'Deaktivieren' : 'Aktivieren'}</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Mitarbeiter</h1>
        <p class="view-subtitle">Verwaltung aller Mitarbeiter, Rollen und Grade. Anmeldung erfolgt am Tablet per Name + Passwort. Die Discord-ID ist nur für den Website-Sync relevant (Config.Website) - verknüpft das Konto mit dem Discord-Login der Speditions-Website. Fahrer haben zusätzlich einen "Fahrerakte"-Button für die digitale Personalakte.</p>
        <div class="btn-row" style="margin-bottom:14px;"><button class="btn btn-primary" onclick="Actions.openHireModal()">+ Mitarbeiter einstellen</button></div>
        <div class="section">${table(['#', 'Name', 'Login-Name', 'Rolle', 'Status', 'Eingestellt', 'Discord-ID', ''], rows)}</div>`;
}

async function renderStaffRoles(root) {
    const d = await call('roles:list');
    const permLabel = (key) => {
        const p = d.permissionCatalog.find((x) => x.key === key);
        return p ? p.label : key;
    };

    const websiteRoleOptions = (r) => `<option value="">— keine —</option>` + Object.keys(WEBSITE_ROLE_LABELS).map((key) =>
        `<option value="${key}" ${r.websiteRoleKey === key ? 'selected' : ''}>${escapeHtml(WEBSITE_ROLE_LABELS[key])}</option>`
    ).join('');

    const rows = d.roles.map((r) => `<tr>
        <td>${escapeHtml(r.label)}${r.isBuiltin ? ' <span class="pill"><span class="dot dot-gray"></span>Basisrolle</span>' : ''}</td>
        <td style="max-width:420px;">${r.permissions.map((p) => `<span class="pill" style="margin:2px 4px 2px 0;"><span class="dot dot-blue"></span>${escapeHtml(permLabel(p))}</span>`).join('') || '<span class="card-hint">Keine Berechtigungen</span>'}</td>
        <td>
            <select onchange="Actions.setRoleWebsiteMapping('${r.key}', this.value)">${websiteRoleOptions(r)}</select>
        </td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.openEditRoleModal('${r.key}')">Bearbeiten</button>
            ${r.isBuiltin ? '' : `<button class="btn btn-sm btn-danger" onclick="Actions.deleteRole('${r.key}', ${escapeHtml(JSON.stringify(r.label))})">Löschen</button>`}
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Rollen</h1>
        <p class="view-subtitle">Eigene Rollen mit frei wählbaren Berechtigungen anlegen und bearbeiten. Die drei mitgelieferten Basisrollen (Fahrer/Disponent/Geschäftsführung) können nicht gelöscht, ihre Berechtigungen aber angepasst werden. Die Spalte "Website-Rolle" ordnet diese Rolle - nur relevant bei aktiviertem Website-Sync (Config.Website) - einer der 9 Rollen der Speditions-Website zu, damit Mitarbeiter mit dieser Rolle dorthin synchronisiert werden können.</p>
        <div class="btn-row" style="margin-bottom:14px;"><button class="btn btn-primary" onclick="Actions.openCreateRoleModal()">+ Rolle anlegen</button></div>
        <div class="section">${table(['Rolle', 'Berechtigungen', 'Website-Rolle', ''], rows)}</div>`;
}

// "Fuhrpark-Verwaltung" - zusammengelegte App: Fahrzeuge/Anhänger als
// Sektionen rechts statt zweier eigener Kategorie-Kacheln (beide teilen
// ohnehin dieselbe Berechtigung fleet_manage).
VIEWS['gf-fleet-hub'] = async (root) => {
    await renderSectionedApp(root, 'gf-fleet-hub', [
        { key: 'vehicles', label: 'Fahrzeuge', render: renderFleetVehicles },
        { key: 'trailers', label: 'Anhänger', render: renderFleetTrailers },
    ]);
};

async function renderFleetVehicles(root) {
    const includeArchived = window.__fleetShowArchived === true;
    const d = await call('gf:vehicles:list', { includeArchived });

    const rows = d.vehicles.map((v) => `<tr>
        <td>${badge(VEHICLE_STATUS_META[v.status])}</td>
        <td>${escapeHtml(v.name)}${v.archived ? ' <span class="pill">Archiviert</span>' : ''}</td>
        <td>${escapeHtml(v.plate)}</td>
        <td>${escapeHtml(v.vehicle_class)}</td>
        <td>${Number(v.mileage).toLocaleString('de-DE')} km</td>
        <td>${v.driver_name ? escapeHtml(v.driver_name) : '-'}</td>
        <td>${v.trailer_id ? escapeHtml(v.trailer_name) : '-'}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.openVehicleFile(${v.id})">Akte</button>
            ${!v.archived ? `
                <button class="btn btn-sm" onclick="Actions.openVehicleEditModal(${v.id})">Bearbeiten</button>
                <button class="btn btn-sm" onclick="Actions.openAssignModal(${v.id})">Zuweisen</button>
                <button class="btn btn-sm btn-danger" onclick="Actions.openDeleteVehicleModal(${v.id})">Löschen</button>
            ` : `<button class="btn btn-sm btn-primary" onclick="Actions.reactivateVehicle(${v.id})">Reaktivieren</button>`}
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Fuhrpark</h1>
        <p class="view-subtitle">${d.vehicles.length} Fahrzeuge${includeArchived ? ' (inkl. archivierte)' : ''}</p>
        <div class="btn-row" style="margin-bottom:14px;">
            <button class="btn btn-primary" onclick="Actions.openVehicleCreateModal()">+ LKW hinzufügen</button>
            <button class="btn" onclick="Actions.toggleArchivedFleet()">${includeArchived ? 'Archivierte ausblenden' : 'Archivierte anzeigen'}</button>
        </div>
        <div class="section">${table(['Status', 'Name', 'Kennzeichen', 'Klasse', 'Kilometerstand', 'Fahrer', 'Anhänger', ''], rows)}</div>`;
}

async function renderFleetTrailers(root) {
    const d = await call('gf:trailers:list');
    const typeLabel = (key) => (d.trailerTypes.find((t) => t.key === key) || {}).label || key;

    const rows = d.trailers.map((t) => `<tr>
        <td>${badge(VEHICLE_STATUS_META[t.status])}</td>
        <td>${escapeHtml(t.name)}${t.archived ? ' <span class="pill">Archiviert</span>' : ''}</td>
        <td>${escapeHtml(t.plate)}</td>
        <td>${escapeHtml(typeLabel(t.type))}</td>
        <td>${t.vehicle_plate ? `${escapeHtml(t.vehicle_name)} (${escapeHtml(t.vehicle_plate)})` : '-'}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.openTrailerEditModal(${t.id})">Bearbeiten</button>
            <button class="btn btn-sm" onclick="Actions.openTrailerAssignModal(${t.id})">${t.vehicle_plate ? 'Umkuppeln' : 'Ankuppeln'}</button>
            ${t.vehicle_plate ? `<button class="btn btn-sm" onclick="Actions.confirmTrailerAssign(${t.id}, null)">Abkuppeln</button>` : ''}
            <button class="btn btn-sm btn-danger" onclick="Actions.confirmDeleteTrailer(${t.id})">Löschen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Anhänger</h1>
        <p class="view-subtitle">${d.trailers.length} Anhänger</p>
        <div class="btn-row" style="margin-bottom:14px;">
            <button class="btn btn-primary" onclick="Actions.openTrailerCreateModal()">+ Anhänger hinzufügen</button>
        </div>
        <div class="section">${table(['Status', 'Name', 'Kennzeichen', 'Typ', 'Angekuppelt an', ''], rows)}</div>`;
}

VIEWS['gf-locations'] = async (root) => {
    const d = await call('locations:list');

    const rows = d.locations.map((l) => `<tr>
        <td>${escapeHtml(l.name)}</td>
        <td>${(l.sourceCargo || []).map((c) => `<span class="pill">${escapeHtml(c)}</span>`).join(' ') || '-'}</td>
        <td>${(l.destCargo || []).map((c) => `<span class="pill">${escapeHtml(c)}</span>`).join(' ') || '-'}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.openLocationEditModal(${l.id})">Bearbeiten</button>
            <button class="btn btn-sm btn-danger" onclick="Actions.confirmDeleteLocation(${l.id})">Löschen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Orte</h1>
        <p class="view-subtitle">${d.locations.length} Be-/Entladepunkte</p>
        <div class="btn-row" style="margin-bottom:14px;">
            <button class="btn btn-primary" onclick="Actions.openLocationCreateModal()">+ Ort hinzufügen</button>
        </div>
        <div class="section">${table(['Name', 'Quelle (Abholung)', 'Ziel (Anlieferung)', ''], rows)}</div>`;
};

VIEWS['gf-cargo-types'] = async (root) => {
    const [d, trailerData] = await Promise.all([call('cargotypes:list'), call('gf:trailers:list')]);
    const trailerLabel = (key) => (trailerData.trailerTypes.find((t) => t.key === key) || {}).label || key;

    const rows = d.cargoTypes.map((c) => `<tr>
        <td>${escapeHtml(c.name)}</td>
        <td>${escapeHtml(c.unit)}</td>
        <td>${c.min} - ${c.max}</td>
        <td>${c.hazardous ? badge({ label: 'Gefahrgut', dot: 'red' }) : '-'}</td>
        <td>${escapeHtml(trailerLabel(c.trailerType))}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.openCargoTypeEditModal(${c.id})">Bearbeiten</button>
            <button class="btn btn-sm btn-danger" onclick="Actions.confirmDeleteCargoType(${c.id})">Löschen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Frachtarten</h1>
        <p class="view-subtitle">${d.cargoTypes.length} Frachtarten</p>
        <div class="btn-row" style="margin-bottom:14px;">
            <button class="btn btn-primary" onclick="Actions.openCargoTypeCreateModal()">+ Frachtart hinzufügen</button>
        </div>
        <div class="section">${table(['Name', 'Einheit', 'Menge', 'Gefahrgut', 'Anhängertyp', ''], rows)}</div>`;
};

async function renderFinanceLedger(root) {
    const [overview, tx] = await Promise.all([call('gf:finance:overview'), call('gf:finance:transactions', { limit: 40 })]);

    const TX_TYPE_LABELS = { einnahme: 'Einnahme', auszahlung: 'Auszahlung', einzahlung: 'Einzahlung', gehalt: 'Gehalt', vertragsstrafe: 'Vertragsstrafe' };
    const rows = tx.transactions.map((t) => `<tr>
        <td>#${t.id}</td>
        <td>${TX_TYPE_LABELS[t.type] || t.type}${t.driver_name ? ` - ${escapeHtml(t.driver_name)}` : ''}</td>
        <td>${escapeHtml(t.description || '-')}</td>
        <td style="color:${t.amount >= 0 ? 'var(--green)' : 'var(--red)'};font-weight:700;">${t.amount >= 0 ? '+' : ''}${formatMoney(t.amount)}</td>
        <td>${formatDate(t.created_at, true)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Unternehmensfinanzen</h1>
        <div class="section finance-hero">
            <div class="label">Aktuelles Guthaben</div>
            <div class="value">${formatMoney(overview.balance)}</div>
        </div>
        <div class="grid grid-3" style="margin-top:16px;">
            <div class="card"><div class="card-title">Einnahmen heute</div><div class="card-value">${formatMoney(overview.revenueToday)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Woche</div><div class="card-value">${formatMoney(overview.revenueWeek)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Monat</div><div class="card-value">${formatMoney(overview.revenueMonth)}</div></div>
        </div>
        <div class="btn-row" style="margin:16px 0;"><button class="btn btn-primary" onclick="jumpToSection('gf-finance-hub', 'payouts')">Auszahlung verwalten</button></div>
        <div class="section">
            <div class="section-header"><h3>Transaktionshistorie</h3></div>
            ${table(['#', 'Typ', 'Beschreibung', 'Betrag', 'Datum'], rows)}
        </div>`;
}

async function renderFinancePayouts(root) {
    const [overview, payoutHistory, depositHistory] = await Promise.all([
        call('gf:finance:overview'), call('gf:payout:history'), call('gf:deposit:history'),
    ]);

    const payoutRows = payoutHistory.payouts.map((p) => `<tr>
        <td>${formatDate(p.executed_at, true)}</td>
        <td>${formatMoney(p.amount)}</td>
        <td>${escapeHtml(p.target)}</td>
        <td>${escapeHtml(p.executed_by_name || '-')}</td>
        <td>${escapeHtml(p.reason)}</td>
    </tr>`);

    const depositRows = depositHistory.deposits.map((d) => `<tr>
        <td>${formatDate(d.executed_at, true)}</td>
        <td>${formatMoney(d.amount)}</td>
        <td>${escapeHtml(d.source)}</td>
        <td>${escapeHtml(d.executed_by_name || '-')}</td>
        <td>${escapeHtml(d.reason)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Ein-/Auszahlungen</h1>
        <div class="section finance-hero">
            <div class="label">Aktuelles Guthaben</div>
            <div class="value">${formatMoney(overview.balance)}</div>
        </div>
        <div class="grid grid-2" style="margin-top:16px;">
            <div class="section">
                <h3 style="margin:0 0 12px;">Einzahlung</h3>
                <label>Einzahlungsbetrag</label>
                <input id="deposit-amount" type="number" min="1" step="1" />
                <label>Herkunft</label>
                <input id="deposit-source" type="text" value="${escapeHtml(window.__depositSource || 'Bareinzahlung')}" />
                <label>Grund</label>
                <input id="deposit-reason" type="text" />
                <button class="btn btn-primary" style="margin-top:16px;width:100%;" onclick="Actions.executeDeposit()">Einzahlung verbuchen</button>
            </div>
            <div class="section">
                <h3 style="margin:0 0 12px;">Auszahlung</h3>
                <label>Auszahlungsbetrag</label>
                <input id="payout-amount" type="number" min="1" step="1" />
                <label>Auszahlung an</label>
                <input id="payout-target" type="text" value="${escapeHtml(window.__payoutTarget || 'Unternehmensbankkonto')}" />
                <label>Grund</label>
                <input id="payout-reason" type="text" />
                <button class="btn btn-primary" style="margin-top:16px;width:100%;" onclick="Actions.executePayout()">Auszahlung bestätigen</button>
            </div>
        </div>
        <div class="grid grid-2" style="margin-top:16px;">
            <div class="section">
                <div class="section-header"><h3>Einzahlungshistorie</h3></div>
                ${table(['Datum', 'Betrag', 'Herkunft', 'Durchgeführt von', 'Grund'], depositRows)}
            </div>
            <div class="section">
                <div class="section-header"><h3>Auszahlungshistorie</h3></div>
                ${table(['Datum', 'Betrag', 'Ziel', 'Durchgeführt von', 'Grund'], payoutRows)}
            </div>
        </div>`;
}

async function renderFinancePayroll(root) {
    const [ratesRes, overview] = await Promise.all([call('gf:payroll:rates'), call('gf:payroll:overview')]);

    const rateRows = Object.keys(ratesRes.roleLabels).map((role) => `
        <div class="wage-rate-row">
            <label>${escapeHtml(ratesRes.roleLabels[role])}</label>
            <input id="wage-rate-${role}" type="number" min="0" step="0.5" value="${Number(ratesRes.rates[role] || 0)}" />
            <button class="btn btn-sm" onclick="Actions.setWageRate('${role}')">Speichern</button>
        </div>`).join('');

    const employeeRows = overview.employees.map((e) => `<tr>
        <td>${escapeHtml(e.name)}</td>
        <td>${escapeHtml(ratesRes.roleLabels[e.role] || e.role)}</td>
        <td>
            ${e.clockedIn ? badge({ label: 'Eingestempelt', dot: 'green' }) : badge({ label: 'Ausgestempelt', dot: 'gray' })}
            ${e.online ? '' : ` ${badge({ label: 'Nicht online', dot: 'red' })}`}
        </td>
        <td>${formatHm(e.unpaidSeconds)}</td>
        <td>${formatMoney(e.hourlyRate)}/Std.</td>
        <td style="font-weight:700;">${formatMoney(e.amount)}</td>
        <td class="btn-row">
            <button class="btn btn-sm btn-primary" ${e.amount <= 0 || !e.online ? 'disabled' : ''} onclick="Actions.payEmployee(${e.id}, ${escapeHtml(JSON.stringify(e.name))})" title="${e.online ? '' : 'Mitarbeiter ist gerade nicht online/am Tablet eingeloggt'}">Auszahlen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Gehälter</h1>
        <p class="view-subtitle">Stundenlöhne je Rolle festlegen und offene Gehälter anhand der Stempeluhr auszahlen.</p>
        <div class="section">
            <h3 style="margin:0 0 12px;">Stundenlöhne</h3>
            <div class="wage-rate-list">${rateRows}</div>
        </div>
        <div class="section" style="margin-top:16px;">
            <h3 style="margin:0 0 12px;">Offene Gehälter</h3>
            ${table(['Name', 'Rolle', 'Stempeluhr', 'Offene Std.', 'Satz', 'Betrag', ''], employeeRows)}
        </div>`;
}

VIEWS['gf-orders'] = async (root) => {
    const filter = window.__orderStatusFilter || '';
    const d = await call('gf:orders:all', { limit: 150, statusFilter: filter || undefined });

    const rows = d.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${o.driver_name ? escapeHtml(o.driver_name) : '-'}</td>
        <td>${o.vehicle_name ? escapeHtml(o.vehicle_name) : '-'}</td>
        <td>${badge(ORDER_STATUS_META[o.status])}</td>
        <td>${o.status === 'abgeschlossen' ? formatMoney(o.value) : '-'}</td>
        <td>${formatDate(o.created_at, true)}</td>
    </tr>`);

    const statuses = Object.keys(ORDER_STATUS_META);

    root.innerHTML = `
        <h1 class="view-title">Auftragsstatistik</h1>
        <p class="view-subtitle">Vollständige Übersicht aller Aufträge im Unternehmen.</p>
        <div class="btn-row" style="margin-bottom:14px;">
            <select id="order-status-filter" style="width:220px;" onchange="Actions.filterOrders(this.value)">
                <option value="">Alle Status</option>
                ${statuses.map((s) => `<option value="${s}" ${filter === s ? 'selected' : ''}>${ORDER_STATUS_META[s].label}</option>`).join('')}
            </select>
        </div>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Fahrer', 'Fahrzeug', 'Status', 'Wert', 'Erstellt'], rows)}</div>`;
};

VIEWS['gf-log'] = async (root) => {
    const d = await call('gf:activityLog', { limit: 150 });
    const rows = d.entries.map((l) => `<tr>
        <td>${formatDate(l.created_at, true)}</td>
        <td>${l.employee_name ? escapeHtml(l.employee_name) : 'System'}</td>
        <td>${escapeHtml(l.action)}</td>
        <td>${escapeHtml(l.details)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Aktivitätsprotokoll</h1>
        <p class="view-subtitle">Alle protokollierten Aktionen der Geschäftsführung und des Systems.</p>
        <div class="section">${table(['Datum', 'Mitarbeiter', 'Aktion', 'Details'], rows)}</div>`;
};

const CONSOLE_KIND_META = {
    rpc_error: { label: 'RPC-Fehler', dot: 'red' },
    db_error: { label: 'Datenbank-Fehler', dot: 'red' },
    client_error: { label: 'Client-Fehler', dot: 'yellow' },
    info: { label: 'Info', dot: 'blue' },
};

VIEWS['gf-console'] = async (root) => {
    const d = await call('console:list');
    const rows = [...d.entries].reverse().map((e) => `<tr>
        <td>${formatDate(e.at, true)}</td>
        <td>${badge(CONSOLE_KIND_META[e.kind] || { label: e.kind, dot: 'gray' })}</td>
        <td>${escapeHtml(e.context || '-')}</td>
        <td>${escapeHtml(e.message)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Konsole</h1>
        <p class="view-subtitle">
            Fehler, die im Tablet selbst auftreten (RPC-/Datenbankfehler, gemeldete Client-Fehler), sowie
            Info-Meldungen wie die Zusammenfassung des Auftrags-Resets bei jedem Ressourcenstart - neueste zuerst.
            Zeigt NICHT die Konsolen-Ausgabe anderer Ressourcen (z.B. oxmysql selbst) und überlebt keinen
            Ressourcen-Neustart.
        </p>
        <p class="card-hint" style="margin:0 0 10px;">
            Aktuell laufende Skript-Version auf diesem Server: <b>${escapeHtml(d.version || 'unbekannt')}</b>
            (steht in <code>fxmanifest.lua</code> - stimmt das nicht mit der zuletzt zugesendeten Version überein,
            wurde die Datei entweder nicht ersetzt oder die Ressource nicht neu gestartet).
        </p>
        <button class="btn" id="console-refresh">Aktualisieren</button>
        <div class="section">${table(['Zeit', 'Typ', 'Kontext', 'Meldung'], rows)}</div>`;

    document.getElementById('console-refresh').addEventListener('click', () => showView('gf-console'));
};

// =========================================================
// ACTIONS
// =========================================================

const Actions = {};

Actions.login = async () => {
    const username = document.getElementById('login-username').value.trim();
    const password = document.getElementById('login-password').value;
    const errEl = document.getElementById('login-error');
    errEl.classList.add('hidden');

    if (!username || !password) {
        errEl.textContent = 'Bitte Name und Passwort eingeben.';
        errEl.classList.remove('hidden');
        return;
    }

    const res = await rpc('session:login', { username, password });
    if (!res || !res.ok) {
        errEl.textContent = translateError(res && res.error);
        errEl.classList.remove('hidden');
        return;
    }

    const data = res.result;
    State.employee = data.employee;
    State.role = data.employee.role;
    State.config = data;
    syncRadioChannelDefaultOnce();
    hideAllScreens();
    document.getElementById('boot-screen').classList.remove('hidden');
    boot(data);
};

Actions.logout = async () => {
    closeModal();
    await call('session:logout');
    document.getElementById('main-ui').classList.add('hidden');
    showLoginScreen();
};

Actions.openAccountModal = () => {
    openModal('Mein Konto', escapeHtml(State.employee.name), `
        <label>Aktuelles Passwort</label>
        <input id="account-current-password" type="password" autocomplete="off" />
        <label>Neues Passwort</label>
        <input id="account-new-password" type="password" autocomplete="off" />
    `, `
        <button class="btn btn-danger" onclick="Actions.logout()">Abmelden</button>
        <button class="btn btn-primary" onclick="Actions.submitChangePassword()">Passwort ändern</button>
    `);
};

Actions.submitChangePassword = async () => {
    const currentPassword = modalInputValue('account-current-password');
    const newPassword = modalInputValue('account-new-password');
    await call('me:changePassword', { currentPassword, newPassword });
    closeModal();
    toast('Passwort geändert', '', 'success');
};

Actions.submitVehicleConditionAndClose = async () => {
    const fuel = Number(document.getElementById('condition-fuel').value);
    const notes = document.getElementById('condition-notes').value.trim();
    const needsWorkshop = document.getElementById('condition-workshop').checked;
    await call('driver:reportVehicleCondition', { fuel, notes, needsWorkshop });
    closeModal();
    requestClose();
};

Actions.setDriverStatus = async () => {
    const status = document.getElementById('driver-status-select').value;
    await call('driver:setStatus', { status });
    toast('Status aktualisiert', '', 'success');
    showView('driver-card');
};

Actions.acceptOrder = async (orderId) => {
    await call('driver:acceptOrder', { orderId });
    toast('Auftrag angenommen', `Auftrag #${orderId} wurde angenommen.`, 'success');
    showView('driver-orders');
};

Actions.declineOrder = (orderId) => {
    openModal('Auftrag ablehnen', `Auftrag #${orderId}`, `
        <label>Grund</label>
        <textarea id="decline-reason"></textarea>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-danger" onclick="Actions.confirmDecline(${orderId})">Ablehnen</button>
    `);
};
Actions.confirmDecline = async (orderId) => {
    const reason = modalInputValue('decline-reason');
    await call('driver:declineOrder', { orderId, reason });
    closeModal();
    toast('Auftrag abgelehnt', '', 'success');
    showView('driver-orders');
};

Actions.selfAssignOrder = async (orderId) => {
    await call('driver:selfAssignOrder', { orderId });
    toast('Auftrag übernommen', `Auftrag #${orderId} wurde dir zugewiesen - du kannst ihn jetzt annehmen.`, 'success');
    showView('driver-orders');
};

Actions.setCustomMarker = async (orderId) => {
    await call('driver:setCustomMarker', { orderId });
    toast('Markierung gesetzt', 'Ein Wegpunkt zu deiner aktuellen Position wurde gesetzt.', 'success');
};

Actions.requestCancelOrder = (orderId) => {
    openModal('Auftrag abbrechen', `Auftrag #${orderId}`, `
        <label>Grund</label>
        <textarea id="cancel-order-reason"></textarea>
        <p class="card-hint" style="margin-top:8px;">Ist ein Disponent online, muss er den Abbruch erst genehmigen. Ist niemand online, wird sofort abgebrochen - das kostet der Firma eine Vertragsstrafe.</p>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Zurück</button>
        <button class="btn btn-danger" onclick="Actions.confirmCancelOrderRequest(${orderId})">Abbrechen bestätigen</button>
    `);
};
Actions.confirmCancelOrderRequest = async (orderId) => {
    const reason = modalInputValue('cancel-order-reason');
    const r = await call('driver:requestCancelOrder', { orderId, reason });
    closeModal();
    if (r.pending) {
        toast('Abbruch angefragt', 'Warte auf Genehmigung des Disponenten.', 'info');
    } else {
        toast('Auftrag abgebrochen', `Vertragsstrafe für die Firma: ${formatMoney(r.penalty)}`, 'error');
    }
    showView('driver-orders');
};

Actions.resolveCancelRequest = async (requestId, approve) => {
    await call('dispatch:resolveCancelRequest', { requestId, approve });
    toast(approve ? 'Abbruch genehmigt' : 'Abbruch abgelehnt', '', approve ? 'success' : 'info');
    showView('dispatch-orders');
};

function trailerTypeLabel(trailerTypes, key) {
    return (trailerTypes.find((t) => t.key === key) || {}).label || key;
}

Actions.openStartShiftModal = async () => {
    const d = await call('driver:shiftOptions');

    if (d.vehicles.length === 0) {
        openModal('Fahrerkarte einstecken', '', `
            <p style="font-size:13px;color:var(--text-1);">Aktuell ist kein freies Fahrzeug verfügbar - entweder sind alle im Einsatz/in Wartung, oder bereits von einem anderen Fahrer im Dienst beansprucht. Wende dich an die Geschäftsführung/Disposition.</p>
        `, `<button class="btn btn-ghost" onclick="closeModal()">Schließen</button>`);
        return;
    }

    const vehicleOptions = d.vehicles.map((v) => `<option value="${v.id}">${escapeHtml(v.name)} (${escapeHtml(v.plate)}, ${escapeHtml(v.vehicle_class)})${v.trailer_id ? ` - bereits angekuppelt: ${escapeHtml(v.trailer_name)}` : ''}</option>`).join('');
    const trailerOptions = d.trailers.map((t) => `<option value="${t.id}">${escapeHtml(t.name)} (${escapeHtml(t.plate)}) - ${escapeHtml(trailerTypeLabel(d.trailerTypes, t.type))}</option>`).join('');

    openModal('Fahrerkarte einstecken', 'Wähle dein Fahrzeug und einen Anhänger.', `
        <label>Fahrzeug</label>
        <select id="shift-vehicle">${vehicleOptions}</select>

        <label style="margin-top:12px;">Anhänger</label>
        <select id="shift-trailer" onchange="document.getElementById('shift-workshop-hint').classList.toggle('hidden', this.value !== '')">
            <option value="">- Werkstattfahrt (kein Anhänger) -</option>
            ${trailerOptions}
        </select>
        <p id="shift-workshop-hint" class="card-hint">Ohne Anhänger kannst du keine Frachtaufträge annehmen, bis du dir einen ankuppelst - für reine Werkstatt-/Testfahrten reicht das aber aus.</p>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmStartShift()">Fahrerkarte einstecken</button>
    `);
};

Actions.confirmStartShift = async () => {
    const vehicleId = Number(modalInputValue('shift-vehicle')) || null;
    const trailerRaw = modalInputValue('shift-trailer');
    const trailerId = trailerRaw ? Number(trailerRaw) : null;
    await call('driver:startShift', { vehicleId, trailerId, workshopMode: !trailerId });
    closeModal();
    toast('Fahrerkarte eingesteckt', 'Deine Fahrt hat begonnen - Lenk-/Ruhezeiten werden erfasst.', 'success');
    showView('driver-card');
};

Actions.endShift = async () => {
    await call('driver:endShift');
    toast('Fahrerkarte abgezogen', 'Deine Fahrt wurde beendet.', 'info');
    showView('driver-card');
};

// Rein clientseitig (nuiPost statt call()/rpc()) - der Kanal wird direkt an
// client/cl_radio.lua weitergereicht, das ihn bei pma-voice einstellt.
// Kein Server-Roundtrip nötig, daher auch keine Fehlerbehandlung über
// call()/toast() - optimistisches, sofortiges UI-Update reicht (schneller
// Kanalwechsel per Touch war explizit gewünscht).
Actions.setRadioChannel = (ch) => {
    const range = radioChannelRange();
    if (ch < range.min || ch > range.max) return;
    currentRadioChannel = ch;
    nuiPost('radioSetChannel', { channel: ch });
    updateRadioDockBadge();
    if (State.currentView === 'funk') showView('funk');
};

Actions.markRead = async (id) => {
    await call('driver:markMessageRead', { notificationId: id });
    showView('driver-messages');
};

Actions.messageDriver = (driverId, driverName) => {
    openModal('Nachricht senden', driverName, `
        <label>Nachricht</label>
        <textarea id="message-text"></textarea>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmMessageDriver(${driverId})">Senden</button>
    `);
};
Actions.confirmMessageDriver = async (driverId) => {
    const message = modalInputValue('message-text');
    if (!message.trim()) return;
    await call('dispatch:messageDriver', { driverId, message });
    closeModal();
    toast('Nachricht gesendet', '', 'success');
};

Actions.remindDriver = async (driverId) => {
    await call('dispatch:remindDriver', { driverId });
    toast('Erinnerung gesendet', 'Der Fahrer wurde an seine Lenk-/Ruhezeiten erinnert.', 'success');
};

Actions.startDispatchDuty = async () => {
    await call('dispatch:startDuty');
    toast('Dienst begonnen', 'Fahrer können sich offene Aufträge jetzt nicht mehr selbst zuweisen.', 'success');
    showView('dispatch-duty');
};
Actions.endDispatchDuty = async () => {
    await call('dispatch:endDuty');
    toast('Dienst beendet', '', 'success');
    showView('dispatch-duty');
};

Actions.openDispatchModal = (orderId, requiresPermission) => {
    const hasPerm = (d) => !requiresPermission || (d.permissions || '').split(',').includes(requiresPermission);
    const drivers = (window.__availableDrivers || []).filter((d) => d.current_status === 'verfuegbar' && hasPerm(d));
    const options = drivers.map((d) => `<option value="${d.driver_id}">${escapeHtml(d.name)}${d.vehicle_name ? ` - ${escapeHtml(d.vehicle_name)} (${escapeHtml(d.vehicle_plate)})` : ' - kein Fahrzeug'}</option>`).join('');
    const hint = requiresPermission ? `<p class="card-hint" style="margin:0 0 10px;">Dieser Auftrag erfordert die Berechtigung "${escapeHtml(requiresPermission)}" - nur berechtigte, verfügbare Fahrer werden angezeigt.</p>` : '';
    openModal('Auftrag disponieren', `Auftrag #${orderId}`, `
        ${hint}
        <label>Fahrer</label>
        <select id="dispatch-driver">${options || '<option value="">Kein berechtigter/verfügbarer Fahrer</option>'}</select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmDispatch(${orderId})">Zuweisen</button>
    `);
};
Actions.confirmDispatch = async (orderId) => {
    const driverId = Number(modalInputValue('dispatch-driver'));
    if (!driverId) return;
    await call('dispatch:assignOrder', { orderId, driverId });
    closeModal();
    toast('Auftrag disponiert', '', 'success');
    showView('dispatch-orders');
};

Actions.openReassignModal = (orderId) => {
    const drivers = (window.__availableDrivers || []);
    const options = drivers.map((d) => `<option value="${d.driver_id}">${escapeHtml(d.name)}</option>`).join('');
    openModal('Auftrag neu zuweisen', `Auftrag #${orderId}`, `
        <label>Neuer Fahrer</label>
        <select id="reassign-driver">${options}</select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmReassign(${orderId})">Zuweisen</button>
    `);
};
Actions.confirmReassign = async (orderId) => {
    const driverId = Number(modalInputValue('reassign-driver'));
    if (!driverId) return;
    await call('dispatch:reassignOrder', { orderId, driverId });
    closeModal();
    toast('Auftrag neu zugewiesen', '', 'success');
    showView('dispatch-orders');
};

Actions.cancelOrder = (orderId) => {
    openModal('Auftrag abbrechen', `Auftrag #${orderId}`, `
        <label>Grund</label>
        <textarea id="cancel-reason"></textarea>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-danger" onclick="Actions.confirmCancelOrder(${orderId})">Auftrag abbrechen</button>
    `);
};
Actions.confirmCancelOrder = async (orderId) => {
    const reason = modalInputValue('cancel-reason');
    await call('dispatch:cancelOrder', { orderId, reason });
    closeModal();
    toast('Auftrag abgebrochen', '', 'success');
    showView('dispatch-orders');
};

Actions.openHireModal = async () => {
    const rolesRes = await call('roles:list');
    const roleOptions = rolesRes.roles.map((r) => `<option value="${r.key}">${escapeHtml(r.label)}</option>`).join('');
    openModal('Mitarbeiter einstellen', 'Legt ein neues Mitarbeiterkonto mit Login-Name und Passwort an - die Person muss dafür nicht online sein.', `
        <label>Anzeigename</label>
        <input id="hire-name" type="text" />
        <label>Login-Name</label>
        <input id="hire-username" type="text" autocomplete="off" />
        <label>Passwort</label>
        <input id="hire-password" type="password" autocomplete="off" />
        <label>Rolle</label>
        <select id="hire-role">${roleOptions}</select>
        <label>Discord-ID <span style="font-weight:400;color:var(--text-2);">(optional, nur für Website-Sync)</span></label>
        <input id="hire-discord-id" type="text" autocomplete="off" placeholder="z.B. 123456789012345678" />
        <label>Führerscheinklassen <span style="font-weight:400;color:var(--text-2);">(nur relevant, falls die Rolle Fahrerfunktionen hat)</span></label>
        <div class="form-row" style="flex-wrap:wrap;">${(State.config.driverPermissions || []).map((p) => `
            <label style="display:flex;align-items:center;gap:6px;font-size:12.5px;font-weight:400;">
                <input type="checkbox" class="hire-driver-perm" value="${escapeHtml(p.key)}" style="width:auto;" />
                ${escapeHtml(p.label)}
            </label>`).join('')}</div>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmHire()">Einstellen</button>
    `);
};
Actions.confirmHire = async () => {
    const name = modalInputValue('hire-name').trim();
    const username = modalInputValue('hire-username').trim();
    const password = modalInputValue('hire-password');
    const role = modalInputValue('hire-role');
    const discordId = modalInputValue('hire-discord-id').trim();
    const driverPermissions = Array.from(document.querySelectorAll('.hire-driver-perm:checked')).map((el) => el.value);
    if (!name || !username || !password) { toast('Fehler', 'Bitte Anzeigename, Login-Name und Passwort ausfüllen.', 'error'); return; }
    await call('gf:employees:hire', { name, username, password, role, discordId, driverPermissions });
    closeModal();
    toast('Mitarbeiter eingestellt', '', 'success');
    showView('gf-employees');
};

Actions.openResetPasswordModal = (employeeId, name) => {
    openModal('Passwort zurücksetzen', name, `
        <label>Neues Passwort</label>
        <input id="reset-password-value" type="password" autocomplete="off" />
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmResetPassword(${employeeId})">Zurücksetzen</button>
    `);
};
Actions.confirmResetPassword = async (employeeId) => {
    const newPassword = modalInputValue('reset-password-value');
    if (!newPassword) { toast('Fehler', 'Bitte ein neues Passwort eingeben.', 'error'); return; }
    await call('gf:employees:resetPassword', { employeeId, newPassword });
    closeModal();
    toast('Passwort zurückgesetzt', '', 'success');
};

Actions.openSetDiscordIdModal = (employeeId, name, currentDiscordId) => {
    openModal('Discord-ID verknüpfen', `${escapeHtml(name)} - nur relevant für den Website-Sync (Config.Website): verknüpft das Konto mit dem Discord-Login der Speditions-Website.`, `
        <label>Discord-Nutzer-ID</label>
        <input id="discord-id-value" type="text" autocomplete="off" placeholder="z.B. 123456789012345678" value="${escapeHtml(currentDiscordId || '')}" />
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmSetDiscordId(${employeeId})">Speichern</button>
    `);
};
Actions.confirmSetDiscordId = async (employeeId) => {
    const discordId = modalInputValue('discord-id-value').trim();
    await call('gf:employees:setDiscordId', { employeeId, discordId });
    closeModal();
    toast('Discord-ID gespeichert', '', 'success');
    showView('gf-employees');
};

Actions.changeRole = async (employeeId, role) => {
    await call('gf:employees:changeRole', { employeeId, role });
    toast('Rolle geändert', '', 'success');
    showView('gf-employees');
};

Actions.toggleEmployeeStatus = async (employeeId, status) => {
    await call('gf:employees:setStatus', { employeeId, status });
    toast('Status geändert', '', 'success');
    showView('gf-employees');
};

Actions.openCreateRoleModal = async () => {
    const d = await call('roles:list');
    openModal('Rolle anlegen', 'Name und Berechtigungen der neuen Rolle festlegen.', `
        <label>Name</label>
        <input id="role-label" type="text" />
        <div id="role-perm-list">${permissionCheckboxesHtml(d.permissionCatalog, [])}</div>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmCreateRole()">Anlegen</button>
    `);
};
Actions.confirmCreateRole = async () => {
    const label = modalInputValue('role-label').trim();
    const permissions = Array.from(document.querySelectorAll('#role-perm-list .role-perm-checkbox:checked')).map((el) => el.value);
    if (!label) { toast('Fehler', 'Bitte einen Namen eingeben.', 'error'); return; }
    if (!permissions.length) { toast('Fehler', 'Bitte mindestens eine Berechtigung auswählen.', 'error'); return; }
    await call('gf:roles:create', { label, permissions });
    closeModal();
    toast('Rolle angelegt', '', 'success');
    showView('gf-employees');
};

Actions.openEditRoleModal = async (roleKey) => {
    const d = await call('roles:list');
    const role = d.roles.find((r) => r.key === roleKey);
    if (!role) return;
    openModal(`Rolle bearbeiten - ${escapeHtml(role.label)}`, role.isBuiltin ? 'Mitgelieferte Basisrolle - der Rollenschlüssel bleibt fix, Name und Berechtigungen sind aber anpassbar.' : '', `
        <label>Name</label>
        <input id="role-label" type="text" value="${escapeHtml(role.label)}" />
        <div id="role-perm-list">${permissionCheckboxesHtml(d.permissionCatalog, role.permissions)}</div>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmEditRole('${roleKey}')">Speichern</button>
    `);
};
Actions.confirmEditRole = async (roleKey) => {
    const label = modalInputValue('role-label').trim();
    const permissions = Array.from(document.querySelectorAll('#role-perm-list .role-perm-checkbox:checked')).map((el) => el.value);
    if (!label) { toast('Fehler', 'Bitte einen Namen eingeben.', 'error'); return; }
    if (!permissions.length) { toast('Fehler', 'Bitte mindestens eine Berechtigung auswählen.', 'error'); return; }
    await call('gf:roles:update', { roleKey, label, permissions });
    closeModal();
    toast('Rolle gespeichert', '', 'success');
    showView('gf-employees');
};

Actions.deleteRole = (roleKey, label) => {
    openModal('Rolle löschen', `Rolle "${escapeHtml(label)}" wirklich löschen? Das ist nur möglich, wenn ihr aktuell kein Mitarbeiter zugeordnet ist.`, '', `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-danger" onclick="Actions.confirmDeleteRole('${roleKey}')">Löschen</button>
    `);
};
Actions.confirmDeleteRole = async (roleKey) => {
    await call('gf:roles:delete', { roleKey });
    closeModal();
    toast('Rolle gelöscht', '', 'success');
    showView('gf-employees');
};

Actions.setRoleWebsiteMapping = async (roleKey, websiteRoleKey) => {
    if (!websiteRoleKey) return; // "— keine —" ausgewählt: keine Aktion, Zuordnung bleibt wie sie war
    await call('gf:roles:setWebsiteRole', { roleKey, websiteRoleKey });
    toast('Website-Rolle zugeordnet', '', 'success');
};

Actions.openDriverFile = async (driverId) => {
    const f = await call('gf:drivers:file', { driverId });
    const permsHtml = f.permissions.map((p) => `
        <label style="display:flex;align-items:center;gap:8px;font-size:13px;color:var(--text-0);margin:6px 0;">
            <input type="checkbox" style="width:auto;" ${p.granted ? 'checked' : ''} onchange="Actions.togglePermission(${driverId}, '${p.key}', this.checked)" />
            ${escapeHtml(p.label)}
        </label>`).join('');

    openModal(`Fahrerakte - ${escapeHtml(f.employee.name)}`, `Mitarbeiter-ID #${f.employee.id}`, `
        <div class="stat-row"><span>Status</span><span>${badge(DRIVER_STATUS_META[f.driver.current_status])}</span></div>
        <div class="stat-row"><span>Aufträge</span><span>${f.statistics.total_orders}</span></div>
        <div class="stat-row"><span>Kilometer</span><span>${Number(f.statistics.total_km).toLocaleString('de-DE')} km</span></div>
        <div class="stat-row"><span>Pünktlichkeit</span><span>${f.statistics.punctuality_rate} %</span></div>
        <div class="stat-row"><span>Einnahmen gesamt</span><span>${formatMoney(f.earnings.total)}</span></div>
        <div style="margin-top:14px;">${renderHoursBlock(f.hours)}</div>
        <div style="margin-top:14px;">${permsHtml}</div>
        <label>Verwarnungen / Notizen</label>
        <textarea id="driver-notes">${escapeHtml(f.driver.notes || '')}</textarea>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Schließen</button>
        <button class="btn btn-primary" onclick="Actions.saveDriverNote(${driverId})">Notiz speichern</button>
    `);
};
Actions.togglePermission = async (driverId, key, granted) => {
    await call('gf:drivers:setPermission', { driverId, permissionKey: key, granted });
    toast('Berechtigung aktualisiert', '', 'success');
};
Actions.saveDriverNote = async (driverId) => {
    const note = modalInputValue('driver-notes');
    await call('gf:drivers:setNote', { driverId, note });
    closeModal();
    toast('Notiz gespeichert', '', 'success');
};

Actions.toggleArchivedFleet = () => {
    window.__fleetShowArchived = !window.__fleetShowArchived;
    showView('gf-fleet-hub');
};

Actions.openVehicleCreateModal = () => {
    const classOptions = (State.config.vehicleClasses || []).map((c) => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('');
    openModal('Fahrzeug erstellen', '', `
        <label>Fahrzeugname</label><input id="v-name" type="text" />
        <label>Modell</label><input id="v-model" type="text" />
        <label>Kennzeichen</label><input id="v-plate" type="text" />
        <label>Fahrzeugklasse</label><select id="v-class">${classOptions}</select>
        <div class="form-row">
            <div><label>Kilometerstand</label><input id="v-mileage" type="number" min="0" value="0" /></div>
            <div><label>Tank (%)</label><input id="v-fuel" type="number" min="0" max="100" value="100" /></div>
        </div>
        <label>Fahrgestell-/Fahrzeug-ID</label><input id="v-identifier" type="text" />
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmCreateVehicle()">Fahrzeug erstellen</button>
    `);
};
Actions.confirmCreateVehicle = async () => {
    await call('gf:vehicles:create', {
        name: modalInputValue('v-name'),
        model: modalInputValue('v-model'),
        plate: modalInputValue('v-plate'),
        vehicleClass: modalInputValue('v-class'),
        mileage: Number(modalInputValue('v-mileage')) || 0,
        fuel: Number(modalInputValue('v-fuel')) || 100,
        vehicleIdentifier: modalInputValue('v-identifier'),
    });
    closeModal();
    toast('Fahrzeug erstellt', '', 'success');
    showView('gf-fleet-hub');
};

Actions.openVehicleEditModal = async (vehicleId) => {
    const f = await call('gf:vehicles:file', { vehicleId });
    const v = f.vehicle;
    const classOptions = (State.config.vehicleClasses || []).map((c) => `<option value="${escapeHtml(c)}" ${v.vehicle_class === c ? 'selected' : ''}>${escapeHtml(c)}</option>`).join('');
    const statusOptions = Object.keys(VEHICLE_STATUS_META).map((s) => `<option value="${s}" ${v.status === s ? 'selected' : ''}>${VEHICLE_STATUS_META[s].label}</option>`).join('');

    openModal('Fahrzeug bearbeiten', `${escapeHtml(v.name)} - ${escapeHtml(v.plate)}`, `
        <label>Fahrzeugname</label><input id="v-name" type="text" value="${escapeHtml(v.name)}" />
        <label>Modell</label><input id="v-model" type="text" value="${escapeHtml(v.model)}" />
        <label>Kennzeichen</label><input id="v-plate" type="text" value="${escapeHtml(v.plate)}" />
        <label>Fahrzeugklasse</label><select id="v-class">${classOptions}</select>
        <div class="form-row">
            <div><label>Kilometerstand</label><input id="v-mileage" type="number" min="0" value="${v.mileage}" /></div>
            <div><label>Tank (%)</label><input id="v-fuel" type="number" min="0" max="100" value="${v.fuel}" /></div>
        </div>
        <label>Status</label><select id="v-status">${statusOptions}</select>
        <label>Notizen</label><textarea id="v-notes">${escapeHtml(v.notes || '')}</textarea>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmEditVehicle(${vehicleId})">Speichern</button>
    `);
};
Actions.confirmEditVehicle = async (vehicleId) => {
    await call('gf:vehicles:update', {
        vehicleId,
        name: modalInputValue('v-name'),
        model: modalInputValue('v-model'),
        plate: modalInputValue('v-plate'),
        vehicleClass: modalInputValue('v-class'),
        mileage: Number(modalInputValue('v-mileage')) || 0,
        fuel: Number(modalInputValue('v-fuel')) || 0,
        status: modalInputValue('v-status'),
        notes: modalInputValue('v-notes'),
    });
    closeModal();
    toast('Fahrzeug aktualisiert', '', 'success');
    showView('gf-fleet-hub');
};

Actions.openAssignModal = async (vehicleId) => {
    const drivers = await call('dispatch:drivers');
    const options = drivers.drivers.map((d) => `<option value="${d.driver_id}">${escapeHtml(d.name)}</option>`).join('');
    openModal('Fahrzeug zuweisen', '', `
        <label>Neuer Fahrer</label>
        <select id="assign-driver">
            <option value="">- Zuweisung aufheben -</option>
            ${options}
        </select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmAssignVehicle(${vehicleId})">Zuweisen</button>
    `);
};
Actions.confirmAssignVehicle = async (vehicleId) => {
    const driverId = Number(modalInputValue('assign-driver')) || null;
    await call('gf:vehicles:assign', { vehicleId, driverId });
    closeModal();
    toast('Fahrzeug zugewiesen', '', 'success');
    showView('gf-fleet-hub');
};

Actions.openDeleteVehicleModal = (vehicleId) => {
    openModal('Fahrzeug löschen?', 'Diese Aktion wird serverseitig geprüft.', `
        <p style="font-size:13px;color:var(--text-1);">Möchtest du dieses Fahrzeug wirklich aus dem Fuhrpark entfernen?
        Standardmäßig wird es archiviert, damit die Fahrzeughistorie erhalten bleibt.</p>
        <label style="display:flex;align-items:center;gap:8px;">
            <input type="checkbox" id="v-hard-delete" style="width:auto;" />
            <span style="font-size:12.5px;">Endgültig löschen (nur möglich, wenn keine Auftragshistorie vorhanden ist)</span>
        </label>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-danger" onclick="Actions.confirmDeleteVehicle(${vehicleId})">Löschen</button>
    `);
};
Actions.confirmDeleteVehicle = async (vehicleId) => {
    const hard = document.getElementById('v-hard-delete').checked;
    const r = await call('gf:vehicles:delete', { vehicleId, mode: hard ? 'hard' : 'archive' });
    closeModal();
    if (r.forced) {
        toast('Fahrzeug archiviert', 'Endgültiges Löschen war wegen vorhandener Auftragshistorie nicht möglich.', 'info');
    } else {
        toast(r.mode === 'hard' ? 'Fahrzeug gelöscht' : 'Fahrzeug archiviert', '', 'success');
    }
    showView('gf-fleet-hub');
};

Actions.reactivateVehicle = async (vehicleId) => {
    await call('gf:vehicles:reactivate', { vehicleId });
    toast('Fahrzeug reaktiviert', '', 'success');
    showView('gf-fleet-hub');
};

// ---------------------------------------------------------
// Anhänger
// ---------------------------------------------------------

function trailerTypeOptions(trailerTypes, selectedKey) {
    return trailerTypes.map((t) => `<option value="${t.key}" ${t.key === selectedKey ? 'selected' : ''}>${escapeHtml(t.label)}</option>`).join('');
}

Actions.openTrailerCreateModal = async () => {
    const d = await call('gf:trailers:list');
    openModal('Anhänger erstellen', '', `
        <label>Name</label><input id="tr-name" type="text" />
        <label>Kennzeichen</label><input id="tr-plate" type="text" />
        <label>Typ</label><select id="tr-type">${trailerTypeOptions(d.trailerTypes)}</select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmCreateTrailer()">Anhänger erstellen</button>
    `);
};
Actions.confirmCreateTrailer = async () => {
    await call('gf:trailers:create', {
        name: modalInputValue('tr-name'),
        plate: modalInputValue('tr-plate'),
        type: modalInputValue('tr-type'),
    });
    closeModal();
    toast('Anhänger erstellt', '', 'success');
    showView('gf-fleet-hub');
};

Actions.openTrailerEditModal = async (trailerId) => {
    const d = await call('gf:trailers:list');
    const t = d.trailers.find((x) => x.id === trailerId);
    if (!t) return;
    const statusOptions = Object.keys(VEHICLE_STATUS_META).map((s) => `<option value="${s}" ${t.status === s ? 'selected' : ''}>${VEHICLE_STATUS_META[s].label}</option>`).join('');
    openModal('Anhänger bearbeiten', `${escapeHtml(t.name)} - ${escapeHtml(t.plate)}`, `
        <label>Name</label><input id="tr-name" type="text" value="${escapeHtml(t.name)}" />
        <label>Kennzeichen</label><input id="tr-plate" type="text" value="${escapeHtml(t.plate)}" />
        <label>Typ</label><select id="tr-type">${trailerTypeOptions(d.trailerTypes, t.type)}</select>
        <label>Status</label><select id="tr-status">${statusOptions}</select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmEditTrailer(${trailerId})">Speichern</button>
    `);
};
Actions.confirmEditTrailer = async (trailerId) => {
    await call('gf:trailers:update', {
        trailerId,
        name: modalInputValue('tr-name'),
        plate: modalInputValue('tr-plate'),
        type: modalInputValue('tr-type'),
        status: modalInputValue('tr-status'),
    });
    closeModal();
    toast('Anhänger aktualisiert', '', 'success');
    showView('gf-fleet-hub');
};

Actions.openTrailerAssignModal = async (trailerId) => {
    const d = await call('gf:vehicles:list');
    const options = d.vehicles.filter((v) => !v.archived).map((v) => `<option value="${v.id}">${escapeHtml(v.name)} (${escapeHtml(v.plate)})</option>`).join('');
    openModal('Anhänger ankuppeln', '', `
        <label>Fahrzeug</label>
        <select id="tr-assign-vehicle">${options}</select>
        <p class="card-hint">Ein bereits an dieses Fahrzeug gekuppelter Anhänger wird automatisch abgekuppelt.</p>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmTrailerAssign(${trailerId}, Number(modalInputValue('tr-assign-vehicle')))">Ankuppeln</button>
    `);
};
Actions.confirmTrailerAssign = async (trailerId, vehicleId) => {
    await call('gf:trailers:assign', { trailerId, vehicleId });
    closeModal();
    toast(vehicleId ? 'Anhänger angekuppelt' : 'Anhänger abgekuppelt', '', 'success');
    showView('gf-fleet-hub');
};

Actions.confirmDeleteTrailer = (trailerId) => {
    openConfirmModal('Anhänger archivieren?', 'Diesen Anhänger wirklich archivieren?', 'Archivieren', `Actions.reallyDeleteTrailer(${trailerId})`);
};
Actions.reallyDeleteTrailer = async (trailerId) => {
    await call('gf:trailers:delete', { trailerId, mode: 'archive' });
    closeModal();
    toast('Anhänger archiviert', '', 'success');
    showView('gf-fleet-hub');
};

// ---------------------------------------------------------
// Orte
// ---------------------------------------------------------

function cargoCheckboxes(prefix, cargoTypes, selectedList) {
    const selected = new Set(selectedList || []);
    return cargoTypes.map((c) => `
        <label style="display:flex;align-items:center;gap:6px;font-size:12.5px;font-weight:400;">
            <input type="checkbox" class="${prefix}-cargo" value="${escapeHtml(c)}" style="width:auto;" ${selected.has(c) ? 'checked' : ''} />
            ${escapeHtml(c)}
        </label>`).join('');
}

function readCheckedCargo(prefix) {
    return Array.from(document.querySelectorAll(`.${prefix}-cargo:checked`)).map((el) => el.value);
}

function locationFormFields(l) {
    const cargoTypes = State.config.cargoTypes || [];
    l = l || {};
    return `
        <label>Name</label><input id="loc-name" type="text" value="${escapeHtml(l.name || '')}" />
        <div class="btn-row" style="margin:4px 0;">
            <button type="button" class="btn btn-sm" onclick="Actions.useCurrentPositionForLocation()">Aktuelle Position übernehmen</button>
            <span id="loc-pos-hint" class="card-hint">${l.coords ? `x=${l.coords.x.toFixed(1)}, y=${l.coords.y.toFixed(1)}, z=${l.coords.z.toFixed(1)}` : 'Noch keine Position gesetzt.'}</span>
        </div>
        <input id="loc-x" type="hidden" value="${l.coords ? l.coords.x : ''}" />
        <input id="loc-y" type="hidden" value="${l.coords ? l.coords.y : ''}" />
        <input id="loc-z" type="hidden" value="${l.coords ? l.coords.z : ''}" />
        <input id="loc-heading" type="hidden" value="${l.coords ? l.coords.w : 0}" />
        <label>Quelle (hier abholbare Frachtarten)</label>
        <div class="form-row" style="flex-wrap:wrap;">${cargoCheckboxes('loc-src', cargoTypes, l.sourceCargo)}</div>
        <label>Ziel (hier anlieferbare Frachtarten)</label>
        <div class="form-row" style="flex-wrap:wrap;">${cargoCheckboxes('loc-dst', cargoTypes, l.destCargo)}</div>
    `;
}

Actions.useCurrentPositionForLocation = async () => {
    const pos = await call('gf:locations:currentPosition');
    document.getElementById('loc-x').value = pos.x;
    document.getElementById('loc-y').value = pos.y;
    document.getElementById('loc-z').value = pos.z;
    document.getElementById('loc-heading').value = pos.heading;
    document.getElementById('loc-pos-hint').textContent = `x=${pos.x.toFixed(1)}, y=${pos.y.toFixed(1)}, z=${pos.z.toFixed(1)} (übernommen)`;
    toast('Position übernommen', '', 'success');
};

Actions.openLocationCreateModal = () => {
    openModal('Ort erstellen', '', locationFormFields(null), `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmCreateLocation()">Ort erstellen</button>
    `);
};
Actions.confirmCreateLocation = async () => {
    await call('gf:locations:create', {
        name: modalInputValue('loc-name'),
        x: Number(modalInputValue('loc-x')),
        y: Number(modalInputValue('loc-y')),
        z: Number(modalInputValue('loc-z')),
        heading: Number(modalInputValue('loc-heading')) || 0,
        sourceCargo: readCheckedCargo('loc-src'),
        destCargo: readCheckedCargo('loc-dst'),
    });
    closeModal();
    toast('Ort erstellt', '', 'success');
    showView('gf-locations');
};

Actions.openLocationEditModal = async (locationId) => {
    const d = await call('locations:list');
    const l = d.locations.find((x) => x.id === locationId);
    if (!l) return;
    openModal('Ort bearbeiten', escapeHtml(l.name), locationFormFields(l), `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmEditLocation(${locationId})">Speichern</button>
    `);
};
Actions.confirmEditLocation = async (locationId) => {
    await call('gf:locations:update', {
        locationId,
        name: modalInputValue('loc-name'),
        x: Number(modalInputValue('loc-x')),
        y: Number(modalInputValue('loc-y')),
        z: Number(modalInputValue('loc-z')),
        heading: Number(modalInputValue('loc-heading')) || 0,
        sourceCargo: readCheckedCargo('loc-src'),
        destCargo: readCheckedCargo('loc-dst'),
    });
    closeModal();
    toast('Ort aktualisiert', '', 'success');
    showView('gf-locations');
};

Actions.confirmDeleteLocation = (locationId) => {
    openConfirmModal('Ort löschen?', 'Diesen Ort wirklich löschen?', 'Löschen', `Actions.reallyDeleteLocation(${locationId})`);
};
Actions.reallyDeleteLocation = async (locationId) => {
    await call('gf:locations:delete', { locationId });
    closeModal();
    toast('Ort gelöscht', '', 'success');
    showView('gf-locations');
};

// ---------------------------------------------------------
// Frachtarten
// ---------------------------------------------------------

function cargoTypeFormFields(c, trailerTypes) {
    c = c || {};
    return `
        <label>Name</label><input id="ct-name" type="text" value="${escapeHtml(c.name || '')}" />
        <label>Einheit</label><input id="ct-unit" type="text" placeholder="z.B. Stück, kg, Liter" value="${escapeHtml(c.unit || '')}" />
        <div class="form-row">
            <div>
                <label>Menge min.</label>
                <input id="ct-min" type="number" min="1" step="1" value="${c.min != null ? c.min : ''}" />
            </div>
            <div>
                <label>Menge max.</label>
                <input id="ct-max" type="number" min="1" step="1" value="${c.max != null ? c.max : ''}" />
            </div>
        </div>
        <label>Benötigter Anhängertyp</label>
        <select id="ct-trailer-type">${trailerTypeOptions(trailerTypes, c.trailerType)}</select>
        <label style="display:flex;align-items:center;gap:6px;">
            <input id="ct-hazardous" type="checkbox" style="width:auto;" ${c.hazardous ? 'checked' : ''} />
            Gefahrgut (Fahrer benötigt Gefahrgut-Berechtigung)
        </label>
    `;
}

Actions.openCargoTypeCreateModal = async () => {
    const d = await call('gf:trailers:list');
    openModal('Frachtart erstellen', '', cargoTypeFormFields(null, d.trailerTypes), `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmCreateCargoType()">Frachtart erstellen</button>
    `);
};
Actions.confirmCreateCargoType = async () => {
    await call('gf:cargotypes:create', {
        name: modalInputValue('ct-name'),
        unit: modalInputValue('ct-unit'),
        min: Number(modalInputValue('ct-min')),
        max: Number(modalInputValue('ct-max')),
        hazardous: document.getElementById('ct-hazardous').checked,
        trailerType: modalInputValue('ct-trailer-type'),
    });
    closeModal();
    toast('Frachtart erstellt', '', 'success');
    showView('gf-cargo-types');
};

Actions.openCargoTypeEditModal = async (cargoTypeId) => {
    const [d, trailerData] = await Promise.all([call('cargotypes:list'), call('gf:trailers:list')]);
    const c = d.cargoTypes.find((x) => x.id === cargoTypeId);
    if (!c) return;
    openModal('Frachtart bearbeiten', escapeHtml(c.name), cargoTypeFormFields(c, trailerData.trailerTypes), `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmEditCargoType(${cargoTypeId})">Speichern</button>
    `);
};
Actions.confirmEditCargoType = async (cargoTypeId) => {
    await call('gf:cargotypes:update', {
        cargoTypeId,
        name: modalInputValue('ct-name'),
        unit: modalInputValue('ct-unit'),
        min: Number(modalInputValue('ct-min')),
        max: Number(modalInputValue('ct-max')),
        hazardous: document.getElementById('ct-hazardous').checked,
        trailerType: modalInputValue('ct-trailer-type'),
    });
    closeModal();
    toast('Frachtart aktualisiert', '', 'success');
    showView('gf-cargo-types');
};

Actions.confirmDeleteCargoType = (cargoTypeId) => {
    openConfirmModal('Frachtart löschen?', 'Diese Frachtart wirklich löschen? Bereits laufende Aufträge mit dieser Frachtart bleiben unberührt.', 'Löschen', `Actions.reallyDeleteCargoType(${cargoTypeId})`);
};
Actions.reallyDeleteCargoType = async (cargoTypeId) => {
    await call('gf:cargotypes:delete', { cargoTypeId });
    closeModal();
    toast('Frachtart gelöscht', '', 'success');
    showView('gf-cargo-types');
};

Actions.openVehicleFile = async (vehicleId) => {
    const f = await call('gf:vehicles:file', { vehicleId });
    const v = f.vehicle;
    const ordersHtml = f.recentOrders.map((o) => `<div class="stat-row"><span>#${o.id} ${o.driver_name ? escapeHtml(o.driver_name) : ''}</span><span>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</span></div>`).join('') || '<div class="card-hint">Keine Aufträge.</div>';

    openModal(`Fahrzeugakte - ${escapeHtml(v.name)}`, escapeHtml(v.plate), `
        <div class="stat-row"><span>Kilometer</span><span>${Number(v.mileage).toLocaleString('de-DE')} km</span></div>
        <div class="stat-row"><span>Abgeschlossene Aufträge</span><span>${f.totalOrders}</span></div>
        <div class="stat-row"><span>Gefahrene Strecke</span><span>${Number(f.totalKm).toLocaleString('de-DE')} km</span></div>
        <div class="stat-row"><span>Aktueller Fahrer</span><span>${f.currentDriverName ? escapeHtml(f.currentDriverName) : '-'}</span></div>
        <h4 style="margin:16px 0 8px;font-size:11px;text-transform:uppercase;color:var(--text-2);">Letzte Aufträge</h4>
        ${ordersHtml}
    `, `<button class="btn btn-ghost" onclick="closeModal()">Schließen</button>`);
};

Actions.executePayout = async () => {
    const amount = Number(document.getElementById('payout-amount').value);
    const target = document.getElementById('payout-target').value;
    const reason = document.getElementById('payout-reason').value;
    if (!amount || amount <= 0) { toast('Ungültiger Betrag', 'Bitte einen gültigen Auszahlungsbetrag angeben.', 'error'); return; }
    window.__payoutTarget = target;
    const result = await call('gf:payout:execute', { amount, target, reason });
    if (result.cashGiven) {
        toast('Auszahlung durchgeführt', `${formatMoney(amount)} als Bargeld erhalten.`, 'success');
    } else {
        toast('Achtung: kein Bargeld erhalten!', `${formatMoney(amount)} wurde verbucht, aber die Wirtschafts-Anbindung (Config.MoneyBridge) hat kein Bargeld übergeben - Server-Konsole prüfen.`, 'error');
    }
    showView('gf-finance-hub');
};

Actions.executeDeposit = async () => {
    const amount = Number(document.getElementById('deposit-amount').value);
    const source = document.getElementById('deposit-source').value;
    const reason = document.getElementById('deposit-reason').value;
    if (!amount || amount <= 0) { toast('Ungültiger Betrag', 'Bitte einen gültigen Einzahlungsbetrag angeben.', 'error'); return; }
    window.__depositSource = source;
    await call('gf:deposit:execute', { amount, source, reason });
    toast('Einzahlung verbucht', `${formatMoney(amount)} Bargeld abgezogen.`, 'success');
    showView('gf-finance-hub');
};

Actions.setWageRate = async (role) => {
    const hourlyRate = Number(document.getElementById(`wage-rate-${role}`).value);
    if (hourlyRate === null || hourlyRate < 0 || Number.isNaN(hourlyRate)) {
        toast('Ungültiger Betrag', 'Bitte einen gültigen Stundenlohn angeben.', 'error');
        return;
    }
    await call('gf:payroll:setRate', { role, hourlyRate });
    toast('Stundenlohn gespeichert', '', 'success');
    showView('gf-finance-hub');
};

Actions.payEmployee = async (employeeId, name) => {
    const result = await call('gf:payroll:pay', { employeeId });
    if (result.cashGiven) {
        toast('Gehalt ausgezahlt', `${formatMoney(result.amount)} an ${name} als Bargeld übergeben.`, 'success');
    } else {
        toast('Achtung: kein Bargeld erhalten!', `${formatMoney(result.amount)} für ${name} wurde verbucht, aber NICHT als Bargeld übergeben (nicht online, oder Config.MoneyBridge funktioniert nicht - Server-Konsole prüfen).`, 'error');
    }
    showView('gf-finance-hub');
};

Actions.filterOrders = (status) => {
    window.__orderStatusFilter = status;
    showView('gf-orders');
};
