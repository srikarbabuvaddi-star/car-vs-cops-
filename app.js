// =========================================================================
// CHASELINE: LAST EXIT — OFFICIAL INTERACTIVE GAME EXPERIENCE
// Modules: Playable Tactical Radar Simulator, Vehicle Garage & Underglow,
//          Live Web Audio FFT Frequency Visualizer, Cockpit HUD Controls
// =========================================================================

document.addEventListener('DOMContentLoaded', () => {
  initCockpitToggles();
  initPlayableRadar();
  initVehicleGarage();
  initAudioLabWithVisualizer();
});

// -------------------------------------------------------------------------
// 1. COCKPIT HUD & SCANLINE TOGGLES
// -------------------------------------------------------------------------
function initCockpitToggles() {
  const toggleHudBtn = document.getElementById('toggleHudMode');
  const toggleScanBtn = document.getElementById('toggleScanlines');
  const hudOverlay = document.getElementById('cockpitHudOverlay');
  const scanlines = document.getElementById('globalScanlines');

  if (toggleHudBtn && hudOverlay) {
    toggleHudBtn.addEventListener('click', () => {
      playUiBeep(880, 0.08);
      const isVisible = hudOverlay.style.display !== 'none';
      hudOverlay.style.display = isVisible ? 'none' : 'block';
      toggleHudBtn.classList.toggle('active', !isVisible);
    });
  }

  if (toggleScanBtn && scanlines) {
    toggleScanBtn.addEventListener('click', () => {
      playUiBeep(660, 0.08);
      const isVisible = scanlines.style.display !== 'none';
      scanlines.style.display = isVisible ? 'none' : 'block';
      toggleScanBtn.classList.toggle('active', !isVisible);
    });
  }
}

// Global UI Audio Beep Synthesizer
let globalAudioCtx = null;
function getSharedAudioContext() {
  if (!globalAudioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    globalAudioCtx = new AudioContextClass();
  }
  if (globalAudioCtx.state === 'suspended') {
    globalAudioCtx.resume();
  }
  return globalAudioCtx;
}

function playUiBeep(freq = 800, dur = 0.06) {
  try {
    const ctx = getSharedAudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const now = ctx.currentTime;
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + dur);
  } catch (e) {
    // AudioContext requires user gesture
  }
}

