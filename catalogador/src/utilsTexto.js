export function normaliza(s) {
  if (!s) return '';
  try {
    // remove diacritics and uppercase
    return s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toUpperCase();
  } catch (e) {
    // fallback for environments without \p{Diacritic}
    return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase();
  }
}

export function tokensIncluidos(texto, tokens) {
  const t = normaliza(texto);
  return tokens.every(token => t.includes(normaliza(token)));
}
