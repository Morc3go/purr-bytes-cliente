# ADR 0044 — Vinhas da moldura no tom do wallpaper

**Data:** 2026-11-22 · **Situação:** aceita

## Contexto

Desde o ADR 0034, todo cartão de vidro (menu, seleção, editor, telemetria, escolha do
gato e do cenário, painéis do jogo) tem a moldura de vinhas com flores. Os botões, as
listas, as abas e o vidro já seguiam o wallpaper escolhido na galeria, mas a vinha
continuava sempre verde, com as cores do logo.

Na apresentação do TCC, o fundo do piquenique ficou melhor com as folhas marrons, que
combinam com a toalha e com os cartões. A equipe pediu o mesmo no jogo: a vinha
acompanhar o wallpaper, em todos os temas.

## Decisões

- **Uma paleta por fundo.** `GaleriaDeFundos.VINHAS` guarda três cores por fundo, na
  ordem vinha, folha escura e folha clara. Fica ao lado de `TONS` e `TINTAS`, que já
  definem o resto da paleta de cada wallpaper. `cores_das_vinhas(fundo)` devolve as
  três; um fundo desconhecido usa o padrão.

  | Fundo | Vinha | Cor |
  |---|---|---|
  | brejo | verde do logo (sem mudança) | `#4f8941`, `#73a429`, `#8bb518` |
  | noite estrelada | azul da noite | `#345482`, `#567eb2`, `#8cb4e2` |
  | estufa | verde-água | `#266e58`, `#489676`, `#80c4a0` |
  | lago das carpas | laranja das carpas | `#b05824`, `#e38b3b`, `#f6b86e` |
  | piquenique | marrom, como nos slides | `#7a5232`, `#9c744d`, `#be9260` |
  | céu e montanhas | azul do céu | `#46789a`, `#71a1bb`, `#aad0e4` |

- **A vinha é o tom mais escuro.** Ela é a linha que contorna o cartão; as folhas
  clareiam a partir dela, como no verde original.
- **As flores não mudam.** A flor vermelha e a azul são as do logo e aparecem em todos
  os fundos.
- **O logo não muda.** As vinhas desenhadas no logo "Crypto Cats" fazem parte da arte da
  equipe e continuam verdes.
- **Onde a cor é escolhida.**
  - `MolduraDeVinhas` ganhou a propriedade `fundo`. Vazia, usa o fundo atual da galeria.
  - `EnfeiteDaGaleria.vidro()` repassa o fundo da tela para a moldura.
  - O menu chama `definir_fundo()` ao trocar o wallpaper, e a vinha muda na hora, junto
    com os botões.
- **Cache.** A textura é guardada por tamanho e por fundo. Trocar o wallpaper não
  redesenha as molduras que já existem para aquele fundo.

## Consequências

- É só aparência: nenhum comportamento muda.
- Testes:
  - `teste_tema_da_galeria.gd` confere que cada fundo tem uma vinha diferente, que o
    brejo mantém o verde do logo e o piquenique é marrom, e que as flores continuam.
  - O mesmo arquivo confere que trocar o fundo no menu troca a cor da vinha.
  - `afirmar_vidro_com_vinhas` agora também confere que a moldura de cada tela usa o
    fundo escolhido.