// -------------------------------------------------------------------------
// 2. PLAYABLE TACTICAL RADAR COMBAT SIMULATOR
// -------------------------------------------------------------------------
function initPlayableRadar() {
  const canvas = document.getElementById('radarCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;
  const center = { x: width / 2, y: height / 2 };
  const radius = width * 0.44;

  // Telemetry DOM elements
  const scoreEl = document.getElementById('radarScoreReadout');
  const comboEl = document.getElementById('radarComboReadout');
  const crashesEl = document.getElementById('radarCrashesReadout');
  const modeBadge = document.getElementById('radarModeBadge');
  const distanceEl = document.getElementById('radarDistanceReadout');
  const alertBanner = document.getElementById('radarAlertBanner');
  const healthFill = document.getElementById('radarHealthFill');
  const shieldFill = document.getElementById('radarShieldFill');
  const nitroFill = document.getElementById('radarNitroFill');
  const starsContainer = document.getElementById('radarStars');

  const chipVelocity = document.getElementById('chipVelocity');
  const chipSlip = document.getElementById('chipSlip');
  const chipDist = document.getElementById('chipDist');

  // Simulator State
  let isManual = true;
  let score = 2400;
  let combo = 1;
  let crashCount = 0;
  let wantedLevel = 3;
  let vitality = 100;
  let shield = 100;
  let nitro = 100;

  // Player Physics
  const player = {
    x: center.x - 30,
    y: center.y + 40,
    vx: 0,
    vy: 0,
    heading: -Math.PI * 0.4,
    speed: 0,
    maxSpeed: 3.4,
    accel: 0.14,
    friction: 0.965,
    steerRate: 0.058,
    isDrifting: false,
    isNitro: false,
    slipAngle: 0
  };

  // Keyboard Inputs
  const keys = {
    up: false,
    down: false,
    left: false,
    right: false,
    drift: false,
    nitro: false
  };

  // Skid Marks & Explosions Particles
  const skidMarks = [];
  const particles = [];
  const floatTexts = [];

  // Pursuit Cruisers
  const cops = [
    { x: center.x + 80, y: center.y - 70, vx: 0, vy: 0, heading: 0, speed: 1.8, active: true },
    { x: center.x - 90, y: center.y - 40, vx: 0, vy: 0, heading: 0, speed: 1.7, active: true },
    { x: center.x + 60, y: center.y + 80, vx: 0, vy: 0, heading: 0, speed: 1.9, active: true }
  ];

  // Extraction Waypoint Beacon
  const waypoint = { x: center.x + 80, y: center.y - 80 };

  let frame = 0;

  // Key Event Listeners
  window.addEventListener('keydown', (e) => {
    if (['ArrowUp', 'KeyW'].includes(e.code)) { keys.up = true; }
    if (['ArrowDown', 'KeyS'].includes(e.code)) { keys.down = true; }
    if (['ArrowLeft', 'KeyA'].includes(e.code)) { keys.left = true; }
    if (['ArrowRight', 'KeyD'].includes(e.code)) { keys.right = true; }
    if (e.code === 'Space') { keys.drift = true; e.preventDefault(); }
    if (['ShiftLeft', 'ShiftRight'].includes(e.code)) { keys.nitro = true; }
  });

  window.addEventListener('keyup', (e) => {
    if (['ArrowUp', 'KeyW'].includes(e.code)) { keys.up = false; }
    if (['ArrowDown', 'KeyS'].includes(e.code)) { keys.down = false; }
    if (['ArrowLeft', 'KeyA'].includes(e.code)) { keys.left = false; }
    if (['ArrowRight', 'KeyD'].includes(e.code)) { keys.right = false; }
    if (e.code === 'Space') { keys.drift = false; }
    if (['ShiftLeft', 'ShiftRight'].includes(e.code)) { keys.nitro = false; }
  });

  // On-Screen Touch / Mouse Arcade D-Pad Handlers
  function bindTouchBtn(id, keyProp) {
    const btn = document.getElementById(id);
    if (!btn) return;
    const start = (ev) => { ev.preventDefault(); keys[keyProp] = true; btn.classList.add('pressed'); };
    const end = (ev) => { ev.preventDefault(); keys[keyProp] = false; btn.classList.remove('pressed'); };
    btn.addEventListener('mousedown', start);
    btn.addEventListener('mouseup', end);
    btn.addEventListener('mouseleave', end);
    btn.addEventListener('touchstart', start, { passive: false });
    btn.addEventListener('touchend', end, { passive: false });
  }

  bindTouchBtn('btnTouchUp', 'up');
  bindTouchBtn('btnTouchDown', 'down');
  bindTouchBtn('btnTouchLeft', 'left');
  bindTouchBtn('btnTouchRight', 'right');
  bindTouchBtn('btnTouchDrift', 'drift');

  // Mode and Action Buttons
  const btnManual = document.getElementById('btnManualDrive');
  const btnAuto = document.getElementById('btnAutopilot');
  const btnNitro = document.getElementById('btnTriggerNitro');
  const btnBlast = document.getElementById('btnTriggerBlastDemo');
  const btnReset = document.getElementById('btnResetArena');

  if (btnManual && btnAuto) {
    btnManual.addEventListener('click', () => {
      isManual = true;
      btnManual.classList.add('active');
      btnAuto.classList.remove('active');
      if (modeBadge) modeBadge.textContent = 'MANUAL PILOT';
      triggerAlert('MANUAL FLIGHT ENGAGED');
    });

    btnAuto.addEventListener('click', () => {
      isManual = false;
      btnAuto.classList.add('active');
      btnManual.classList.remove('active');
      if (modeBadge) modeBadge.textContent = 'AUTOPILOT DEMO';
      triggerAlert('AUTOPILOT EVASION ACTIVE');
    });
  }

  if (btnNitro) {
    btnNitro.addEventListener('click', () => {
      nitro = 100;
      keys.nitro = true;
      triggerAlert('NITRO BURST INJECTED!');
      setTimeout(() => { keys.nitro = false; }, 800);
    });
  }

  if (btnBlast) {
    btnBlast.addEventListener('click', () => {
      triggerCopCollision(cops[0], cops[1]);
    });
  }

  if (btnReset) {
    btnReset.addEventListener('click', () => {
      player.x = center.x - 30;
      player.y = center.y + 40;
      player.vx = 0;
      player.vy = 0;
      player.speed = 0;
      vitality = 100;
      shield = 100;
      nitro = 100;
      respawnWaypoint();
      cops.forEach((cop, i) => {
        cop.x = center.x + Math.cos(i * 2) * (radius - 25);
        cop.y = center.y + Math.sin(i * 2) * (radius - 25);
        cop.active = true;
      });
      triggerAlert('SECTOR RESET COMPLETE');
    });
  }

  function triggerAlert(msg) {
    if (!alertBanner) return;
    alertBanner.textContent = msg;
    alertBanner.style.opacity = '1';
    alertBanner.style.transform = 'translateX(-50%) scale(1.08)';
    setTimeout(() => {
      alertBanner.style.transform = 'translateX(-50%) scale(1.0)';
    }, 120);
  }

  function respawnWaypoint() {
    const angle = Math.random() * Math.PI * 2;
    const dist = (radius * 0.4) + Math.random() * (radius * 0.4);
    waypoint.x = center.x + Math.cos(angle) * dist;
    waypoint.y = center.y + Math.sin(angle) * dist;
  }

  function triggerCopCollision(c1, c2) {
    const midX = (c1.x + c2.x) / 2;
    const midY = (c1.y + c2.y) / 2;

    // Spawn 28 fiery particles
    for (let p = 0; p < 28; p++) {
      const pAngle = Math.random() * Math.PI * 2;
      const pSpeed = 1.5 + Math.random() * 4.5;
      particles.push({
        x: midX,
        y: midY,
        vx: Math.cos(pAngle) * pSpeed,
        vy: Math.sin(pAngle) * pSpeed,
        life: 1.0,
        decay: 0.025 + Math.random() * 0.03,
        color: Math.random() > 0.4 ? '#ff5500' : '#ffcc00',
        radius: 2 + Math.random() * 3
      });
    }

    // Shockwave ring
    particles.push({
      x: midX,
      y: midY,
      vx: 0, vy: 0,
      radius: 6,
      maxRadius: 36,
      life: 1.0,
      decay: 0.04,
      isRing: true,
      color: '#ff3300'
    });

    crashCount++;
    score += 500 * combo;
    combo = Math.min(10, combo + 1);

    // Floating text
    floatTexts.push({
      x: midX,
      y: midY - 10,
      text: '💥 COP BLAST! +500',
      life: 1.0,
      color: '#ffb700'
    });

    triggerAlert('TACTICAL COLLISION DETONATED!');
    playUiExplosion();

    // Respawn cops at sector perimeter
    setTimeout(() => {
      c1.x = center.x + (Math.random() - 0.5) * (radius * 1.5);
      c1.y = center.y - radius + 15;
    }, 400);

    setTimeout(() => {
      c2.x = center.x + (Math.random() - 0.5) * (radius * 1.5);
      c2.y = center.y + radius - 15;
    }, 600);
  }

  function playUiExplosion() {
    try {
      const ctx = getSharedAudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const now = ctx.currentTime;
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(140, now);
      osc.frequency.exponentialRampToValueAtTime(28, now + 0.45);
      gain.gain.setValueAtTime(0.3, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.5);
    } catch (e) {}
  }

  // -----------------------------------------------------------------------
  // MAIN ANIMATION & PHYSICS LOOP (60 FPS)
  // -----------------------------------------------------------------------
  function updatePhysics() {
    frame++;

    if (isManual) {
      // Manual Player Driving
      const isNitro = keys.nitro && nitro > 5;
      const isDrift = keys.drift;
      const currentMaxSpeed = isNitro ? player.maxSpeed * 1.55 : player.maxSpeed;
      const currentAccel = isNitro ? player.accel * 1.8 : player.accel;

      if (isNitro) {
        nitro = Math.max(0, nitro - 0.35);
        // Exhaust flame particles
        if (frame % 2 === 0) {
          particles.push({
            x: player.x - Math.cos(player.heading) * 10,
            y: player.y - Math.sin(player.heading) * 10,
            vx: -Math.cos(player.heading) * 2 + (Math.random() - 0.5),
            vy: -Math.sin(player.heading) * 2 + (Math.random() - 0.5),
            life: 0.8,
            decay: 0.08,
            color: '#00f0ff',
            radius: 3
          });
        }
      } else {
        nitro = Math.min(100, nitro + 0.08);
      }

      // Acceleration & Reversing
      if (keys.up) {
        player.speed = Math.min(currentMaxSpeed, player.speed + currentAccel);
      } else if (keys.down) {
        player.speed = Math.max(-1.5, player.speed - currentAccel * 0.8);
      } else {
        player.speed *= player.friction;
      }

      // Steering
      const steerFactor = isDrift ? 1.4 : 1.0;
      if (keys.left) {
        player.heading -= player.steerRate * steerFactor;
      }
      if (keys.right) {
        player.heading += player.steerRate * steerFactor;
      }

      // Velocity with drift slip
      const targetVx = Math.cos(player.heading) * player.speed;
      const targetVy = Math.sin(player.heading) * player.speed;
      const grip = isDrift ? 0.08 : 0.28;

      player.vx += (targetVx - player.vx) * grip;
      player.vy += (targetVy - player.vy) * grip;

      // Skid marks during hard drift
      if (isDrift && Math.abs(player.speed) > 1.2) {
        skidMarks.push({
          x: player.x,
          y: player.y,
          alpha: 0.4
        });
        if (skidMarks.length > 70) skidMarks.shift();
      }

      // Calculate slip angle in degrees
      const actualMoveAngle = Math.atan2(player.vy, player.vx);
      let angleDiff = Math.abs(player.heading - actualMoveAngle);
      while (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
      player.slipAngle = Math.round(Math.abs(angleDiff) * (180 / Math.PI));

    } else {
      // Autopilot Demo Mode: Sweeping figure-eight evasion
      player.heading = Math.sin(frame * 0.02) * 0.85 - Math.PI * 0.35;
      player.speed = 2.2;
      player.vx = Math.cos(player.heading) * player.speed;
      player.vy = Math.sin(player.heading) * player.speed;
      player.slipAngle = Math.round(Math.abs(Math.sin(frame * 0.03)) * 32);
      nitro = 85;
    }

    // Apply Velocity
    player.x += player.vx;
    player.y += player.vy;

    // Arena Perimeter Bounds Clamping
    const distFromCenter = Math.hypot(player.x - center.x, player.y - center.y);
    if (distFromCenter > radius - 14) {
      const ang = Math.atan2(player.y - center.y, player.x - center.x);
      player.x = center.x + Math.cos(ang) * (radius - 14);
      player.y = center.y + Math.sin(ang) * (radius - 14);
      player.vx *= -0.4;
      player.vy *= -0.4;
      player.speed *= -0.3;
    }

    // Waypoint Proximity Check
    const distToWp = Math.hypot(player.x - waypoint.x, player.y - waypoint.y);
    if (distToWp < 18) {
      score += 1000 * combo;
      combo = Math.min(10, combo + 1);
      triggerAlert('★ EXTRACTION BEACON SECURED! +1000');
      playUiBeep(1200, 0.15);
      respawnWaypoint();

      // Waypoint Celebration Sparks
      for (let s = 0; s < 18; s++) {
        const sAng = Math.random() * Math.PI * 2;
        particles.push({
          x: player.x,
          y: player.y,
          vx: Math.cos(sAng) * 3,
          vy: Math.sin(sAng) * 3,
          life: 1.0,
          decay: 0.04,
          color: '#ffb700',
          radius: 2.5
        });
      }
    }

    // Update Cops AI
    cops.forEach((cop) => {
      const dx = player.x - cop.x;
      const dy = player.y - cop.y;
      const dist = Math.hypot(dx, dy);

      if (dist > 12) {
        cop.vx += (dx / dist) * 0.11;
        cop.vy += (dy / dist) * 0.11;
        cop.vx *= 0.94;
        cop.vy *= 0.94;
        cop.x += cop.vx;
        cop.y += cop.vy;
      }

      // Cop vs Player Collision Check
      if (dist < 14) {
        if (shield > 20) {
          shield = Math.max(0, shield - 35);
          triggerAlert('SHIELD ABSORPTION HIT!');
          playUiBeep(450, 0.1);
        } else {
          vitality = Math.max(0, vitality - 25);
          triggerAlert('HULL INTEGRITY DAMAGED!');
          playUiBeep(250, 0.2);
        }
        // Repel cop
        cop.vx = -cop.vx * 1.5;
        cop.vy = -cop.vy * 1.5;
      }
    });

    // Cop vs Cop Friendly Fire Collision Check
    for (let i = 0; i < cops.length; i++) {
      for (let j = i + 1; j < cops.length; j++) {
        const c1 = cops[i];
        const c2 = cops[j];
        const copDist = Math.hypot(c1.x - c2.x, c1.y - c2.y);
        if (copDist < 16) {
          triggerCopCollision(c1, c2);
        }
      }
    }

    // Update Particles
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= p.decay;
      if (p.isRing) p.radius += (p.maxRadius - p.radius) * 0.12;
      if (p.life <= 0) particles.splice(i, 1);
    }

    // Update Floating Texts
    for (let i = floatTexts.length - 1; i >= 0; i--) {
      const ft = floatTexts[i];
      ft.y -= 0.6;
      ft.life -= 0.02;
      if (ft.life <= 0) floatTexts.splice(i, 1);
    }

    // Update Telemetry Displays
    if (scoreEl) scoreEl.textContent = `SCORE: ${score.toLocaleString().padStart(7, '0')}`;
    if (comboEl) comboEl.textContent = `CHAIN: x${combo}`;
    if (crashesEl) crashesEl.textContent = `BLASTS: ${crashCount}`;
    if (distanceEl) distanceEl.textContent = `GPS ➔ EXTRACTION BEACON: ${Math.round(distToWp)}m`;
    if (healthFill) healthFill.style.width = `${vitality}%`;
    if (shieldFill) shieldFill.style.width = `${shield}%`;
    if (nitroFill) nitroFill.style.width = `${nitro}%`;

    const kmhSpeed = Math.round(Math.abs(player.speed) * 75);
    if (chipVelocity) chipVelocity.textContent = `${kmhSpeed} KM/H`;
    if (chipSlip) chipSlip.textContent = `${player.slipAngle}°`;
    if (chipDist) chipDist.textContent = `${Math.round(distToWp)}m`;

    // Wanted Stars Lighting
    if (starsContainer) {
      wantedLevel = Math.min(5, Math.max(1, 1 + Math.floor(crashCount / 2)));
      const stars = starsContainer.querySelectorAll('.star');
      stars.forEach((s, idx) => {
        s.classList.toggle('lit', idx < wantedLevel);
      });
      starsContainer.classList.toggle('blinking', wantedLevel >= 4);
    }
  }

  // -----------------------------------------------------------------------
  // RENDER RADAR TO CANVAS
  // -----------------------------------------------------------------------
  function renderRadar() {
    updatePhysics();

    ctx.clearRect(0, 0, width, height);

    // Radar circular clip
    ctx.save();
    ctx.beginPath();
    ctx.arc(center.x, center.y, radius, 0, Math.PI * 2);
    ctx.clip();

    // Terrain Backdrop (Dark Municipal Park Green)
    ctx.fillStyle = '#0f1c12';
    ctx.fillRect(0, 0, width, height);

    // Garden sidewalk and flower patches
    ctx.fillStyle = '#142518';
    ctx.fillRect(center.x - 70, center.y - 70, 60, 60);
    ctx.fillRect(center.x + 15, center.y - 70, 60, 60);
    ctx.fillRect(center.x - 70, center.y + 15, 60, 60);
    ctx.fillRect(center.x + 15, center.y + 15, 60, 60);

    // High-Contrast Solid White Avenues (with dark concrete borders)
    const avenues = [-80, -40, 0, 40, 80];
    const roadWidth = 20;

    // Dark road boundary border
    ctx.strokeStyle = '#05080e';
    ctx.lineWidth = roadWidth + 4;
    avenues.forEach(offset => {
      ctx.beginPath();
      ctx.moveTo(0, center.y + offset);
      ctx.lineTo(width, center.y + offset);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(center.x + offset, 0);
      ctx.lineTo(center.x + offset, height);
      ctx.stroke();
    });

    // Solid Bright White Road Ribbons
    ctx.strokeStyle = '#f8fafc';
    ctx.lineWidth = roadWidth;
    avenues.forEach(offset => {
      ctx.beginPath();
      ctx.moveTo(0, center.y + offset);
      ctx.lineTo(width, center.y + offset);
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(center.x + offset, 0);
      ctx.lineTo(center.x + offset, height);
      ctx.stroke();
    });

    // Draw Skid Marks
    skidMarks.forEach(sm => {
      ctx.fillStyle = `rgba(15, 23, 42, ${sm.alpha})`;
      ctx.beginPath();
      ctx.arc(sm.x, sm.y, 2.5, 0, Math.PI * 2);
      ctx.fill();
    });

    // GPS Route Line (Player to Waypoint)
    ctx.strokeStyle = 'rgba(255, 183, 0, 0.75)';
    ctx.lineWidth = 3;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.moveTo(player.x, player.y);
    ctx.lineTo(waypoint.x, waypoint.y);
    ctx.stroke();
    ctx.setLineDash([]);

    // Draw Yellow Waypoint Extraction Beacon
    const pulseRad = 8 + Math.sin(frame * 0.12) * 4;
    ctx.strokeStyle = 'rgba(255, 183, 0, 0.5)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(waypoint.x, waypoint.y, pulseRad + 4, 0, Math.PI * 2);
    ctx.stroke();

    ctx.fillStyle = '#ffb700';
    ctx.beginPath();
    ctx.arc(waypoint.x, waypoint.y, 6, 0, Math.PI * 2);
    ctx.fill();

    // Draw Pursuit Cruisers & Proximity Radii
    cops.forEach((cop, idx) => {
      // Danger proximity halo
      ctx.fillStyle = 'rgba(255, 30, 70, 0.16)';
      ctx.beginPath();
      ctx.arc(cop.x, cop.y, 24, 0, Math.PI * 2);
      ctx.fill();

      // Alternating Red & Blue Strobe Lightbar
      const flash = (Math.floor(frame / 7) + idx) % 2 === 0;
      ctx.fillStyle = '#060910';
      ctx.beginPath();
      ctx.arc(cop.x, cop.y, 7, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = flash ? '#ff1e46' : '#3b82f6';
      ctx.beginPath();
      ctx.arc(cop.x, cop.y, 5, 0, Math.PI * 2);
      ctx.fill();
    });

    // Draw Particles & Shockwaves
    particles.forEach(p => {
      ctx.save();
      ctx.globalAlpha = p.life;
      if (p.isRing) {
        ctx.strokeStyle = p.color;
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.stroke();
      } else {
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    });

    // Draw Player Sightline Cone (50° Translucent Field of View)
    const coneDist = 48;
    const halfFov = 0.44;
    const leftRay = {
      x: player.x + Math.cos(player.heading - halfFov) * coneDist,
      y: player.y + Math.sin(player.heading - halfFov) * coneDist
    };
    const rightRay = {
      x: player.x + Math.cos(player.heading + halfFov) * coneDist,
      y: player.y + Math.sin(player.heading + halfFov) * coneDist
    };

    ctx.fillStyle = 'rgba(0, 240, 255, 0.22)';
    ctx.beginPath();
    ctx.moveTo(player.x, player.y);
    ctx.lineTo(leftRay.x, leftRay.y);
    ctx.lineTo(rightRay.x, rightRay.y);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = 'rgba(0, 240, 255, 0.5)';
    ctx.lineWidth = 1;
    ctx.stroke();

    // Draw Player Interceptor Chevron
    ctx.save();
    ctx.translate(player.x, player.y);
    ctx.rotate(player.heading + Math.PI / 2);

    ctx.fillStyle = '#ffffff';
    ctx.strokeStyle = '#050811';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, -11);
    ctx.lineTo(7, 7);
    ctx.lineTo(0, 3.5);
    ctx.lineTo(-7, 7);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Cyan engine core
    ctx.fillStyle = '#00f0ff';
    ctx.beginPath();
    ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Draw Floating Text Popups
    floatTexts.forEach(ft => {
      ctx.save();
      ctx.globalAlpha = ft.life;
      ctx.fillStyle = ft.color;
      ctx.font = 'bold 11px Orbitron, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(ft.text, ft.x, ft.y);
      ctx.restore();
    });

    ctx.restore(); // Restore radar clip

    // Perimeter Compass Ring & Cardinal N Pointer
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(center.x, center.y, radius, 0, Math.PI * 2);
    ctx.stroke();

    ctx.fillStyle = '#f8fafc';
    ctx.font = 'bold 11px Orbitron, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('N', center.x, center.y - radius + 15);

    requestAnimationFrame(renderRadar);
  }

  renderRadar();
}

// -------------------------------------------------------------------------
// 3. INTERACTIVE VEHICLE GARAGE & NEON UNDERGLOW TUNER
// -------------------------------------------------------------------------
function initVehicleGarage() {
  const tabs = document.querySelectorAll('.garage-tab');
  const vName = document.getElementById('vName');
  const vDesc = document.getElementById('vDesc');
  const vBadge = document.getElementById('vBadge');
  const vShape = document.getElementById('vShape');
  const vUnderglow = document.getElementById('vUnderglow');
  const vehicleCard = document.getElementById('vehicleCard');
  const visualStage = document.getElementById('vehicleVisualStage');

  const vSpeed = document.getElementById('vSpeed');
  const vSpeedVal = document.getElementById('vSpeedVal');
  const vAccel = document.getElementById('vAccel');
  const vAccelVal = document.getElementById('vAccelVal');
  const vHandling = document.getElementById('vHandling');
  const vHandlingVal = document.getElementById('vHandlingVal');
  const vArmor = document.getElementById('vArmor');
  const vArmorVal = document.getElementById('vArmorVal');

  let activeVehicleKey = 'player';

  const fleet = {
    player: {
      name: 'APEX INTERCEPTOR',
      badge: 'PLAYER CHASSIS',
      desc: 'Lightweight high-torque rear-wheel escape vehicle equipped with dual nitro tanks, precision drift slip differential, and kinetic shield generator.',
      color: 'linear-gradient(180deg, #ff7b00 0%, #ff2a00 100%)',
      shadow: '0 10px 30px rgba(255, 123, 0, 0.45)',
      revFreq: 280,
      speed: '90%', speedVal: '260 KM/H',
      accel: '88%', accelVal: '3.2s (0-100)',
      handling: '94%', handlingVal: '94%',
      armor: '75%', armorVal: '3 INTEGRITY'
    },
    chaser: {
      name: 'CRUISER CHASER',
      badge: 'STANDARD PURSUIT SQUAD',
      desc: 'Rapid highway cruiser utilizing direct pursuit algorithms, balanced cornering agility, and persistent pursuit formation.',
      color: 'linear-gradient(180deg, #ffffff 0%, #0044ff 100%)',
      shadow: '0 10px 30px rgba(0, 68, 255, 0.45)',
      revFreq: 220,
      speed: '82%', speedVal: '235 KM/H',
      accel: '80%', accelVal: '3.8s (0-100)',
      handling: '82%', handlingVal: '82%',
      armor: '65%', armorVal: 'LIGHT'
    },
    interceptor: {
      name: 'ROUTE INTERCEPTOR',
      badge: 'PREDICTIVE CUT-OFF UNIT',
      desc: 'Equipped with predictive route estimation to calculate escape trajectories and flank intersections ahead of your vehicle.',
      color: 'linear-gradient(180deg, #0f172a 0%, #ef4444 100%)',
      shadow: '0 10px 30px rgba(239, 68, 68, 0.45)',
      revFreq: 320,
      speed: '94%', speedVal: '275 KM/H',
      accel: '92%', accelVal: '2.9s (0-100)',
      handling: '88%', handlingVal: '88%',
      armor: '70%', armorVal: 'REINFORCED'
    },
    blocker: {
      name: 'HEAVY BLOCKER',
      badge: 'TACTICAL ROADBLOCK UNIT',
      desc: 'Reinforced tactical interceptor deployed to set stationary barricades and ram escape vehicles into perimeter barriers.',
      color: 'linear-gradient(180deg, #1e293b 0%, #334155 100%)',
      shadow: '0 10px 30px rgba(51, 65, 85, 0.5)',
      revFreq: 180,
      speed: '70%', speedVal: '190 KM/H',
      accel: '75%', accelVal: '4.5s (0-100)',
      handling: '60%', handlingVal: '60%',
      armor: '100%', armorVal: 'HEAVY REINFORCED'
    }
  };

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      activeVehicleKey = tab.getAttribute('data-vehicle');
      const data = fleet[activeVehicleKey];
      if (!data) return;

      playUiBeep(data.revFreq * 2, 0.08);

      vName.textContent = data.name;
      vDesc.textContent = data.desc;
      vBadge.textContent = data.badge;
      vShape.style.background = data.color;
      vShape.style.boxShadow = data.shadow;

      vSpeed.style.width = data.speed;
      vSpeedVal.textContent = data.speedVal;
      vAccel.style.width = data.accel;
      vAccelVal.textContent = data.accelVal;
      vHandling.style.width = data.handling;
      vHandlingVal.textContent = data.handlingVal;
      vArmor.style.width = data.armor;
      vArmorVal.textContent = data.armorVal;
    });
  });

  // Neon Underglow Palette Chips
  const glowChips = document.querySelectorAll('.glow-chip');
  glowChips.forEach(chip => {
    chip.addEventListener('click', () => {
      glowChips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');

      const glowColor = chip.getAttribute('data-glow');
      if (vUnderglow && glowColor) {
        vUnderglow.style.background = `radial-gradient(ellipse, ${glowColor} 0%, transparent 70%)`;
        playUiBeep(900, 0.06);
      }
    });
  });

  // 3D Perspective Tilt on Mouse Movement
  if (vehicleCard && visualStage) {
    vehicleCard.addEventListener('mousemove', (e) => {
      const rect = vehicleCard.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;
      const rotY = (x / rect.width) * 14;
      const rotX = -(y / rect.height) * 14;
      visualStage.style.transform = `perspective(800px) rotateX(${rotX}deg) rotateY(${rotY}deg) scale(1.02)`;
    });

    vehicleCard.addEventListener('mouseleave', () => {
      visualStage.style.transform = 'perspective(800px) rotateX(0deg) rotateY(0deg) scale(1)';
    });
  }

  // Rev Spec Engine Button
  const btnRev = document.getElementById('btnGarageRev');
  if (btnRev) {
    btnRev.addEventListener('click', () => {
      const data = fleet[activeVehicleKey];
      revCarAudio(data.revFreq);
    });
  }

  function revCarAudio(baseFreq) {
    try {
      const ctx = getSharedAudioContext();
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(baseFreq * 0.4, now);
      osc.frequency.exponentialRampToValueAtTime(baseFreq * 1.6, now + 0.5);
      osc.frequency.exponentialRampToValueAtTime(baseFreq * 0.6, now + 1.4);

      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(400, now);
      filter.frequency.exponentialRampToValueAtTime(2200, now + 0.5);
      filter.frequency.exponentialRampToValueAtTime(600, now + 1.4);

      gain.gain.setValueAtTime(0.01, now);
      gain.gain.linearRampToValueAtTime(0.35, now + 0.2);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 1.5);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 1.5);
    } catch (e) {}
  }
}

