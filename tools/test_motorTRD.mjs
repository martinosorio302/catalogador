// dynamic import test for ES modules
(async () => {
  try {
  const mod = await import('../src/motorTRD.mjs');
    console.log('motorTRD imported, running simularAnalisisPDF()');
    const res = mod.simularAnalisisPDF('dummy.pdf');
    console.log(JSON.stringify(res, null, 2));
  } catch (err) {
    console.error('Failed to run test:', err);
    process.exit(1);
  }
})();
