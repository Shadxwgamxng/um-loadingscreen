/* =========================================================
   Speditions-Tablet - NUI Frontend
   ========================================================= */

const State = {
    employee: null,
    role: null,
    config: null,
    currentView: null,
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
    not_logged_in: 'Dein Charakter hat kein Mitarbeiterkonto.',
    player_not_online: 'Dieser Spieler ist nicht online.',
    employee_already_exists: 'Dieser Charakter hat bereits ein Mitarbeiterkonto.',
    employee_not_found: 'Mitarbeiter nicht gefunden.',
    already_clocked_in: 'Du bist bereits eingestempelt.',
    not_clocked_in: 'Du bist nicht eingestempelt.',
    nothing_to_pay: 'Für diesen Mitarbeiter steht aktuell kein Gehalt aus.',
    dispatcher_available: 'Ein Disponent ist gerade online - Aufträge werden von ihm zugewiesen.',
    insufficient_player_cash: 'Du hast nicht genug Bargeld dabei, um diesen Betrag einzuzahlen.',
    employee_inactive: 'Dieses Mitarbeiterkonto ist deaktiviert.',
    forbidden_role: 'Keine Berechtigung für diese Aktion.',
    insufficient_balance: 'Nicht genügend Guthaben für diese Auszahlung.',
    invalid_amount: 'Ungültiger Betrag.',
    missing_reason: 'Bitte einen Grund angeben.',
    missing_fields: 'Bitte alle Pflichtfelder ausfüllen.',
    plate_taken: 'Dieses Kennzeichen ist bereits vergeben.',
    vehicle_not_found: 'Fahrzeug nicht gefunden.',
    vehicle_unavailable: 'Fahrzeug steht aktuell nicht zur Verfügung.',
    vehicle_archived: 'Fahrzeug ist archiviert.',
    driver_not_found: 'Fahrer nicht gefunden.',
    order_not_found: 'Auftrag nicht gefunden.',
    order_not_open: 'Auftrag ist nicht mehr offen.',
    order_not_pending: 'Auftrag befindet sich nicht im richtigen Status.',
    order_not_in_transit: 'Auftrag ist nicht unterwegs.',
    order_not_reassignable: 'Auftrag kann nicht neu zugewiesen werden.',
    order_already_closed: 'Auftrag ist bereits abgeschlossen.',
    not_your_order: 'Das ist nicht dein Auftrag.',
    driver_missing_permission: 'Dieser Fahrer besitzt nicht die für den Auftrag erforderliche Berechtigung (z.B. Gefahrgut).',
    last_management_account: 'Es muss mindestens eine aktive Geschäftsführung geben.',
    invalid_status_transition: 'Ungültiger Statuswechsel.',
    invalid_status: 'Ungültiger Status.',
    invalid_role: 'Ungültige Rolle.',
    invalid_permission: 'Ungültige Berechtigung.',
    unknown_action: 'Unbekannte Aktion.',
    connection_error: 'Keine Verbindung zum Server.',
    server_error: 'Serverfehler. Bitte später erneut versuchen.',
};

function translateError(code) {
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
    const d = new Date(String(s).replace(' ', 'T'));
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
    beladen: { label: 'Beladen', dot: 'blue' },
    unterwegs: { label: 'Unterwegs', dot: 'blue' },
    abgeschlossen: { label: 'Abgeschlossen', dot: 'green' },
    abgebrochen: { label: 'Abgebrochen', dot: 'red' },
    abgelehnt: { label: 'Abgelehnt', dot: 'red' },
};

