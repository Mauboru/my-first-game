# Roadmap — Fuga do Pinscher

Jogo em Godot 4.7, terceira pessoa. Você joga como um pinscher fugindo de casa.
A ideia é misturar o stealth de **Hello Neighbor** com a pegada RPG de **The Witcher 3**.

## Estado atual

Já existe:

- **Jogador** (`entities/player/player.gd`): andar, correr, pulo duplo, agachar e latir para atrair o inimigo.
- **Inimigo** (`entities/enemie/enemie.gd`): patrulha, investiga barulho, persegue e ataca.
- **Fase da casa** (`levels/house/house.gd`): 4 tarefas fixas, coletáveis, esconderijos, barra de barulho e telas de vitória e derrota.

Ainda falta: menu, pausa, vida, combate, inventário, XP, missões de verdade, mapa e save.

## Etapas

As etapas estão na ordem recomendada. As etapas 0 e 1 vêm primeiro porque todas as outras dependem delas.

### 0. Fundação

- [x] Criar o repositório git
- [x] Criar o autoload `GameState` para guardar vida, inventário, missões e XP fora da cena
- [x] Tirar o HUD de dentro de `levels/house/house.gd` para uma cena própria
- [x] Adicionar as ações de input: atacar, esquivar, interagir, inventário, mapa e pausa

### 1. Casca do jogo

- [ ] Menu principal (Novo jogo, Continuar, Opções, Sair)
- [ ] Pausa (hoje o Esc só solta o mouse)
- [x] Opções de volume, sensibilidade e tela cheia
- [ ] Transição entre cenas
- [ ] Telas de game over e vitória refeitas

### 2. Vida e atributos

- [ ] Componente reutilizável de vida e fôlego, para jogador e inimigos
- [ ] O soco do vizinho tira vida em vez de causar derrota instantânea
- [ ] Barras de vida e fôlego no HUD

### 3. Combate

- [ ] Mordida: ataque leve e ataque carregado
- [ ] Esquiva gastando fôlego
- [ ] Trava de mira
- [ ] Hitbox e hurtbox
- [ ] Inimigo reage: dano, atordoamento e morte
- [ ] Latido como "sinal" do Witcher: atordoa ou assusta, além de atrair

### 4. Itens e inventário

- [ ] Itens como `Resource` (nome, ícone, tipo, efeito)
- [ ] Interação com tecla e aviso na tela, em vez de coletar por encostar
- [ ] Consumíveis (petisco cura)
- [ ] Equipamentos (coleiras com bônus)
- [ ] Itens-chave
- [ ] Tela de inventário
- [ ] Slots rápidos

### 5. Progressão RPG

- [ ] XP por missão e por inimigo
- [ ] Níveis
- [ ] Árvore de habilidades em três ramos: Furtividade, Mordida e Latido

### 6. Missões e diálogo

- [ ] Trocar a lista fixa `TASKS` por missões em dados, com objetivos e recompensas
- [ ] NPCs (outros bichos do bairro) com diálogo e escolhas
- [ ] Diário de missões
- [ ] Objetivo rastreado no HUD

### 7. Mundo e mapa

- [ ] Bairro como hub, com várias casas (cada casa é uma "dungeon" de stealth)
- [ ] Minimapa
- [ ] Mapa cheio com marcadores
- [ ] Viagem rápida
- [ ] Ciclo dia/noite que muda as rotinas dos inimigos

### 8. IA no estilo Hello Neighbor

- [ ] O vizinho aprende: põe armadilhas e tranca as rotas mais usadas
- [ ] Novos inimigos: gato, rato, outro cachorro
- [ ] Um chefe

### 9. Save/Load

- [ ] Salvar e carregar o `GameState`
- [ ] Botão Continuar do menu funcionando

### 10. Polimento

- [ ] Música dinâmica (calma, alerta, perseguição)
- [ ] Efeitos visuais
- [ ] Tutorial
- [ ] Balanceamento
- [ ] Exportação

## Decisões de design

**Stealth contra combate.** Se o pinscher puder matar o vizinho na mordida, o medo acaba. O vizinho deve ser só atordoável; o combate de verdade fica para inimigos menores e chefes.

**Escopo.** The Witcher 3 é enorme. A meta é um recorte jogável, e só depois aumentar:

- 1 bairro
- 2 ou 3 casas
- cerca de 5 missões
- cerca de 10 itens
- 1 árvore de habilidades pequena