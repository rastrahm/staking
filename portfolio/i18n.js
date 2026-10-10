const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Staking Rewards — Rolando Strahm',
    'meta.description':
      'Pool de staking O(1) estilo Synthetix: CEI, gas optimizado, auditoría SWC y demo Next.js. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 03 · PORTFOLIO WEB3',
    'hero.title': 'STAKING<br>REWARDS',
    'hero.role': 'Solidity 0.8.24 · Foundry · Gas · SWC · Next.js',
    'hero.sub':
      'Pool de staking estilo Synthetix con rewards O(1), lockup dinámico, CEI, optimización de gas documentada y matriz SWC — más demo Next.js con ethers v6.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Tercer módulo de la suite: un <strong>pool de staking proporcional</strong> donde el reto es accrual correcto sin loops, solvencia del vault y lockups honestos. Cerré el ciclo con <strong>gas</strong>, matriz <strong>SWC-100–136</strong>, fuzz/invariant, ataque de reentrancy y frontend Next.js.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Staking O(1)',
    'p1.desc':
      'Accumulator Synthetix, Ownable2Step, SafeERC20, lockup dinámico, same-token permitido y CEI estricto.',
    'p1.l1': 'stake / withdraw / getReward / exit',
    'p1.l2': 'notify + rewardsDuration / lockup',
    'p1.l3': 'ReentrancyGuardTransient (Cancun)',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Transient reentrancy, packing uint64×4, cache de rewardPerToken y msg.sender, unchecked post-check — medido con forge gas-report.',
    'p2.l1': 'notify −32 119 avg',
    'p2.l2': 'withdraw −9 199 avg',
    'p2.l3': 'stake −7 358 avg',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación de ataques',
    'p3.desc':
      'Matriz SWC completa y campañas A–E: integridad, reentrancy, approve externo, lockup/notify y solvencia fuzz/invariant.',
    'p3.l1': '0 vulnerabilidades SWC explotables',
    'p3.l2': '35 tests Foundry (unit/attack/fuzz/inv)',
    'p3.l3': 'Demo Next.js + ethers v6',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot paths más baratos',
    'gas.lead':
      'Cada optimización documenta su <strong>tradeoff</strong> en <code>doc/GAS-ES.md</code>. Baseline vs post-opt con <code>forge test --gas-report</code>. El deploy sube un poco (OZ 5.2 + getters); las rutas de usuario/admin <strong>bajan</strong>.',
    'gas.m1': 'notify avg',
    'gas.m2': 'withdraw avg',
    'gas.m3': 'exit avg',
    'gas.m4': 'stake avg',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'ReentrancyGuardTransient (EIP-1153)',
    'gas.r1b': 'Guard más barato; requiere EVM Cancun+',
    'gas.r2a': 'Packing uint64 ×4 (tiempos / durations)',
    'gas.r2b': 'Un slot; overflow → revert ZeroAmount',
    'gas.r3a': 'Cache rewardPerToken en updateReward',
    'gas.r3b': 'Evita doble cálculo del acumulador',
    'gas.r4a': 'Cache account = msg.sender',
    'gas.r4b': 'Menos opcodes CALLER repetidos',
    'gas.r5a': 'unchecked tras checks de resta',
    'gas.r5b': 'Solo con bal >= amount; ahorra overflow check',
    'gas.r6a': 'OZ v5.2.0 + getters explícitos',
    'gas.r6b': 'Deploy +32 493; habilita transient y API clara',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra <code>StakingRewards</code>. Informe en <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong>; 3 ítems informativos (approve, timestamp, trust owner/tokens).',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked solo tras checks',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'Transfers ERC-20 vía SafeERC20',
    'swc.r107': 'CEI + ReentrancyGuardTransient; test/attack/ReentrancyAttack',
    'swc.r128': 'Paths O(1); sin loops sobre stakers',
    'swc.r123': 'Custom errors + unit / fuzz / invariant',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Approve front-running',
    'swc.i1d':
      'Race del ERC-20 externo al stake. Mitigación FE: approve(0)→N o permit; el pool no gestiona allowances.',
    'swc.i2t': 'block.timestamp',
    'swc.i2d':
      'Rate, periodFinish y lockup usan timestamp (estilo Synthetix aceptado). Miner skew acotado.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'Gates TDD: bootstrap, diseño, core O(1), lockup/notify, fuzz/gas, deploy/ABI, frontend y handoff.',
    'ph.01': 'Bootstrap + diseño TDD',
    'ph.23': 'Core O(1) + lockup / notify',
    'ph.4': 'Fuzz · invariant · gas · SWC',
    'ph.5': 'Deploy scripts + ABI',
    'ph.67': 'Frontend + handoff docs',
    'st.1': 'Fases',
    'st.2': 'Campañas',
    'st.3': 'SWC críticos',
    'st.4': 'Tests Forge',
    'term.label': 'rolando@strahm:~/03-staking',
    'term.1': 'forge test',
    'term.2': '[PASS] 35 tests · unit/fuzz/inv/attack',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 3 · Mitigados/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_03_CLOSED · SWC_0_CRITICAL · GAS_DOCUMENTED',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Tests Foundry donde el “ataque” debe fallar o quedar documentado como límite de diseño. Sin PoCs de exploit.',
    'cA.t': 'Integridad',
    'cA.d': 'Stake, withdraw, claim, exit y notify.',
    'cB.t': 'Reentrancy',
    'cB.d': 'Callback ERC-20 en getReward / withdraw.',
    'cC.t': 'Orden txs',
    'cC.d': 'Approve race del ERC-20 externo (doc).',
    'cD.t': 'Tiempo',
    'cD.d': 'Lockup, periodFinish, setRewardsDuration.',
    'cE.t': 'Solvencia',
    'cE.d': 'Fuzz + invariant de vault / earned.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead': 'Contrato, tests, gas, SWC, frontend y handoff en GitHub y GitLab.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Staking Rewards · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Staking Rewards — Rolando Strahm',
    'meta.description':
      'O(1) Synthetix-style staking pool: CEI, optimized gas, SWC audit, and Next.js demo. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 03 · WEB3 PORTFOLIO',
    'hero.title': 'STAKING<br>REWARDS',
    'hero.role': 'Solidity 0.8.24 · Foundry · Gas · SWC · Next.js',
    'hero.sub':
      'Synthetix-style staking pool with O(1) rewards, dynamic lockup, CEI, documented gas optimizations, and an SWC matrix — plus a Next.js / ethers v6 demo.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'Third suite module: a <strong>proportional staking pool</strong> where the hard part is correct accrual without user loops, vault solvency, and honest lockups. I closed the loop with <strong>gas</strong>, a full <strong>SWC-100–136</strong> matrix, fuzz/invariant tests, a reentrancy attack suite, and a Next.js frontend.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'O(1) staking',
    'p1.desc':
      'Synthetix accumulator, Ownable2Step, SafeERC20, dynamic lockup, same-token allowed, and strict CEI.',
    'p1.l1': 'stake / withdraw / getReward / exit',
    'p1.l2': 'notify + rewardsDuration / lockup',
    'p1.l3': 'ReentrancyGuardTransient (Cancun)',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Transient reentrancy, uint64×4 packing, rewardPerToken + msg.sender caching, post-check unchecked — measured with forge gas-report.',
    'p2.l1': 'notify −32,119 avg',
    'p2.l2': 'withdraw −9,199 avg',
    'p2.l3': 'stake −7,358 avg',
    'p3.num': '// PILLAR_03',
    'p3.title': 'Attack verification',
    'p3.desc':
      'Full SWC matrix and campaigns A–E: integrity, reentrancy, external approve, lockup/notify, and fuzz/invariant solvency.',
    'p3.l1': '0 exploitable SWC findings',
    'p3.l2': '35 Foundry tests (unit/attack/fuzz/inv)',
    'p3.l3': 'Next.js + ethers v6 demo',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheaper hot paths',
    'gas.lead':
      'Every optimization documents its <strong>tradeoff</strong> in <code>doc/GAS-EN.md</code>. Baseline vs post-opt via <code>forge test --gas-report</code>. Deploy cost rises slightly (OZ 5.2 + getters); user/admin paths <strong>drop</strong>.',
    'gas.m1': 'notify avg',
    'gas.m2': 'withdraw avg',
    'gas.m3': 'exit avg',
    'gas.m4': 'stake avg',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'ReentrancyGuardTransient (EIP-1153)',
    'gas.r1b': 'Cheaper guard; requires Cancun+ EVM',
    'gas.r2a': 'uint64 ×4 packing (timestamps / durations)',
    'gas.r2b': 'One slot; overflow → ZeroAmount revert',
    'gas.r3a': 'Cache rewardPerToken in updateReward',
    'gas.r3b': 'Avoids double accumulator computation',
    'gas.r4a': 'Cache account = msg.sender',
    'gas.r4b': 'Fewer repeated CALLER opcodes',
    'gas.r5a': 'unchecked after subtraction checks',
    'gas.r5b': 'Only when bal >= amount; skips overflow check',
    'gas.r6a': 'OZ v5.2.0 + explicit getters',
    'gas.r6b': 'Deploy +32,493; enables transient + clear API',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full matrix <strong>SWC-100 → SWC-136</strong> against <code>StakingRewards</code>. Report in <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong>; 3 informational items (approve, timestamp, owner/token trust).',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked only after checks',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'ERC-20 transfers via SafeERC20',
    'swc.r107': 'CEI + ReentrancyGuardTransient; test/attack/ReentrancyAttack',
    'swc.r128': 'O(1) paths; no loops over stakers',
    'swc.r123': 'Custom errors + unit / fuzz / invariant',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Approve front-running',
    'swc.i1d':
      'External ERC-20 race on stake. FE mitigation: approve(0)→N or permit; the pool does not manage allowances.',
    'swc.i2t': 'block.timestamp',
    'swc.i2d':
      'Rate, periodFinish, and lockup use timestamp (accepted Synthetix-style). Bounded miner skew.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'TDD gates: bootstrap, design, O(1) core, lockup/notify, fuzz/gas, deploy/ABI, frontend, and handoff.',
    'ph.01': 'Bootstrap + TDD design',
    'ph.23': 'O(1) core + lockup / notify',
    'ph.4': 'Fuzz · invariant · gas · SWC',
    'ph.5': 'Deploy scripts + ABI',
    'ph.67': 'Frontend + handoff docs',
    'st.1': 'Phases',
    'st.2': 'Campaigns',
    'st.3': 'Critical SWC',
    'st.4': 'Forge tests',
    'term.label': 'rolando@strahm:~/03-staking',
    'term.1': 'forge test',
    'term.2': '[PASS] 35 tests · unit/fuzz/inv/attack',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 3 · Mitigated/N/A: 33',
    'term.5': 'echo status',
    'term.6': 'MODULE_03_CLOSED · SWC_0_CRITICAL · GAS_DOCUMENTED',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'Foundry tests where a successful “attack” means it fails or is documented as a design limit. No exploit PoCs.',
    'cA.t': 'Integrity',
    'cA.d': 'Stake, withdraw, claim, exit, and notify.',
    'cB.t': 'Reentrancy',
    'cB.d': 'ERC-20 callback on getReward / withdraw.',
    'cC.t': 'Tx order',
    'cC.d': 'External ERC-20 approve race (documented).',
    'cD.t': 'Time',
    'cD.d': 'Lockup, periodFinish, setRewardsDuration.',
    'cE.t': 'Solvency',
    'cE.d': 'Vault / earned fuzz + invariant.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead': 'Contract, tests, gas, SWC, frontend, and handoff on GitHub and GitLab.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Staking Rewards · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('staking-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('staking-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