const EMPLOYMENT_STATUS_META = {
    aktiv: { label: 'Aktiv', dot: 'green' },
    inaktiv: { label: 'Inaktiv', dot: 'gray' },
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

// ---------------------------------------------------------
// Navigation
// ---------------------------------------------------------

const NAV = {
    fahrer: [
        { id: 'driver-card', label: 'Fahrerkarte', icon: '🪪' },
        { id: 'driver-orders', label: 'Aufträge', icon: '📦' },
        { id: 'driver-history', label: 'Historie', icon: '🕓' },
        { id: 'driver-earnings', label: 'Einnahmen', icon: '💰' },
        { id: 'driver-vehicle', label: 'Mein Fahrzeug', icon: '🚛' },
        { id: 'driver-messages', label: 'Nachrichten', icon: '✉️' },
    ],
    disponent: [
        { id: 'dispatch-drivers', label: 'Fahrerübersicht', icon: '👥' },
        { id: 'dispatch-pool', label: 'Auftragspool', icon: '📋' },
        { id: 'dispatch-active', label: 'Aktive Aufträge', icon: '🚚' },
        { id: 'dispatch-completed', label: 'Abgeschlossen', icon: '✅' },
        { id: 'dispatch-revenue', label: 'Unternehmensumsatz', icon: '📈' },
    ],
    geschaeftsfuehrung: [
        { id: 'gf-dashboard', label: 'Dashboard', icon: '📊' },
        { id: 'gf-employees', label: 'Mitarbeiter', icon: '🧑‍💼' },
        { id: 'gf-drivers', label: 'Fahrerakten', icon: '🪪' },
        { id: 'gf-fleet', label: 'Fuhrpark', icon: '🚛' },
        { id: 'gf-finance', label: 'Finanzen', icon: '💰' },
        { id: 'gf-payouts', label: 'Ein-/Auszahlungen', icon: '🏦' },
        { id: 'gf-payroll', label: 'Gehälter', icon: '💵' },
        { id: 'gf-orders', label: 'Aufträge', icon: '📦' },
        { id: 'gf-log', label: 'Protokoll', icon: '📜' },
    ],
};

function buildSidebar(role) {
    const sidebar = document.getElementById('sidebar');
    sidebar.innerHTML = '';
    (NAV[role] || []).forEach((item) => {
        const el = document.createElement('div');
        el.className = 'nav-item';
        el.dataset.view = item.id;
        el.innerHTML = `<span>${item.icon}</span><span>${escapeHtml(item.label)}</span>`;
        el.addEventListener('click', () => showView(item.id));
        sidebar.appendChild(el);
    });
}

async function showView(id) {
    State.currentView = id;
    document.querySelectorAll('.nav-item').forEach((el) => el.classList.toggle('active', el.dataset.view === id));
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
    else if (data.type === 'radioInteract') document.getElementById('cb-radio').classList.toggle('cb-radio-focused', !!data.on);
});

document.addEventListener('keydown', (e) => {
    if (!document.getElementById('lock-screen').classList.contains('hidden')) { unlockTablet(); return; }
    if (e.key === 'Escape') requestClose();
});

document.getElementById('lock-screen').addEventListener('click', () => unlockTablet());
document.getElementById('no-account-retry').addEventListener('click', () => unlockTablet());

function requestClose() {
    nuiPost('close', {});
}