// -------------------------------------------------------------------------
// 4. REAL-TIME AUDIO LAB WITH FFT SPECTRUM VISUALIZER
// -------------------------------------------------------------------------
function initAudioLabWithVisualizer() {
  const visCanvas = document.getElementById('audioVisualizerCanvas');
  const visStatus = document.getElementById('visualizerStatus');
  const rpmSlider = document.getElementById('engineRpmSlider');
  const rpmValue = document.getElementById('sliderRpmValue');
  const sirenSlider = document.getElementById('sirenRateSlider');
  const sirenValue = document.getElementById('sliderSirenValue');

  let analyser = null;
  let dataArray = null;

  function setupAnalyser(ctx) {
    if (!analyser) {
      analyser = ctx.createAnalyser();
      analyser.fftSize = 64;
      const bufferLength = analyser.frequencyBinCount;
      dataArray = new Uint8Array(bufferLength);
    }
    return analyser;
  }

  // Draw 60 FPS Real-time FFT Frequency Spectrum
  function renderVisualizer() {
    if (visCanvas) {
      const vCtx = visCanvas.getContext('2d');
      const w = visCanvas.width;
      const h = visCanvas.height;

      vCtx.clearRect(0, 0, w, h);

      // Grid background
      vCtx.fillStyle = 'rgba(6, 12, 22, 0.95)';
      vCtx.fillRect(0, 0, w, h);

      if (analyser && dataArray) {
        analyser.getByteFrequencyData(dataArray);
      }

      const barCount = dataArray ? dataArray.length : 32;
      const barWidth = (w / barCount) - 3;

      for (let i = 0; i < barCount; i++) {
        const rawVal = dataArray ? dataArray[i] : 8 + Math.sin(i * 0.5 + Date.now() * 0.003) * 6;
        const barHeight = Math.max(4, (rawVal / 255) * (h - 18));
        const x = i * (barWidth + 3) + 4;
        const y = h - barHeight - 4;

        // Gradient: Cyan to Gold to Crimson
        const grad = vCtx.createLinearGradient(0, h, 0, 0);
        grad.addColorStop(0, '#00f0ff');
        grad.addColorStop(0.6, '#ffb700');
        grad.addColorStop(1, '#ff1e46');

        vCtx.fillStyle = grad;
        vCtx.fillRect(x, y, barWidth, barHeight);

        // Peak cap
        vCtx.fillStyle = '#ffffff';
        vCtx.fillRect(x, y - 2, barWidth, 2);
      }
    }
    requestAnimationFrame(renderVisualizer);
  }

  renderVisualizer();

  // Slider inputs
  if (rpmSlider && rpmValue) {
    rpmSlider.addEventListener('input', () => {
      const rpm = parseInt(rpmSlider.value, 10);
      const hz = Math.round(rpm / 15);
      rpmValue.textContent = `${rpm.toLocaleString()} RPM (${hz} Hz)`;
    });
  }

  if (sirenSlider && sirenValue) {
    sirenSlider.addEventListener('input', () => {
      const rate = parseFloat(sirenSlider.value).toFixed(1);
      sirenValue.textContent = `${rate} Hz (${rate > 3 ? 'URGENT YELP' : 'PURSUIT WAIL'})`;
    });
  }

  // Audio Triggers
  const btnEngine = document.getElementById('btnEngine');
  const engineStatus = document.getElementById('engineStatus');
  if (btnEngine) {
    btnEngine.addEventListener('click', () => {
      const ctx = getSharedAudioContext();
      const node = setupAnalyser(ctx);
      engineStatus.textContent = 'Revving...';
      if (visStatus) visStatus.textContent = 'ANALYZING: V8 COMBUSTION HARMONICS';

      const rpm = rpmSlider ? parseInt(rpmSlider.value, 10) : 3400;
      const baseFreq = rpm / 15;

      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(baseFreq * 0.5, now);
      osc.frequency.exponentialRampToValueAtTime(baseFreq * 1.4, now + 0.6);
      osc.frequency.exponentialRampToValueAtTime(baseFreq * 0.7, now + 1.6);

      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(400, now);
      filter.frequency.exponentialRampToValueAtTime(1600, now + 0.6);
      filter.frequency.exponentialRampToValueAtTime(500, now + 1.6);

      gain.gain.setValueAtTime(0.01, now);
      gain.gain.linearRampToValueAtTime(0.4, now + 0.2);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 1.8);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(node);
      node.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 1.8);

      setTimeout(() => {
        engineStatus.textContent = 'Ready';
        if (visStatus) visStatus.textContent = 'STANDBY // READY';
      }, 1900);
    });
  }

  const btnWail = document.getElementById('btnSirenWail');
  const wailStatus = document.getElementById('wailStatus');
  if (btnWail) {
    btnWail.addEventListener('click', () => {
      const ctx = getSharedAudioContext();
      const node = setupAnalyser(ctx);
      wailStatus.textContent = 'Wailing...';
      if (visStatus) visStatus.textContent = 'ANALYZING: EMERGENCY PURSUIT WAIL';

      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(550, now);
      osc.frequency.linearRampToValueAtTime(1200, now + 0.9);
      osc.frequency.linearRampToValueAtTime(600, now + 1.8);

      gain.gain.setValueAtTime(0.01, now);
      gain.gain.linearRampToValueAtTime(0.28, now + 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 2.0);

      osc.connect(gain);
      gain.connect(node);
      node.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 2.0);

      setTimeout(() => {
        wailStatus.textContent = 'Ready';
        if (visStatus) visStatus.textContent = 'STANDBY // READY';
      }, 2100);
    });
  }

  const btnYelp = document.getElementById('btnSirenYelp');
  const yelpStatus = document.getElementById('yelpStatus');
  if (btnYelp) {
    btnYelp.addEventListener('click', () => {
      const ctx = getSharedAudioContext();
      const node = setupAnalyser(ctx);
      yelpStatus.textContent = 'Yelping...';
      if (visStatus) visStatus.textContent = 'ANALYZING: CLOSE-RANGE YELP SWEEP';

      const now = ctx.currentTime;
      for (let i = 0; i < 4; i++) {
        const tStart = now + i * 0.25;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(650, tStart);
        osc.frequency.exponentialRampToValueAtTime(1300, tStart + 0.24);

        gain.gain.setValueAtTime(0.25, tStart);
        gain.gain.exponentialRampToValueAtTime(0.001, tStart + 0.25);

        osc.connect(gain);
        gain.connect(node);
        node.connect(ctx.destination);

        osc.start(tStart);
        osc.stop(tStart + 0.25);
      }

      setTimeout(() => {
        yelpStatus.textContent = 'Ready';
        if (visStatus) visStatus.textContent = 'STANDBY // READY';
      }, 1100);
    });
  }

  const btnExplosion = document.getElementById('btnExplosion');
  const blastStatus = document.getElementById('blastStatus');
  if (btnExplosion) {
    btnExplosion.addEventListener('click', () => {
      const ctx = getSharedAudioContext();
      const node = setupAnalyser(ctx);
      blastStatus.textContent = 'Detonating...';
      if (visStatus) visStatus.textContent = 'ANALYZING: SUB-BASS SHOCKWAVE BLAST';

      const now = ctx.currentTime;
      const subOsc = ctx.createOscillator();
      const subGain = ctx.createGain();

      subOsc.type = 'sawtooth';
      subOsc.frequency.setValueAtTime(160, now);
      subOsc.frequency.exponentialRampToValueAtTime(25, now + 0.6);

      subGain.gain.setValueAtTime(0.5, now);
      subGain.gain.exponentialRampToValueAtTime(0.001, now + 0.7);

      subOsc.connect(subGain);
      subGain.connect(node);
      node.connect(ctx.destination);

      subOsc.start(now);
      subOsc.stop(now + 0.7);

      setTimeout(() => {
        blastStatus.textContent = 'Ready';
        if (visStatus) visStatus.textContent = 'STANDBY // READY';
      }, 900);
    });
  }
}