async function closeTabletWithVehicleCheck() {
    if (State.role === 'fahrer') {
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
    document.getElementById('no-account-screen').classList.add('hidden');
    document.getElementById('main-ui').classList.add('hidden');
}

function showNoAccount() {
    hideAllScreens();
    document.getElementById('no-account-screen').classList.remove('hidden');
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
        boot(data);
    } else {
        showNoAccount();
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

let clockInterval = null;
function startClock() {
    if (clockInterval) clearInterval(clockInterval);
    const update = () => {
        const now = new Date();
        const time = now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
        const clockEl = document.getElementById('clock');
        if (clockEl) clockEl.textContent = time;
        const lockTimeEl = document.getElementById('lock-time');
        if (lockTimeEl) lockTimeEl.textContent = time;
        const lockDateEl = document.getElementById('lock-date');
        if (lockDateEl) lockDateEl.textContent = now.toLocaleDateString('de-DE', { weekday: 'long', day: '2-digit', month: 'long' });
    };
    update();
    clockInterval = setInterval(update, 15000);
}

function boot(data) {
    document.getElementById('boot-screen').classList.add('hidden');
    document.getElementById('main-ui').classList.remove('hidden');
    document.getElementById('employee-name').textContent = data.employee.name;
    document.getElementById('employee-role').textContent = data.roleLabels[data.employee.role] || data.employee.role;
    document.getElementById('topbar-brand').textContent = State.companyName;
    buildSidebar(data.employee.role);
    const first = (NAV[data.employee.role] || [])[0];
    if (first) showView(first.id);
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

// ---------------------------------------------------------
// CB-Funk - ein-/ausschalten läuft über das Tablet, danach ist das
// Bedienfeld auch bei geschlossenem Tablet sichtbar/verschiebbar
// (siehe Config.CbRadio.interactKey, um es dann noch bedienen zu können).
// ---------------------------------------------------------

const Radio = { on: false, channel: 1, volume: 80, muted: false };

function radioRefreshUi() {
    document.getElementById('cb-channel').textContent = String(Radio.channel).padStart(2, '0');
    document.getElementById('cb-lcd-mute').classList.toggle('active', Radio.muted);
    document.getElementById('cb-mute-btn').classList.toggle('active', Radio.muted);
    const notch = document.querySelector('#cb-knob-vol .cb-knob-notch');
    if (notch) notch.style.transform = `translateX(-50%) rotate(${-135 + (Radio.volume / 100) * 270}deg)`;
    document.getElementById('cb-radio-dot').classList.toggle('on', Radio.on);
    document.getElementById('cb-radio-toggle-label').textContent = Radio.on ? `CB-Funk (Kanal ${Radio.channel})` : 'CB-Funk';
}

document.getElementById('cb-radio-toggle').addEventListener('click', async () => {
    if (Radio.on) {
        await call('me:radio:powerOff');
        Radio.on = false;
        await nuiPost('radioPower', { on: false });
        document.getElementById('cb-radio').classList.add('hidden');
        toast('CB-Funk ausgeschaltet', '', 'info');
    } else {
        await call('me:radio:powerOn');
        Radio.on = true;
        await nuiPost('radioPower', { on: true, channel: Radio.channel, volume: Radio.volume });
        document.getElementById('cb-radio').classList.remove('hidden');
        toast('CB-Funk eingeschaltet', `Kanal ${String(Radio.channel).padStart(2, '0')}`, 'success');
    }
    radioRefreshUi();
});

document.getElementById('cb-ch-up').addEventListener('click', () => {
    Radio.channel = Radio.channel >= 9 ? 1 : Radio.channel + 1;
    nuiPost('radioSetChannel', { channel: Radio.channel });
    radioRefreshUi();
});
document.getElementById('cb-ch-down').addEventListener('click', () => {
    Radio.channel = Radio.channel <= 1 ? 9 : Radio.channel - 1;
    nuiPost('radioSetChannel', { channel: Radio.channel });
    radioRefreshUi();
});

document.getElementById('cb-knob-vol').addEventListener('wheel', (e) => {
    e.preventDefault();
    Radio.volume = Math.max(0, Math.min(100, Radio.volume + (e.deltaY < 0 ? 5 : -5)));
    nuiPost('radioSetVolume', { volume: Radio.volume });
    radioRefreshUi();
}, { passive: false });

document.getElementById('cb-mute-btn').addEventListener('click', () => {
    Radio.muted = !Radio.muted;
    nuiPost('radioToggleMute', {});
    radioRefreshUi();
});

// Ziehen: nur auslösen, wenn NICHT auf einem der (nicht-dekorativen)
// Bedienelemente geklickt wird - der Rest des Foto-Nachbaus dient als
// Ziehfläche.
(() => {
    const radioEl = document.getElementById('cb-radio');
    const body = document.getElementById('cb-radio-drag-handle');
    let dragging = false, offsetX = 0, offsetY = 0;

    body.addEventListener('mousedown', (e) => {
        if (e.target.closest('.cb-knob-vol, .cb-btn, .cb-ch-btn')) return;
        dragging = true;
        const rect = radioEl.getBoundingClientRect();
        offsetX = e.clientX - rect.left;
        offsetY = e.clientY - rect.top;
        e.preventDefault();
    });
    document.addEventListener('mousemove', (e) => {
        if (!dragging) return;
        radioEl.style.left = `${e.clientX - offsetX}px`;
        radioEl.style.top = `${e.clientY - offsetY}px`;
        radioEl.style.bottom = 'auto';
    });
    document.addEventListener('mouseup', () => { dragging = false; });
})();

radioRefreshUi();

function handlePush(event, data) {
    const map = {
        'notifications:new': () => { toast(data.title, data.message, 'info'); refreshIfViewing(['driver-messages', 'driver-orders']); },
        'orders:newOpenOrder': () => { toast('Neuer Auftrag', 'Ein neuer Auftrag ist im Pool verfügbar.', 'info'); refreshIfViewing(['dispatch-pool']); },
        'orders:activeChanged': () => refreshIfViewing(['dispatch-active', 'dispatch-pool', 'driver-orders']),
        'orders:completed': () => { toast('Auftrag abgeschlossen', 'Ein Auftrag wurde erfolgreich abgeschlossen.', 'success'); refreshIfViewing(['dispatch-active', 'dispatch-completed', 'gf-dashboard']); },
        'dispatch:driversChanged': () => refreshIfViewing(['dispatch-drivers']),
        'fleet:changed': () => refreshIfViewing(['gf-fleet', 'dispatch-drivers']),
        'finance:balanceChanged': () => refreshIfViewing(['gf-finance', 'gf-dashboard']),
    };
    if (map[event]) map[event]();
}

// =========================================================
// VIEW RENDERERS
// =========================================================

const VIEWS = {};

// ---------- FAHRER ----------

VIEWS['driver-card'] = async (root) => {
    const d = await call('driver:card');
    const emp = d.employee;
    const stats = d.statistics;
    const vehicle = d.vehicle;

    const permsHtml = d.permissions.map((p) => `
        <div class="perm-item ${p.granted ? 'granted' : 'denied'}">
            <span class="mark">${p.granted ? '✓' : '✕'}</span>${escapeHtml(p.label)}
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

VIEWS['driver-orders'] = async (root) => {
    const [d, pool] = await Promise.all([call('driver:myOrders'), call('driver:openOrders')]);

    const rows = d.orders.map((o) => {
        let actions = '';
        if (o.status === 'disponiert') {
            actions = `<button class="btn btn-sm btn-primary" onclick="Actions.acceptOrder(${o.id})">Annehmen</button>
                        <button class="btn btn-sm btn-danger" onclick="Actions.declineOrder(${o.id})">Ablehnen</button>`;
        } else if (o.status === 'angenommen') {
            actions = `<button class="btn btn-sm btn-primary" onclick="Actions.cargoStatus(${o.id}, 'beladen')">Beladen</button>`;
        } else if (o.status === 'beladen') {
            actions = `<button class="btn btn-sm btn-primary" onclick="Actions.cargoStatus(${o.id}, 'unterwegs')">Unterwegs</button>`;
        } else if (o.status === 'unterwegs') {
            actions = `<button class="btn btn-sm btn-primary" onclick="Actions.completeOrder(${o.id})">Abschließen</button>`;
        }
        return `<tr>
            <td>#${o.id}</td>
            <td>${escapeHtml(o.cargo)}</td>
            <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
            <td>${Number(o.distance_km).toLocaleString('de-DE')} km</td>
            <td>${o.vehicle_name ? `${escapeHtml(o.vehicle_name)} (${escapeHtml(o.vehicle_plate)})` : '-'}</td>
            <td>${badge(ORDER_STATUS_META[o.status])}</td>
            <td class="btn-row">${actions}</td>
        </tr>`;
    });

    const poolRows = pool.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}${o.requires_permission ? ' <span class="pill">⚠ Gefahrgut</span>' : ''}</td>
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
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Fahrzeug', 'Status', 'Aktion'], rows)}</div>

        <h1 class="view-title" style="margin-top:24px;">Offener Auftragspool</h1>
        <p class="view-subtitle">${pool.dispatcherAvailable
            ? 'Ein Disponent ist gerade online - Aufträge werden von ihm zugewiesen.'
            : 'Aktuell ist kein Disponent verfügbar - du kannst dir einen offenen Auftrag selbst übernehmen.'}</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Wert', ''], poolRows)}</div>`;
};

VIEWS['driver-history'] = async (root) => {
    const d = await call('driver:history');
    const rows = d.history.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${badge(ORDER_STATUS_META[o.status])}</td>
        <td>${o.status === 'abgeschlossen' ? (o.punctual ? '✅ Pünktlich' : '⚠️ Verspätet') : '-'}</td>
        <td>${o.status === 'abgeschlossen' ? formatMoney(o.value) : '-'}</td>
        <td>${formatDate(o.completed_at || o.created_at, true)}</td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Auftragshistorie</h1>
        <p class="view-subtitle">Deine abgeschlossenen, abgebrochenen und abgelehnten Aufträge.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Status', 'Pünktlichkeit', 'Wert', 'Datum'], rows)}</div>`;
};

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

VIEWS['dispatch-drivers'] = async (root) => {
    const d = await call('dispatch:drivers');
    const rows = d.drivers.map((r) => `<tr>
        <td>${badge(DRIVER_STATUS_META[r.current_status])}</td>
        <td>${escapeHtml(r.name)}</td>
        <td>${r.vehicle_name ? `${escapeHtml(r.vehicle_name)} (${escapeHtml(r.vehicle_plate)})` : '-'}</td>
        <td>${r.vehicle_status ? badge(VEHICLE_STATUS_META[r.vehicle_status]) : '-'}</td>
        <td class="btn-row">
            <button class="btn btn-sm" onclick="Actions.messageDriver(${r.driver_id}, ${JSON.stringify(r.name)})">Nachricht</button>
            <button class="btn btn-sm" onclick="Actions.remindDriver(${r.driver_id})">Lenkzeit erinnern</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Fahrerübersicht</h1>
        <p class="view-subtitle">Alle aktiven Fahrer mit Status und aktuellem Fahrzeug.</p>
        <div class="section">${table(['Status', 'Fahrer', 'Fahrzeug', 'Fahrzeugstatus', ''], rows)}</div>`;
};

VIEWS['dispatch-pool'] = async (root) => {
    const [pool, drivers] = await Promise.all([call('dispatch:openOrders'), call('dispatch:drivers')]);
    window.__availableDrivers = drivers.drivers;

    const rows = pool.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}${o.requires_permission ? ' <span class="pill">⚠ Gefahrgut</span>' : ''}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${Number(o.distance_km).toLocaleString('de-DE')} km</td>
        <td>${formatMoney(o.value)}</td>
        <td><button class="btn btn-sm btn-primary" onclick="Actions.openDispatchModal(${o.id}, ${JSON.stringify(o.requires_permission || null)})">Disponieren</button></td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Auftragspool</h1>
        <p class="view-subtitle">Automatisch generierte Aufträge, die noch keinem Fahrer zugewiesen sind.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Distanz', 'Wert', ''], rows)}</div>`;
};

VIEWS['dispatch-active'] = async (root) => {
    const [active, drivers] = await Promise.all([call('dispatch:activeOrders'), call('dispatch:drivers')]);
    window.__availableDrivers = drivers.drivers;

    const rows = active.orders.map((o) => `<tr>
        <td>#${o.id}</td>
        <td>${escapeHtml(o.cargo)}</td>
        <td>${escapeHtml(o.start_location)} → ${escapeHtml(o.end_location)}</td>
        <td>${o.driver_name ? escapeHtml(o.driver_name) : '-'}</td>
        <td>${o.vehicle_name ? `${escapeHtml(o.vehicle_name)} (${escapeHtml(o.vehicle_plate)})` : '-'}</td>
        <td>${badge(ORDER_STATUS_META[o.status])}</td>
        <td class="btn-row">
            ${['disponiert', 'angenommen', 'beladen'].includes(o.status) ? `<button class="btn btn-sm" onclick="Actions.openReassignModal(${o.id})">Neu zuweisen</button>` : ''}
            <button class="btn btn-sm btn-danger" onclick="Actions.cancelOrder(${o.id})">Abbrechen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Aktive Aufträge</h1>
        <p class="view-subtitle">Live-Überwachung aller disponierten und laufenden Aufträge.</p>
        <div class="section">${table(['#', 'Fracht', 'Strecke', 'Fahrer', 'Fahrzeug', 'Status', 'Aktion'], rows)}</div>`;
};

VIEWS['dispatch-completed'] = async (root) => {
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
};

VIEWS['dispatch-revenue'] = async (root) => {
    const r = await call('dispatch:companyOrdersRevenue');
    root.innerHTML = `
        <h1 class="view-title">Unternehmensumsatz</h1>
        <p class="view-subtitle">Reine Leseansicht - Auszahlungen sind der Geschäftsführung vorbehalten.</p>
        <div class="grid grid-3">
            <div class="card"><div class="card-title">Einnahmen heute</div><div class="card-value">${formatMoney(r.revenueToday)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Woche</div><div class="card-value">${formatMoney(r.revenueWeek)}</div></div>
            <div class="card"><div class="card-title">Einnahmen Monat</div><div class="card-value">${formatMoney(r.revenueMonth)}</div></div>
        </div>`;
};

// ---------- GESCHÄFTSFÜHRUNG ----------

VIEWS['gf-dashboard'] = async (root) => {
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

    const statusOrder = ['offen', 'disponiert', 'angenommen', 'beladen', 'unterwegs', 'abgeschlossen', 'abgebrochen', 'abgelehnt'];
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
};

VIEWS['gf-employees'] = async (root) => {
    const d = await call('gf:employees:list');
    const rows = d.employees.map((e) => `<tr>
        <td>#${e.id}</td>
        <td>${escapeHtml(e.name)}</td>
        <td>
            <select onchange="Actions.changeRole(${e.id}, this.value)">
                <option value="fahrer" ${e.role === 'fahrer' ? 'selected' : ''}>LKW-Fahrer</option>
                <option value="disponent" ${e.role === 'disponent' ? 'selected' : ''}>Disponent</option>
                <option value="geschaeftsfuehrung" ${e.role === 'geschaeftsfuehrung' ? 'selected' : ''}>Geschäftsführung</option>
            </select>
        </td>
        <td>${badge(EMPLOYMENT_STATUS_META[e.status])}</td>
        <td>${formatDate(e.hired_at)}</td>
        <td class="btn-row">
            <button class="btn btn-sm ${e.status === 'aktiv' ? 'btn-danger' : 'btn-primary'}" onclick="Actions.toggleEmployeeStatus(${e.id}, '${e.status === 'aktiv' ? 'inaktiv' : 'aktiv'}')">${e.status === 'aktiv' ? 'Deaktivieren' : 'Aktivieren'}</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Mitarbeiter</h1>
        <p class="view-subtitle">Verwaltung aller Mitarbeiter, Rollen und Grade. Mitarbeiter werden automatisch anhand ihres FiveM-Charakters erkannt.</p>
        <div class="btn-row" style="margin-bottom:14px;"><button class="btn btn-primary" onclick="Actions.openHireModal()">+ Mitarbeiter einstellen</button></div>
        <div class="section">${table(['#', 'Name', 'Rolle', 'Status', 'Eingestellt', ''], rows)}</div>`;
};

VIEWS['gf-drivers'] = async (root) => {
    const d = await call('gf:employees:list');
    const drivers = d.employees.filter((e) => e.role === 'fahrer');
    const rows = drivers.map((e) => `<tr>
        <td>#${e.id}</td>
        <td>${escapeHtml(e.name)}</td>
        <td>${e.driver_current_status ? badge(DRIVER_STATUS_META[e.driver_current_status]) : '-'}</td>
        <td>${badge(EMPLOYMENT_STATUS_META[e.status])}</td>
        <td><button class="btn btn-sm btn-primary" onclick="Actions.openDriverFile(${e.driver_id})">Akte öffnen</button></td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Fahrerakten</h1>
        <p class="view-subtitle">Digitale Personalakten aller Fahrer.</p>
        <div class="section">${table(['#', 'Name', 'Status', 'Mitarbeiter', ''], rows)}</div>`;
};

VIEWS['gf-fleet'] = async (root) => {
    const includeArchived = window.__fleetShowArchived === true;
    const d = await call('gf:vehicles:list', { includeArchived });

    const rows = d.vehicles.map((v) => `<tr>
        <td>${badge(VEHICLE_STATUS_META[v.status])}</td>
        <td>${escapeHtml(v.name)}${v.archived ? ' <span class="pill">Archiviert</span>' : ''}</td>
        <td>${escapeHtml(v.plate)}</td>
        <td>${escapeHtml(v.vehicle_class)}</td>
        <td>${Number(v.mileage).toLocaleString('de-DE')} km</td>
        <td>${v.driver_name ? escapeHtml(v.driver_name) : '-'}</td>
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
        <div class="section">${table(['Status', 'Name', 'Kennzeichen', 'Klasse', 'Kilometerstand', 'Fahrer', ''], rows)}</div>`;
};

VIEWS['gf-finance'] = async (root) => {
    const [overview, tx] = await Promise.all([call('gf:finance:overview'), call('gf:finance:transactions', { limit: 40 })]);

    const TX_TYPE_LABELS = { einnahme: 'Einnahme', auszahlung: 'Auszahlung', einzahlung: 'Einzahlung', gehalt: 'Gehalt' };
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
        <div class="btn-row" style="margin:16px 0;"><button class="btn btn-primary" onclick="showView('gf-payouts')">Auszahlung verwalten</button></div>
        <div class="section">
            <div class="section-header"><h3>Transaktionshistorie</h3></div>
            ${table(['#', 'Typ', 'Beschreibung', 'Betrag', 'Datum'], rows)}
        </div>`;
};

VIEWS['gf-payouts'] = async (root) => {
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
};

VIEWS['gf-payroll'] = async (root) => {
    const [ratesRes, overview] = await Promise.all([call('gf:payroll:rates'), call('gf:payroll:overview')]);

    const rateRows = Object.keys(ratesRes.roleLabels).map((role) => `
        <label>${escapeHtml(ratesRes.roleLabels[role])}</label>
        <div class="btn-row" style="margin-bottom:10px;">
            <input id="wage-rate-${role}" type="number" min="0" step="0.5" value="${Number(ratesRes.rates[role] || 0)}" style="flex:1;" />
            <button class="btn btn-sm" onclick="Actions.setWageRate('${role}')">Speichern</button>
        </div>`).join('');

    const employeeRows = overview.employees.map((e) => `<tr>
        <td>${escapeHtml(e.name)}</td>
        <td>${escapeHtml(ratesRes.roleLabels[e.role] || e.role)}</td>
        <td>${e.clockedIn ? badge({ label: 'Eingestempelt', dot: 'green' }) : badge({ label: 'Ausgestempelt', dot: 'gray' })}</td>
        <td>${formatHm(e.unpaidSeconds)}</td>
        <td>${formatMoney(e.hourlyRate)}/Std.</td>
        <td style="font-weight:700;">${formatMoney(e.amount)}</td>
        <td class="btn-row">
            <button class="btn btn-sm btn-primary" ${e.amount <= 0 ? 'disabled' : ''} onclick="Actions.payEmployee(${e.id}, ${JSON.stringify(e.name)})">Auszahlen</button>
        </td>
    </tr>`);

    root.innerHTML = `
        <h1 class="view-title">Gehälter</h1>
        <p class="view-subtitle">Stundenlöhne je Rolle festlegen und offene Gehälter anhand der Stempeluhr auszahlen.</p>
        <div class="grid grid-2" style="align-items:start;">
            <div class="section">
                <h3 style="margin:0 0 12px;">Stundenlöhne</h3>
                ${rateRows}
            </div>
            <div class="section">
                <h3 style="margin:0 0 12px;">Offene Gehälter</h3>
                ${table(['Name', 'Rolle', 'Stempeluhr', 'Offene Std.', 'Satz', 'Betrag', ''], employeeRows)}
            </div>
        </div>`;
};

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
        <h1 class="view-title">Aufträge</h1>
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

// =========================================================
// ACTIONS
// =========================================================

const Actions = {};

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

Actions.cargoStatus = async (orderId, status) => {
    await call('driver:updateCargoStatus', { orderId, status });
    showView('driver-orders');
};

Actions.completeOrder = async (orderId) => {
    const r = await call('driver:completeOrder', { orderId });
    toast('Auftrag abgeschlossen', `Unternehmensumsatz: ${formatMoney(r.value)}`, 'success');
    showView('driver-orders');
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

Actions.openDispatchModal = (orderId, requiresPermission) => {
    const hasPerm = (d) => !requiresPermission || (d.permissions || '').split(',').includes(requiresPermission);
    const drivers = (window.__availableDrivers || []).filter((d) => d.current_status === 'verfuegbar' && hasPerm(d));
    const options = drivers.map((d) => `<option value="${d.driver_id}">${escapeHtml(d.name)}${d.vehicle_name ? ` - ${escapeHtml(d.vehicle_name)} (${escapeHtml(d.vehicle_plate)})` : ' - kein Fahrzeug'}</option>`).join('');
    const hint = requiresPermission ? `<p class="card-hint" style="margin:0 0 10px;">⚠ Dieser Auftrag erfordert die Berechtigung "${escapeHtml(requiresPermission)}" - nur berechtigte, verfügbare Fahrer werden angezeigt.</p>` : '';
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
    showView('dispatch-pool');
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
    showView('dispatch-active');
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
    showView('dispatch-active');
};

Actions.openHireModal = async () => {
    const d = await call('gf:employees:onlinePlayers');
    const options = d.players.length
        ? d.players.map((p) => `<option value="${p.serverId}">${escapeHtml(p.name)} (ID ${p.serverId})</option>`).join('')
        : '<option value="">Kein online Spieler ohne Mitarbeiterkonto gefunden</option>';

    openModal('Mitarbeiter einstellen', 'Legt für einen gerade online Spieler ein Mitarbeiterkonto an - dessen FiveM-Charakter wird automatisch erkannt.', `
        <label>Spieler</label>
        <select id="hire-target">${options}</select>
        <label>Name</label>
        <input id="hire-name" type="text" />
        <label>Rolle</label>
        <select id="hire-role">
            <option value="fahrer">LKW-Fahrer</option>
            <option value="disponent">Disponent</option>
            <option value="geschaeftsfuehrung">Geschäftsführung</option>
        </select>
    `, `
        <button class="btn btn-ghost" onclick="closeModal()">Abbrechen</button>
        <button class="btn btn-primary" onclick="Actions.confirmHire()">Einstellen</button>
    `);
};
Actions.confirmHire = async () => {
    const targetId = Number(modalInputValue('hire-target'));
    const name = modalInputValue('hire-name').trim();
    const role = modalInputValue('hire-role');
    if (!targetId || !name) { toast('Fehler', 'Bitte Spieler und Name auswählen.', 'error'); return; }
    await call('gf:employees:hire', { targetId, name, role });
    closeModal();
    toast('Mitarbeiter eingestellt', '', 'success');
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
    showView('gf-fleet');
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
    showView('gf-fleet');
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
    showView('gf-fleet');
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
    showView('gf-fleet');
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
    showView('gf-fleet');
};

Actions.reactivateVehicle = async (vehicleId) => {
    await call('gf:vehicles:reactivate', { vehicleId });
    toast('Fahrzeug reaktiviert', '', 'success');
    showView('gf-fleet');
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
        toast('Auszahlung gebucht', `${formatMoney(amount)} - Bargeld konnte nicht übergeben werden (Wirtschafts-Anbindung nicht verfügbar).`, 'info');
    }
    showView('gf-payouts');
};

Actions.executeDeposit = async () => {
    const amount = Number(document.getElementById('deposit-amount').value);
    const source = document.getElementById('deposit-source').value;
    const reason = document.getElementById('deposit-reason').value;
    if (!amount || amount <= 0) { toast('Ungültiger Betrag', 'Bitte einen gültigen Einzahlungsbetrag angeben.', 'error'); return; }
    window.__depositSource = source;
    await call('gf:deposit:execute', { amount, source, reason });
    toast('Einzahlung verbucht', `${formatMoney(amount)} Bargeld abgezogen.`, 'success');
    showView('gf-payouts');
};

Actions.setWageRate = async (role) => {
    const hourlyRate = Number(document.getElementById(`wage-rate-${role}`).value);
    if (hourlyRate === null || hourlyRate < 0 || Number.isNaN(hourlyRate)) {
        toast('Ungültiger Betrag', 'Bitte einen gültigen Stundenlohn angeben.', 'error');
        return;
    }
    await call('gf:payroll:setRate', { role, hourlyRate });
    toast('Stundenlohn gespeichert', '', 'success');
    showView('gf-payroll');
};

Actions.payEmployee = async (employeeId, name) => {
    const result = await call('gf:payroll:pay', { employeeId });
    if (result.cashGiven) {
        toast('Gehalt ausgezahlt', `${formatMoney(result.amount)} an ${name} als Bargeld übergeben.`, 'success');
    } else {
        toast('Gehalt gebucht', `${formatMoney(result.amount)} für ${name} - Bargeld konnte nicht übergeben werden (nicht online oder keine Wirtschafts-Anbindung).`, 'info');
    }
    showView('gf-payroll');
};

Actions.filterOrders = (status) => {
    window.__orderStatusFilter = status;
    showView('gf-orders');
};
